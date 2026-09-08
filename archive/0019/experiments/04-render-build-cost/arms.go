package main

import (
	"fmt"
	"os"
	"runtime"
	"strings"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/ast"
	"cuelang.org/go/cue/build"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
)

// Paths copied from library/opm/schema/paths.go. Copied rather than imported,
// per the experiments protocol, and worth reading side by side: definition
// paths on closed structs resolve only when built with cue.Def, which is why
// #context is a MakePath and #component is not.
var (
	pathRendered   = cue.ParsePath("rendered")
	pathInstance   = cue.ParsePath("instance")
	pathComponents = cue.ParsePath("components")
	pathTransform  = cue.ParsePath("#transform")
	pathComponent  = cue.ParsePath("#component")
	pathContext    = cue.MakePath(cue.Def("context"))
	pathOutput     = cue.ParsePath("output")
)

// env returns the process environment with CUE_CACHE_DIR pointed at dir.
// load.Config.Env is the only lever for the cache location: modconfig builds
// its registry from these values (modconfig.NewRegistry -> cueconfig.CacheDir),
// so an arm can be given a cold cache without touching the process env.
func env(cacheDir string) []string {
	out := make([]string, 0, len(os.Environ())+1)
	for _, kv := range os.Environ() {
		if strings.HasPrefix(kv, "CUE_CACHE_DIR=") {
			continue
		}
		out = append(out, kv)
	}
	if cacheDir != "" {
		out = append(out, "CUE_CACHE_DIR="+cacheDir)
	}
	return out
}

// renderOnce is the whole single-build render path: load, build, force
// concrete, export. Every arm except D calls exactly this; they differ only in
// the cue.Context and the cache handed to it.
func renderOnce(cctx *cue.Context, dir string, e []string) (phases, int, error) {
	var p phases

	t0 := time.Now()
	insts := load.Instances([]string{"."}, &load.Config{Dir: dir, Env: e})
	p.Load = time.Since(t0)
	if len(insts) == 0 {
		return p, 0, fmt.Errorf("no instances loaded from %s", dir)
	}
	if err := insts[0].Err; err != nil {
		return p, 0, fmt.Errorf("load: %w", err)
	}

	t1 := time.Now()
	v := cctx.BuildInstance(insts[0])
	p.Build = time.Since(t1)
	if err := v.Err(); err != nil {
		return p, 0, fmt.Errorf("build: %w", err)
	}

	// Validate(Concrete) is what forces the evaluation. Without it the value is
	// lazy and the arm would be timing a promise rather than a render.
	t2 := time.Now()
	rendered := v.LookupPath(pathRendered)
	if err := rendered.Validate(cue.Concrete(true)); err != nil {
		p.Eval = time.Since(t2)
		return p, 0, fmt.Errorf("eval: %w", err)
	}
	p.Eval = time.Since(t2)

	t3 := time.Now()
	if _, err := rendered.MarshalJSON(); err != nil {
		return p, 0, fmt.Errorf("export: %w", err)
	}
	p.Export = time.Since(t3)

	n := countFields(rendered)
	if n != expectOutputs {
		return p, n, fmt.Errorf("rendered %d outputs, expected %d (a render that produced nothing would otherwise be timed as a fast one)", n, expectOutputs)
	}
	return p, n, nil
}

// expectOutputs is the number of rendered resources this fixture must produce:
// four for the web component, one for config. Asserted on every sample because
// an empty `rendered` evaluates instantly, and an arm that silently rendered
// nothing would report as the fastest one.
var expectOutputs = 5

func countFields(v cue.Value) int {
	it, err := v.Fields()
	if err != nil {
		return 0
	}
	n := 0
	for it.Next() {
		n++
	}
	return n
}

// ---------------------------------------------------------------------------
// Arm A: cold
// ---------------------------------------------------------------------------
//
// Each sample gets a cache directory that did not exist a moment ago, so it
// pays the full resolution and fetch of core, the catalog and the k8s types.
// This is inherently a small-sample, network-bound measurement: it answers
// "what does a cold operator pod pay before its first render", which is a
// one-off per process, not a per-render cost.
func armCold(t *tree, samples int) armResult {
	r := armResult{
		Name: "A-cold",
		Note: "network-bound; one-off per process rather than per render",
	}
	before := memSnapshot()
	for i := 0; i < samples && i < len(t.Renders); i++ {
		cache, err := os.MkdirTemp("", "cue-cold-cache-")
		if err != nil {
			r.Samples = append(r.Samples, sample{Index: i, Err: err})
			continue
		}
		cctx := cuecontext.New()
		p, out, err := renderOnce(cctx, t.Renders[i], env(cache))
		r.Samples = append(r.Samples, sample{Index: i, P: p, Outputs: out, Err: err})
		os.RemoveAll(cache)
	}
	finishMem(&r, before, len(r.Samples))
	return r
}

// prime warms the shared cache with one throwaway render, so arm B's first
// timed sample is not a fetch in disguise.
func prime(t *tree) error {
	cctx := cuecontext.New()
	_, _, err := renderOnce(cctx, t.Renders[0], env(""))
	return err
}

// ---------------------------------------------------------------------------
// Arm B: warm cache, fresh context
// ---------------------------------------------------------------------------
//
// The difference between B and A is the fetch. The difference between B and C
// is everything a cue.Context holds on to.
func armWarm(t *tree, n int) armResult {
	r := armResult{Name: "B-warm", Note: "fresh cue.Context per render, warm module cache"}
	before := memSnapshot()
	for i := 0; i < n && i < len(t.Renders); i++ {
		cctx := cuecontext.New()
		p, out, err := renderOnce(cctx, t.Renders[i], env(""))
		r.Samples = append(r.Samples, sample{Index: i, P: p, Outputs: out, Err: err})
	}
	finishMem(&r, before, len(r.Samples))
	return r
}

// ---------------------------------------------------------------------------
// Arm C: warm cache, one shared context
// ---------------------------------------------------------------------------
//
// The arm the hypothesis rests on. If CUE's own interning and evaluation
// caching amortise the catalog across renders inside one process, this arm is
// flat and close to arm D; if it does not, the catalog is re-evaluated per
// render and the drift line in the report shows it.
func armShared(t *tree, n int) armResult {
	r := armResult{Name: "C-shared", Note: "one cue.Context for every render, warm module cache"}
	cctx := cuecontext.New()
	before := memSnapshot()
	for i := 0; i < n && i < len(t.Renders); i++ {
		p, out, err := renderOnce(cctx, t.Renders[i], env(""))
		r.Samples = append(r.Samples, sample{Index: i, P: p, Outputs: out, Err: err})
	}
	finishMem(&r, before, len(r.Samples))
	return r
}

// ---------------------------------------------------------------------------
// Arm D: the baseline, which is today's path
// ---------------------------------------------------------------------------
//
// Mirrors library/opm/compile/execute.go: the platform and its catalog are
// built ONCE and held, each instance is built in its own build, its components
// are finalized (library/opm/compile/finalize.go), and the finalized value is
// filled into the transformer across the build boundary.
//
// It is deliberately NOT parity-correct. Finalization is the strip this whole
// enhancement exists to remove, and the #context here is constructed in Go
// exactly because the definition fields a CUE projection would read are gone
// by then. It is here as a cost yardstick and nothing else.
func armBaseline(t *tree, n int) armResult {
	r := armResult{
		Name: "D-base",
		Note: "today's path: platform held, component finalized, filled across builds. Not parity-correct; yardstick only",
	}
	cctx := cuecontext.New()

	// One-time: build the platform without any instance.
	t0 := time.Now()
	insts := load.Instances([]string{"./baseline"}, &load.Config{Dir: t.Renders[0], Env: env("")})
	if len(insts) == 0 || insts[0].Err != nil {
		r.Samples = append(r.Samples, sample{Err: fmt.Errorf("baseline load: %v", loadErr(insts))})
		return r
	}
	base := cctx.BuildInstance(insts[0])
	if err := base.Err(); err != nil {
		r.Samples = append(r.Samples, sample{Err: fmt.Errorf("baseline build: %w", err)})
		return r
	}
	transformers := base.LookupPath(cue.ParsePath("transformers"))
	if err := transformers.Err(); err != nil {
		r.Samples = append(r.Samples, sample{Err: fmt.Errorf("baseline transformers: %w", err)})
		return r
	}
	pairs, err := resolvePairs(transformers)
	if err != nil {
		r.Samples = append(r.Samples, sample{Err: err})
		return r
	}
	r.OneTime = time.Since(t0)

	before := memSnapshot()
	for i := 0; i < n && i < len(t.Instances); i++ {
		p, out, err := baselineRender(cctx, t.Instances[i], transformers, pairs)
		r.Samples = append(r.Samples, sample{Index: i, P: p, Outputs: out, Err: err})
	}
	finishMem(&r, before, len(r.Samples))
	return r
}

// pair is one (component, transformer FQN) to execute. The same five pairs the
// CUE glue selects, resolved the same way: by short name, so no version is
// restated as data on either side.
type pair struct {
	component string
	fqn       string
}

var wanted = map[string][]string{
	"web":    {"deployment-transformer", "hpa-transformer", "http-route-transformer", "service-transformer"},
	"config": {"configmap-transformer"},
}

func resolvePairs(transformers cue.Value) ([]pair, error) {
	it, err := transformers.Fields()
	if err != nil {
		return nil, fmt.Errorf("iterating transformers: %w", err)
	}
	var keys []string
	for it.Next() {
		keys = append(keys, it.Selector().Unquoted())
	}
	var out []pair
	for _, comp := range []string{"web", "config"} {
		for _, short := range wanted[comp] {
			found := ""
			for _, k := range keys {
				if strings.Contains(k, "/"+short+"@") {
					found = k
					break
				}
			}
			if found == "" {
				return nil, fmt.Errorf("no transformer key matched %q among %d keys", short, len(keys))
			}
			out = append(out, pair{component: comp, fqn: found})
		}
	}
	return out, nil
}

func baselineRender(cctx *cue.Context, instDir string, transformers cue.Value, pairs []pair) (phases, int, error) {
	var p phases

	t0 := time.Now()
	insts := load.Instances([]string{"."}, &load.Config{Dir: instDir, Env: env("")})
	p.Load = time.Since(t0)
	if len(insts) == 0 || insts[0].Err != nil {
		return p, 0, fmt.Errorf("load: %v", loadErr(insts))
	}

	t1 := time.Now()
	v := cctx.BuildInstance(insts[0])
	p.Build = time.Since(t1)
	if err := v.Err(); err != nil {
		return p, 0, fmt.Errorf("build: %w", err)
	}

	t2 := time.Now()
	inst := v.LookupPath(pathInstance)
	schemaComponents := inst.LookupPath(pathComponents)
	dataComponents, err := finalizeValue(cctx, schemaComponents)
	if err != nil {
		p.Eval = time.Since(t2)
		return p, 0, fmt.Errorf("finalize: %w", err)
	}

	// #context is built in Go, which is what the kernel does today
	// (library/opm/schema/context.go decodes into structs and re-encodes).
	// The instance-level half is identical for every pair, so it is built once
	// per render rather than once per pair, matching the kernel's shape.
	mim, err := instanceContext(inst)
	if err != nil {
		p.Eval = time.Since(t2)
		return p, 0, err
	}

	var outputs []cue.Value
	for _, pr := range pairs {
		transform := transformers.
			LookupPath(cue.MakePath(cue.Str(pr.fqn))).
			LookupPath(pathTransform)
		if !transform.Exists() {
			p.Eval = time.Since(t2)
			return p, 0, fmt.Errorf("#transform not found for %s", pr.fqn)
		}

		dataComp := dataComponents.LookupPath(cue.MakePath(cue.Str(pr.component)))
		unified := transform.FillPath(pathComponent, dataComp)
		if err := unified.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, 0, fmt.Errorf("fill #component (%s): %w", pr.fqn, err)
		}

		ctxVal := cctx.CompileString(fmt.Sprintf(`{
	#moduleInstanceMetadata: %s
	#componentMetadata: {name: %q}
	#runtimeName: "render-build-cost"
}`, mim, pr.component))
		if err := ctxVal.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, 0, fmt.Errorf("build #context: %w", err)
		}
		unified = unified.FillPath(pathContext, ctxVal)
		if err := unified.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, 0, fmt.Errorf("fill #context (%s): %w", pr.fqn, err)
		}

		out := unified.LookupPath(pathOutput)
		if err := out.Validate(cue.Concrete(true)); err != nil {
			p.Eval = time.Since(t2)
			return p, 0, fmt.Errorf("eval output (%s): %w", pr.fqn, err)
		}
		outputs = append(outputs, out)
	}
	p.Eval = time.Since(t2)

	t3 := time.Now()
	for _, o := range outputs {
		if _, err := o.MarshalJSON(); err != nil {
			return p, 0, fmt.Errorf("export: %w", err)
		}
	}
	p.Export = time.Since(t3)

	return p, len(outputs), nil
}

// finalizeValue is library/opm/compile/finalize.go, copied verbatim in
// behaviour: export through cue.Final() and rebuild. cue.Final() sets
// omitDefinitions, which is precisely why the value it returns cannot carry
// #names, #resources, #traits or #instance into a transformer.
func finalizeValue(cctx *cue.Context, v cue.Value) (cue.Value, error) {
	node := v.Syntax(cue.Final())
	expr, ok := node.(ast.Expr)
	if !ok {
		return cue.Value{}, fmt.Errorf("finalization produced %T instead of ast.Expr", node)
	}
	out := cctx.BuildExpr(expr)
	if err := out.Err(); err != nil {
		return cue.Value{}, err
	}
	return out, nil
}

// instanceContext renders the #moduleInstanceMetadata literal from the
// instance value, mirroring schema.ModuleInstanceContextData's fields.
func instanceContext(inst cue.Value) (string, error) {
	get := func(path string) (string, error) {
		v := inst.LookupPath(cue.ParsePath(path))
		s, err := v.String()
		if err != nil {
			return "", fmt.Errorf("reading %s: %w", path, err)
		}
		return s, nil
	}
	name, err := get("metadata.name")
	if err != nil {
		return "", err
	}
	ns, err := get("metadata.namespace")
	if err != nil {
		return "", err
	}
	fqn, err := get("metadata.fqn")
	if err != nil {
		return "", err
	}
	uuid, err := get("metadata.uuid")
	if err != nil {
		return "", err
	}
	versionVal := inst.LookupPath(cue.MakePath(cue.Def("moduleMetadata"), cue.Str("version")))
	version, err := versionVal.String()
	if err != nil {
		return "", fmt.Errorf("reading #moduleMetadata.version: %w", err)
	}
	return fmt.Sprintf("{name: %q, namespace: %q, fqn: %q, uuid: %q, version: %q}",
		name, ns, fqn, uuid, version), nil
}

func loadErr(insts []*build.Instance) error {
	if len(insts) == 0 {
		return fmt.Errorf("no instances")
	}
	return insts[0].Err
}

func finishMem(r *armResult, before runtime.MemStats, n int) {
	after := memSnapshot()
	if n > 0 && after.TotalAlloc > before.TotalAlloc {
		r.AllocPerRender = (after.TotalAlloc - before.TotalAlloc) / uint64(n)
	}
	r.HeapInuse = after.HeapInuse
}
