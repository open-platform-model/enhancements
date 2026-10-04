package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	cueerrors "cuelang.org/go/cue/errors"
	"cuelang.org/go/cue/load"
	"cuelang.org/go/encoding/jsonschema"
	"cuelang.org/go/encoding/openapi"
)

type jsMode struct {
	label string
	cfg   *jsonschema.GenerateConfig
}

type Res struct {
	Module    string
	LoadErr   string
	Expand    string // "ok" or error
	Plain     string
	WrapPlain string
	Walker    string
	Extra     []string
	Feat      map[string]map[string]int
	Gaps      map[string]int
}

var feats = []string{"minimum", "maximum", "default", "enum", "pattern", "description", "required", "$ref", "allOf", "oneOf", "anyOf"}

func count(j any, m map[string]int) {
	switch t := j.(type) {
	case map[string]any:
		for k, v := range t {
			for _, f := range feats {
				if k == f {
					m[f]++
				}
			}
			count(v, m)
		}
	case []any:
		for _, v := range t {
			count(v, m)
		}
	}
}

func main() {
	outDir := os.Args[1]
	os.MkdirAll(outDir, 0o755)
	var dirs []string
	// os.Args[2:]: globs of module.cue files, e.g. $WS/opm-modules/*/module.cue $WS/modules/*/module.cue
	for _, g := range os.Args[2:] {
		m, _ := filepath.Glob(g)
		for _, f := range m {
			dirs = append(dirs, filepath.Dir(f))
		}
	}
	sort.Strings(dirs)
	var results []Res
	for _, d := range dirs {
		name := filepath.Base(filepath.Dir(d)) + "/" + filepath.Base(d)
		r := Res{Module: name, Feat: map[string]map[string]int{}, Gaps: map[string]int{}}
		ctx := cuecontext.New()
		insts := load.Instances([]string{"."}, &load.Config{Dir: d})
		if insts[0].Err != nil {
			r.LoadErr = insts[0].Err.Error()
			results = append(results, r)
			continue
		}
		mv := ctx.BuildInstance(insts[0])
		if mv.Err() != nil {
			r.LoadErr = mv.Err().Error()
			results = append(results, r)
			continue
		}
		cfg := mv.LookupPath(cue.MakePath(cue.Def("config")))
		if !cfg.Exists() {
			r.LoadErr = "no #config"
			results = append(results, r)
			continue
		}
		wrap := ctx.CompileString("#Config: _").FillPath(cue.MakePath(cue.Def("Config")), cfg)
		gen := func(label string, val cue.Value, cfgo *openapi.Config, path string) (res string) {
			defer func() {
				if p := recover(); p != nil {
					res = fmt.Sprintf("PANIC: %v", p)
				}
			}()
			f, err := openapi.Generate(val, cfgo)
			if err != nil {
				return "ERR: " + strings.ReplaceAll(fmt.Sprintf("%v", cueerrors.Details(err, nil)), "\n", " | ")
			}
			bv := ctx.BuildFile(f)
			b, err := bv.MarshalJSON()
			if err != nil {
				return "MARSHAL ERR: " + err.Error()
			}
			os.WriteFile(filepath.Join(outDir, strings.ReplaceAll(name, "/", "_")+"."+label+".json"), b, 0o644)
			var j any
			json.Unmarshal(b, &j)
			m := map[string]int{}
			count(j, m)
			r.Feat[label] = m
			return "ok"
		}
		r.Expand = gen("expand", wrap, &openapi.Config{ExpandReferences: true}, "")
		r.WrapPlain = gen("wrapplain", wrap, &openapi.Config{}, "")
		// plain on the whole instance, but only #config's closure matters
		r.Plain = gen("plain", mv, &openapi.Config{}, "")
		for _, m := range jsModes() {
			label := m.label
			res := func() (res string) {
				defer func() {
					if p := recover(); p != nil {
						res = fmt.Sprintf("PANIC: %v", p)
					}
				}()
				e, err := jsonschema.Generate(cfg, m.cfg)
				if err != nil {
					return "ERR: " + strings.ReplaceAll(fmt.Sprintf("%v", cueerrors.Details(err, nil)), "\n", " | ")
				}
				b, err := ctx.BuildExpr(e).MarshalJSON()
				if err != nil {
					return "MARSHAL ERR: " + err.Error()
				}
				os.WriteFile(filepath.Join(outDir, strings.ReplaceAll(name, "/", "_")+"."+label+".json"), b, 0o644)
				var j any
				json.Unmarshal(b, &j)
				mm := map[string]int{}
				count(j, mm)
				r.Feat[label] = mm
				return "ok"
			}()
			r.Extra = append(r.Extra, label+"="+res)
		}
		w := &Walker{Gaps: r.Gaps}
		s := w.Schema(cfg, 0)
		b, _ := json.MarshalIndent(s, "", " ")
		os.WriteFile(filepath.Join(outDir, strings.ReplaceAll(name, "/", "_")+".walker.json"), b, 0o644)
		var j any
		json.Unmarshal(b, &j)
		m := map[string]int{}
		count(j, m)
		r.Feat["walker"] = m
		r.Walker = "ok"
		results = append(results, r)
	}
	for _, r := range results {
		fmt.Printf("== %s\n", r.Module)
		if r.LoadErr != "" {
			fmt.Printf("  LOAD ERR %s\n", r.LoadErr)
			continue
		}
		fmt.Printf("  expand=%s\n  wrapplain=%s\n  plain(inst)=%s\n  walker=%s gaps=%v\n", trunc(r.Expand), trunc(r.WrapPlain), trunc(r.Plain), r.Walker, r.Gaps)
		for _, e := range r.Extra {
			fmt.Printf("  %s\n", trunc(e))
		}
		for _, l := range []string{"expand", "wrapplain", "plain", "walker", "js2020", "jsopenapi"} {
			if m, ok := r.Feat[l]; ok {
				var parts []string
				for _, f := range feats {
					parts = append(parts, fmt.Sprintf("%s=%d", f, m[f]))
				}
				fmt.Printf("  feat[%s] %s\n", l, strings.Join(parts, " "))
			}
		}
	}
}
func trunc(s string) string {
	if len(s) > 900 {
		return s[:900] + "..."
	}
	return s
}
