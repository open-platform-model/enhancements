package main

// The render primitives, copied from experiments/04-render-build-cost/arms.go.
// Copied rather than imported, per the experiments protocol: a later edit to
// experiment 04 must not change what this one measured.
//
// Two things are added and nothing else is changed. Every render now returns a
// SHA-256 of its exported output, because the failure mode this experiment is
// most afraid of is a concurrency bug that produces a wrong value rather than a
// crash, and a throughput number would hide it. And the per-render work is
// wrapped so a panic becomes a recorded sample rather than the end of the run.

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"runtime/debug"
	"strings"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/ast"
	"cuelang.org/go/cue/build"
	"cuelang.org/go/cue/load"
)

// Paths copied from library/opm/schema/paths.go. Definition paths on closed
// structs resolve only when built with cue.Def, which is why #context is a
// MakePath and #component is not.
var (
	pathRendered   = cue.ParsePath("rendered")
	pathInstance   = cue.ParsePath("instance")
	pathComponents = cue.ParsePath("components")
	pathTransform  = cue.ParsePath("#transform")
	pathComponent  = cue.ParsePath("#component")
	pathContext    = cue.MakePath(cue.Def("context"))
	pathOutput     = cue.ParsePath("output")
)

// expectOutputs is the number of rendered resources this fixture must produce:
// four for the web component, one for config. Asserted on every render because
// an empty `rendered` evaluates instantly, and a worker that silently rendered
// nothing would report as the fastest one.
const expectOutputs = 5

// phases is the per-render breakdown, kept identical to experiment 04's so the
// two sets of numbers are read the same way.
type phases struct {
	Load   time.Duration // load.Instances: resolution, fetch, parse
	Build  time.Duration // ctx.BuildInstance
	Eval   time.Duration // forcing the rendered value concrete
	Export time.Duration // marshalling
	Wall   time.Duration // the whole render, measured by the worker
}

func (p phases) total() time.Duration { return p.Load + p.Build + p.Eval + p.Export }

// env returns the process environment with CUE_CACHE_DIR pointed at dir.
// load.Config.Env is the only lever for the cache location: modconfig builds
// its registry from these values (modconfig.NewRegistry -> cueconfig.CacheDir).
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
// concrete, export. Strategies S1, S2 and S3 call exactly this and differ only
// in which cue.Context they hand it.
func renderOnce(cctx *cue.Context, dir string) (phases, string, error) {
	var p phases
	e := env("")

	t0 := time.Now()
	insts := load.Instances([]string{"."}, &load.Config{Dir: dir, Env: e})
	p.Load = time.Since(t0)
	if len(insts) == 0 {
		return p, "", fmt.Errorf("no instances loaded from %s", dir)
	}
	if err := insts[0].Err; err != nil {
		return p, "", fmt.Errorf("load: %w", err)
	}

	t1 := time.Now()
	v := cctx.BuildInstance(insts[0])
	p.Build = time.Since(t1)
	if err := v.Err(); err != nil {
		return p, "", fmt.Errorf("build: %w", err)
	}

	// Validate(Concrete) is what forces the evaluation. Without it the value is
	// lazy and the worker would be timing a promise rather than a render.
	t2 := time.Now()
	rendered := v.LookupPath(pathRendered)
	if err := rendered.Validate(cue.Concrete(true)); err != nil {
		p.Eval = time.Since(t2)
		return p, "", fmt.Errorf("eval: %w", err)
	}
	p.Eval = time.Since(t2)

	t3 := time.Now()
	b, err := rendered.MarshalJSON()
	if err != nil {
		return p, "", fmt.Errorf("export: %w", err)
	}
	p.Export = time.Since(t3)

	if n := countFields(rendered); n != expectOutputs {
		return p, "", fmt.Errorf("rendered %d outputs, expected %d", n, expectOutputs)
	}
	return p, digest(b), nil
}

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

func digest(chunks ...[]byte) string {
	h := sha256.New()
	for _, c := range chunks {
		h.Write(c)
		h.Write([]byte{0})
	}
	return hex.EncodeToString(h.Sum(nil))[:16]
}

// ---------------------------------------------------------------------------
// The baseline path: today's kernel shape
// ---------------------------------------------------------------------------
//
// Mirrors library/opm/compile/execute.go. The platform and its catalog are
// built ONCE in their own context and held read-only; each instance is built in
// the CALLER's context, its components are finalized there
// (library/opm/compile/finalize.go), and the finalized value is filled into a
// transformer owned by the platform's context. That cross-context fill is
// exactly what ADR-002 declared legal on CUE v0.17 and what strategy S4 puts
// under load.
//
// It is deliberately NOT parity-correct: finalization is the strip this whole
// enhancement exists to remove, and #context is constructed in Go precisely
// because the definition fields a CUE projection would read are gone by then.
// It is a yardstick, nothing more.

// platformHold is the shared, read-only materialized platform: one built value
// plus the pairs resolved off it. Built once per point, outside every timed
// render, and then read by every worker at once.
type platformHold struct {
	transformers cue.Value
	pairs        []pair
	build        time.Duration
}

func holdPlatform(cctx *cue.Context, renderDir string) (*platformHold, error) {
	t0 := time.Now()
	insts := load.Instances([]string{"./baseline"}, &load.Config{Dir: renderDir, Env: env("")})
	if len(insts) == 0 || insts[0].Err != nil {
		return nil, fmt.Errorf("baseline load: %v", loadErr(insts))
	}
	base := cctx.BuildInstance(insts[0])
	if err := base.Err(); err != nil {
		return nil, fmt.Errorf("baseline build: %w", err)
	}
	transformers := base.LookupPath(cue.ParsePath("transformers"))
	if err := transformers.Err(); err != nil {
		return nil, fmt.Errorf("baseline transformers: %w", err)
	}
	// Forced concrete here, once, so no worker pays a lazy evaluation of the
	// catalog that another worker would then be blocked on. A held platform
	// that is still lazy is not the thing ADR-002 describes.
	if err := transformers.Validate(); err != nil {
		return nil, fmt.Errorf("baseline validate: %w", err)
	}
	pairs, err := resolvePairs(transformers)
	if err != nil {
		return nil, err
	}
	return &platformHold{transformers: transformers, pairs: pairs, build: time.Since(t0)}, nil
}

// forceWalk touches every reachable vertex of v, definitions and hidden fields
// included, so the value graph is fully evaluated before anyone else sees it.
//
// It exists because of what strategy S4 found. Sharing a HELD platform is not
// one thing: it is either sharing an evaluated value (concurrent reads, which
// CUE v0.17 documents as safe) or sharing a lazy one (concurrent evaluation,
// which mutates scheduler state on the shared vertices). S5 is S4 plus this
// call, and the difference between the two isolates which of the two ADR-002
// actually relies on.
//
// The depth cap is not decoration: a CUE value graph can be recursive, and a
// walk without one does not terminate.
func forceWalk(v cue.Value, depth int) {
	if depth > 48 || v.Err() != nil {
		return
	}
	v = v.Eval()
	if it, err := v.Fields(cue.All()); err == nil {
		for it.Next() {
			forceWalk(it.Value(), depth+1)
		}
	}
	if it, err := v.List(); err == nil {
		for it.Next() {
			forceWalk(it.Value(), depth+1)
		}
	}
}

// pair is one (component, transformer FQN) to execute. The same five pairs the
// CUE glue selects, resolved by short name so no version is restated as data.
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

func baselineRender(cctx *cue.Context, instDir string, hold *platformHold) (phases, string, error) {
	var p phases

	t0 := time.Now()
	insts := load.Instances([]string{"."}, &load.Config{Dir: instDir, Env: env("")})
	p.Load = time.Since(t0)
	if len(insts) == 0 || insts[0].Err != nil {
		return p, "", fmt.Errorf("load: %v", loadErr(insts))
	}

	t1 := time.Now()
	v := cctx.BuildInstance(insts[0])
	p.Build = time.Since(t1)
	if err := v.Err(); err != nil {
		return p, "", fmt.Errorf("build: %w", err)
	}

	t2 := time.Now()
	inst := v.LookupPath(pathInstance)
	schemaComponents := inst.LookupPath(pathComponents)
	dataComponents, err := finalizeValue(cctx, schemaComponents)
	if err != nil {
		p.Eval = time.Since(t2)
		return p, "", fmt.Errorf("finalize: %w", err)
	}

	// #context is built in Go, which is what the kernel does today
	// (library/opm/schema/context.go decodes into structs and re-encodes), in
	// the CALLER's context -- the recontract ADR-002 gated.
	mim, err := instanceContext(inst)
	if err != nil {
		p.Eval = time.Since(t2)
		return p, "", err
	}

	var outputs []cue.Value
	for _, pr := range hold.pairs {
		transform := hold.transformers.
			LookupPath(cue.MakePath(cue.Str(pr.fqn))).
			LookupPath(pathTransform)
		if !transform.Exists() {
			p.Eval = time.Since(t2)
			return p, "", fmt.Errorf("#transform not found for %s", pr.fqn)
		}

		dataComp := dataComponents.LookupPath(cue.MakePath(cue.Str(pr.component)))
		unified := transform.FillPath(pathComponent, dataComp)
		if err := unified.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, "", fmt.Errorf("fill #component (%s): %w", pr.fqn, err)
		}

		ctxVal := cctx.CompileString(fmt.Sprintf(`{
	#moduleInstanceMetadata: %s
	#componentMetadata: {name: %q}
	#runtimeName: "concurrent-render"
}`, mim, pr.component))
		if err := ctxVal.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, "", fmt.Errorf("build #context: %w", err)
		}
		unified = unified.FillPath(pathContext, ctxVal)
		if err := unified.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, "", fmt.Errorf("fill #context (%s): %w", pr.fqn, err)
		}

		out := unified.LookupPath(pathOutput)
		if err := out.Validate(cue.Concrete(true)); err != nil {
			p.Eval = time.Since(t2)
			return p, "", fmt.Errorf("eval output (%s): %w", pr.fqn, err)
		}
		outputs = append(outputs, out)
	}
	p.Eval = time.Since(t2)

	if len(outputs) != expectOutputs {
		return p, "", fmt.Errorf("rendered %d outputs, expected %d", len(outputs), expectOutputs)
	}

	t3 := time.Now()
	var chunks [][]byte
	for _, o := range outputs {
		b, err := o.MarshalJSON()
		if err != nil {
			return p, "", fmt.Errorf("export: %w", err)
		}
		chunks = append(chunks, b)
	}
	p.Export = time.Since(t3)

	return p, digest(chunks...), nil
}

// finalizeValue is library/opm/compile/finalize.go, copied verbatim in
// behaviour: export through cue.Final() and rebuild. cue.Final() sets
// omitDefinitions, which is why the value it returns cannot carry #names,
// #resources, #traits or #instance into a transformer.
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

// instanceContext renders the #moduleInstanceMetadata literal from the instance
// value, mirroring schema.ModuleInstanceContextData's fields.
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

// guard turns a panic inside one render into a recorded failure for that render
// only. It cannot catch a runtime throw (a concurrent map write is fatal and
// unrecoverable by design), which is why run.sh gives every strategy its own
// process: for S3 the way it dies is the result.
func guard(f func() (phases, string, error)) (p phases, dig string, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic: %v\n%s", r, firstLines(string(debug.Stack()), 12))
		}
	}()
	return f()
}

func firstLines(s string, n int) string {
	lines := strings.Split(s, "\n")
	if len(lines) > n {
		lines = lines[:n]
	}
	return strings.Join(lines, "\n")
}
