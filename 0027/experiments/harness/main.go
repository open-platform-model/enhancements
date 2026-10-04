package main

// Shared harness for experiments 02 to 05: for every sample under cue/samples, encode #config with each
// encoder, wrap it in a CRD, validate the CRD offline (apiextensions
// NewStructural + ValidateStructural + ValidateCustomResourceDefinition), and,
// with -live, apply it to the throwaway cluster and dry-run every fixture.
// CUE (values & #config, concrete) is the ground truth for each fixture.

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	cueerrors "cuelang.org/go/cue/errors"
	"cuelang.org/go/cue/load"
	"cuelang.org/go/encoding/jsonschema"
	"cuelang.org/go/encoding/openapi"

	"k8s.io/apiextensions-apiserver/pkg/apis/apiextensions"
	apiextv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	crdvalidation "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/validation"
	structuralschema "k8s.io/apiextensions-apiserver/pkg/apiserver/schema"
	"k8s.io/apimachinery/pkg/util/validation/field"
)

type Fixture struct {
	Name   string         `json:"name"`
	Values map[string]any `json:"values"`
}

var fixtureValues = map[string]map[string]any{}

type FixRes struct {
	Fixture string `json:"fixture"`
	CUE     string `json:"cue"` // ok | refused
	CUEErr  string `json:"cueErr,omitempty"`
	API     string `json:"api,omitempty"`
	APIErr  string `json:"apiErr,omitempty"`
	Echo    bool   `json:"echo,omitempty"` // API error text contains "hunter2"
}

type EncRes struct {
	Sample     string         `json:"sample"`
	Encoder    string         `json:"encoder"`
	GenErr     string         `json:"genErr,omitempty"`
	Unknown    string         `json:"unknownFields,omitempty"`
	Structural string         `json:"structural"`
	CRDValid   string         `json:"crdValid"`
	Live       string         `json:"live,omitempty"`
	Refusals   []string       `json:"refusals,omitempty"`
	Secrets    []string       `json:"secrets,omitempty"`
	Gaps       map[string]int `json:"gaps,omitempty"`
	Fixtures   []FixRes       `json:"fixtures,omitempty"`
	crdPath    string
	kind       string
	plural     string
}

var (
	live       = flag.Bool("live", false, "apply to the cluster")
	kubeconfig = flag.String("kubeconfig", "", "kubeconfig of the throwaway cluster")
	outDir     = flag.String("out", "out", "output dir")
	only       = flag.String("only", "", "sample name prefix filter")
	corpus     = flag.Bool("corpus", false, "encode the real module corpus instead of the samples")
	fleet      = flag.String("fleet", "", "comma-separated globs of module.cue files for -corpus, e.g. $WS/opm-modules/*/module.cue,$WS/modules/*/module.cue")
)

func main() {
	flag.Parse()
	if *live && !strings.Contains(*kubeconfig, "x1a") {
		panic("refusing: -live needs the x1a throwaway kubeconfig")
	}
	os.MkdirAll(filepath.Join(*outDir, "crd"), 0o755)
	dirs, _ := filepath.Glob("cue/samples/*")
	if *corpus {
		dirs = nil
		if *fleet == "" {
			panic("-corpus needs -fleet")
		}
		for _, g := range strings.Split(*fleet, ",") {
			m, _ := filepath.Glob(g)
			for _, f := range m {
				dirs = append(dirs, filepath.Dir(f))
			}
		}
	}
	sort.Strings(dirs)
	var all []*EncRes
	for _, d := range dirs {
		sid := filepath.Base(d)
		if *only != "" && !strings.HasPrefix(sid, *only) {
			continue
		}
		ctx := cuecontext.New()
		insts := load.Instances([]string{"./samples/" + sid}, &load.Config{Dir: "cue"})
		if *corpus {
			sid = filepath.Base(filepath.Dir(d)) + "-" + filepath.Base(d)
			insts = load.Instances([]string{"."}, &load.Config{Dir: d})
		}
		if insts[0].Err != nil {
			panic(insts[0].Err)
		}
		inst := ctx.BuildInstance(insts[0])
		cfg := inst.LookupPath(cue.MakePath(cue.Def("config")))
		var fx []Fixture
		b, _ := os.ReadFile(filepath.Join(d, "fixtures.json")) // none for the corpus
		json.Unmarshal(b, &fx)
		if *corpus {
			if dv := inst.LookupPath(cue.ParsePath("debugValues")); dv.Exists() {
				var m map[string]any
				if jb, err := dv.MarshalJSON(); err == nil && json.Unmarshal(jb, &m) == nil {
					fx = append(fx, Fixture{Name: "debugvalues", Values: m})
				}
			}
		}
		truth := map[string]FixRes{}
		for _, f := range fx {
			fixtureValues[sid+"/"+f.Name] = f.Values
			vb, _ := json.Marshal(f.Values)
			u := cfg.Unify(ctx.CompileBytes(vb))
			r := FixRes{Fixture: f.Name, CUE: "ok"}
			if err := u.Validate(cue.Concrete(true), cue.Final()); err != nil {
				r.CUE = "refused"
				r.CUEErr = oneLine(cueerrors.Details(err, nil))
			}
			truth[f.Name] = r
		}
		encs := []string{"oaexpand", "oaexpand-fix", "oaplain", "jsonschema", "walker", "cand-cel", "cand-oneof"}
		if *corpus {
			encs = []string{"oaexpand-fix", "walker", "cand-cel", "cand-oneof"}
		}
		for _, enc := range encs {
			er := &EncRes{Sample: sid, Encoder: enc}
			schema := encode(ctx, inst, cfg, enc, er)
			for _, f := range fx {
				er.Fixtures = append(er.Fixtures, truth[f.Name])
			}
			if schema == nil {
				er.Structural, er.CRDValid = "n/a", "n/a"
				all = append(all, er)
				continue
			}
			buildAndValidate(er, schema)
			all = append(all, er)
		}
	}
	if *live {
		runLive(all)
	}
	b, _ := json.MarshalIndent(all, "", " ")
	os.WriteFile(filepath.Join(*outDir, "results.json"), b, 0o644)
	summary(all)
}

func oneLine(s string) string {
	s = strings.ReplaceAll(strings.TrimSpace(s), "\n", " | ")
	if len(s) > 2000 {
		s = s[:2000] + "..."
	}
	return s
}

func encode(ctx *cue.Context, inst, cfg cue.Value, enc string, er *EncRes) (res map[string]any) {
	defer func() {
		if p := recover(); p != nil {
			er.GenErr = fmt.Sprintf("PANIC: %v", p)
			res = nil
		}
	}()
	toMap := func(v cue.Value) map[string]any {
		b, err := v.MarshalJSON()
		if err != nil {
			er.GenErr = "marshal: " + oneLine(err.Error())
			return nil
		}
		var m map[string]any
		json.Unmarshal(b, &m)
		return m
	}
	switch enc {
	case "oaexpand-fix":
		m := encode(ctx, inst, cfg, "oaexpand", er)
		if m != nil {
			fixOpen(m)
		}
		return m
	case "oaexpand", "oaplain":
		wrap := ctx.CompileString("#Config: _").FillPath(cue.MakePath(cue.Def("Config")), cfg)
		f, err := openapi.Generate(wrap, &openapi.Config{ExpandReferences: enc == "oaexpand"})
		if err != nil {
			er.GenErr = oneLine(cueerrors.Details(err, nil))
			return nil
		}
		v := ctx.BuildFile(f).LookupPath(cue.ParsePath("components.schemas.Config"))
		return toMap(v)
	case "jsonschema":
		e, err := jsonschema.Generate(cfg, nil)
		if err != nil {
			er.GenErr = oneLine(cueerrors.Details(err, nil))
			return nil
		}
		return toMap(ctx.BuildExpr(e))
	case "walker":
		w := &Walker{Gaps: map[string]int{}}
		s := w.Schema(cfg, 0)
		er.Gaps = w.Gaps
		return roundTrip(s)
	default:
		c := NewCand(strings.TrimPrefix(enc, "cand-"))
		s := c.Schema(cfg, "#config", 0)
		delete(s, "description")
		er.Gaps = c.Gaps
		er.Refusals = c.Refusals
		er.Secrets = c.Secrets
		return roundTrip(s)
	}
}

func roundTrip(s S) map[string]any {
	b, _ := json.Marshal(s)
	var m map[string]any
	json.Unmarshal(b, &m)
	return m
}

func camel(s string) string {
	var b strings.Builder
	up := true
	for _, r := range s {
		if r == '-' || r == '_' {
			up = true
			continue
		}
		if up {
			b.WriteString(strings.ToUpper(string(r)))
			up = false
		} else {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func buildAndValidate(er *EncRes, schema map[string]any) {
	kind := "X" + camel(er.Sample+"-"+er.Encoder)
	plural := strings.ToLower(kind) + "s"
	er.kind, er.plural = kind, plural
	crd := map[string]any{
		"apiVersion": "apiextensions.k8s.io/v1",
		"kind":       "CustomResourceDefinition",
		"metadata":   map[string]any{"name": plural + ".x1a.opmodel.dev"},
		"spec": map[string]any{
			"group": "x1a.opmodel.dev",
			"scope": "Namespaced",
			"names": map[string]any{"kind": kind, "plural": plural, "singular": strings.ToLower(kind), "listKind": kind + "List"},
			"versions": []any{map[string]any{
				"name": "v1alpha1", "served": true, "storage": true,
				"schema": map[string]any{"openAPIV3Schema": map[string]any{
					"type":       "object",
					"properties": map[string]any{"spec": schema},
				}},
			}},
		},
	}
	b, _ := json.MarshalIndent(crd, "", " ")
	er.crdPath = filepath.Join(*outDir, "crd", er.Sample+"."+er.Encoder+".json")
	os.WriteFile(er.crdPath, b, 0o644)

	// strict decode: unknown fields are what the API server would reject
	var v1crd apiextv1.CustomResourceDefinition
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&v1crd); err != nil {
		er.Unknown = oneLine(err.Error())
		v1crd = apiextv1.CustomResourceDefinition{}
		json.Unmarshal(b, &v1crd)
	}
	var internal apiextensions.CustomResourceDefinition
	if err := apiextv1.Convert_v1_CustomResourceDefinition_To_apiextensions_CustomResourceDefinition(&v1crd, &internal, nil); err != nil {
		er.Structural = "convert: " + err.Error()
		return
	}
	// the v1 -> internal conversion hoists a single version's schema to
	// spec.validation
	var sch *apiextensions.JSONSchemaProps
	if internal.Spec.Validation != nil {
		sch = internal.Spec.Validation.OpenAPIV3Schema
	} else if len(internal.Spec.Versions) > 0 && internal.Spec.Versions[0].Schema != nil {
		sch = internal.Spec.Versions[0].Schema.OpenAPIV3Schema
	}
	if sch == nil {
		er.Structural = "no schema after decode"
		return
	}
	st, err := structuralschema.NewStructural(sch)
	if err != nil {
		er.Structural = "NewStructural: " + oneLine(err.Error())
	} else if errs := structuralschema.ValidateStructural(field.NewPath("openAPIV3Schema"), st); len(errs) > 0 {
		er.Structural = fmt.Sprintf("%d errs: %s", len(errs), oneLine(errs.ToAggregate().Error()))
	} else {
		er.Structural = "ok"
	}
	internal.Status.StoredVersions = []string{"v1alpha1"}
	if errs := crdvalidation.ValidateCustomResourceDefinition(context.Background(), &internal); len(errs) > 0 {
		er.CRDValid = fmt.Sprintf("%d errs: %s", len(errs), oneLine(errs.ToAggregate().Error()))
	} else {
		er.CRDValid = "ok"
	}
}

// kubectl retries transport failures (the kind API server restarts under
// load); a schema verdict is never retried.
func kubectl(args ...string) (string, error) {
	var out string
	var err error
	for attempt := 0; attempt < 8; attempt++ {
		cmd := exec.Command("kubectl", append([]string{"--kubeconfig", *kubeconfig}, args...)...)
		var o bytes.Buffer
		cmd.Stdout, cmd.Stderr = &o, &o
		err = cmd.Run()
		out = o.String()
		if err == nil || !infra(out) {
			return out, err
		}
		time.Sleep(time.Duration(2+attempt*2) * time.Second)
	}
	return "INFRA: " + out, err
}

func infra(s string) bool {
	for _, m := range []string{"connection refused", "unexpected EOF", "failed to download openapi", "i/o timeout", "TLS handshake", "the server is currently unable", "context deadline exceeded", "connection reset"} {
		if strings.Contains(s, m) {
			return true
		}
	}
	return false
}

func runLive(all []*EncRes) {
	var applied []*EncRes
	for _, er := range all {
		if er.crdPath == "" {
			continue
		}
		out, err := kubectl("apply", "--dry-run=server", "-f", er.crdPath)
		if err != nil {
			er.Live = "dry-run refused: " + oneLine(out)
			continue
		}
		er.Live = "ok"
		if strings.Contains(out, "Warning") {
			er.Live = "ok with warning: " + oneLine(out)
		}
		if out, err := kubectl("apply", "-f", er.crdPath); err != nil {
			er.Live = "apply failed: " + oneLine(out)
			continue
		}
		applied = append(applied, er)
	}
	kubectl("wait", "--for=condition=Established", "crd", "--all", "--timeout=120s")
	type job struct {
		er *EncRes
		i  int
	}
	jobs := make(chan job)
	var wg sync.WaitGroup
	for w := 0; w < 4; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := range jobs {
				f := &j.er.Fixtures[j.i]
				vals := fixtureValues[j.er.Sample+"/"+f.Fixture]
				obj := map[string]any{
					"apiVersion": "x1a.opmodel.dev/v1alpha1", "kind": j.er.kind,
					"metadata": map[string]any{"name": fmt.Sprintf("f%02d", j.i), "namespace": "default"},
					"spec":     vals,
				}
				ob, _ := json.Marshal(obj)
				p := filepath.Join(*outDir, "crd", j.er.Sample+"."+j.er.Encoder+"."+f.Fixture+".inst.json")
				os.WriteFile(p, ob, 0o644)
				out, err := kubectl("apply", "--dry-run=server", "-f", p)
				if err != nil {
					f.API = "refused"
					f.APIErr = oneLine(out)
				} else {
					f.API = "ok"
					if strings.Contains(out, "Warning") {
						f.APIErr = oneLine(out)
					}
				}
				f.Echo = strings.Contains(out, "hunter2")
			}
		}()
	}
	for _, er := range applied {
		for i := range er.Fixtures {
			jobs <- job{er, i}
		}
	}
	close(jobs)
	wg.Wait()
}

func summary(all []*EncRes) {
	for _, er := range all {
		agree, fa, fr, n := 0, 0, 0, 0
		for _, f := range er.Fixtures {
			if f.API == "" {
				continue
			}
			n++
			switch {
			case f.API == f.CUE:
				agree++
			case f.API == "ok":
				fa++
			default:
				fr++
			}
		}
		gen := "ok"
		if er.GenErr != "" {
			gen = "ERR"
		}
		fmt.Printf("%-24s %-11s gen=%-3s struct=%-6.6s crd=%-6.6s live=%-8.8s fixtures agree=%d/%d falseAccept=%d falseRefuse=%d refusals=%d\n",
			er.Sample, er.Encoder, gen, er.Structural, er.CRDValid, er.Live, agree, n, fa, fr, len(er.Refusals))
	}
}

// fixOpen rewrites encoding/openapi's open-struct form (`additionalProperties:
// {}`) to x-kubernetes-preserve-unknown-fields, its structural equivalent.
func fixOpen(x any) {
	switch t := x.(type) {
	case map[string]any:
		if ap, ok := t["additionalProperties"].(map[string]any); ok && len(ap) == 0 {
			delete(t, "additionalProperties")
			t["x-kubernetes-preserve-unknown-fields"] = true
		}
		for _, v := range t {
			fixOpen(v)
		}
	case []any:
		for _, v := range t {
			fixOpen(v)
		}
	}
}
