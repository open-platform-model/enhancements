package main

// COPIED from experiments/07-module-scale-cost/arms.go, with two additions for
// concurrency: guard() recovers a panic per render so one strategy dying does
// not erase the whole run, and phases carries a Wall field so per-render
// latency under contention is visible next to the phase breakdown.

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sort"
	"strings"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/ast"
	"cuelang.org/go/cue/build"
	"cuelang.org/go/cue/load"
)

// Paths copied from library/opm/schema/paths.go, per the experiments protocol.
// Worth reading side by side: definition paths on closed structs resolve only
// when built with cue.Def, which is why #context is a MakePath and #component
// is not.
var (
	pathRendered   = cue.ParsePath("rendered")
	pathInstance   = cue.ParsePath("instance")
	pathComponents = cue.ParsePath("components")
	pathTransform  = cue.ParsePath("#transform")
	pathComponent  = cue.ParsePath("#component")
	pathContext    = cue.MakePath(cue.Def("context"))
	pathOutput     = cue.ParsePath("output")
)

// ---------------------------------------------------------------------------
// The single-build arm
// ---------------------------------------------------------------------------

// renderOnce is the whole single-build render path: load, build, force
// concrete, export. The context policy (fresh per render, or one shared for the
// whole point) is the caller's, because experiments 04 and 06 disagree about
// which is preferable and this experiment measures cost at a size neither of
// them covered.
func renderOnce(cctx *cue.Context, dir string) (phases, digests, int, error) {
	var p phases

	t0 := time.Now()
	insts := load.Instances([]string{"."}, &load.Config{Dir: dir})
	p.Load = time.Since(t0)
	if len(insts) == 0 {
		return p, digests{}, 0, fmt.Errorf("no instances loaded from %s", dir)
	}
	if err := insts[0].Err; err != nil {
		return p, digests{}, 0, fmt.Errorf("load: %w", err)
	}

	t1 := time.Now()
	v := cctx.BuildInstance(insts[0])
	p.Build = time.Since(t1)
	if err := v.Err(); err != nil {
		return p, digests{}, 0, fmt.Errorf("build: %w", err)
	}

	// Validate(Concrete) is what forces the evaluation. Experiment 04 measured
	// that the work has already happened inside BuildInstance by the time this
	// runs, so EVAL reads near zero here; the call stays because without it the
	// arm would be timing a promise rather than a render.
	t2 := time.Now()
	rendered := v.LookupPath(pathRendered)
	if err := rendered.Validate(cue.Concrete(true)); err != nil {
		p.Eval = time.Since(t2)
		return p, digests{}, 0, fmt.Errorf("eval: %w", err)
	}
	p.Eval = time.Since(t2)

	t3 := time.Now()
	parts, err := marshalPairs(rendered)
	if err != nil {
		return p, digests{}, 0, err
	}
	p.Export = time.Since(t3)

	if dumpParts != nil {
		dumpParts("single__"+dir[strings.LastIndex(dir, "/")+1:], parts)
	}
	return p, digests{Strict: digestOf(parts), Loose: looseDigest(parts)}, len(parts), nil
}

// marshalPairs turns the rendered map into (key -> JSON bytes). Both arms go
// through this, so the digests they produce are comparable: CUE emits struct
// fields in source order while the baseline builds its outputs in pair order,
// and hashing a sorted map is what removes that difference from the comparison.
func marshalPairs(rendered cue.Value) (map[string][]byte, error) {
	it, err := rendered.Fields()
	if err != nil {
		return nil, fmt.Errorf("iterating rendered: %w", err)
	}
	out := map[string][]byte{}
	for it.Next() {
		b, err := it.Value().MarshalJSON()
		if err != nil {
			return nil, fmt.Errorf("export %s: %w", it.Selector().Unquoted(), err)
		}
		c, err := canonicalJSON(b)
		if err != nil {
			return nil, fmt.Errorf("canonicalize %s: %w", it.Selector().Unquoted(), err)
		}
		out[it.Selector().Unquoted()] = c
	}
	return out, nil
}

// digestOf is the guard that makes every claim in this experiment checkable.
//
// Three things ride on it: that the blueprint and raw variants of a fixture
// render the SAME bytes (so the cost difference between them is authoring style
// and nothing else), that consecutive renders in a point render DIFFERENT bytes
// (so no render was answered out of another render's evaluation state), and
// that the single build and the baseline agree (reported, not asserted, since
// the baseline is deliberately not parity-correct).
// canonicalJSON re-encodes one rendered object with every object key sorted.
//
// It exists because the two authoring styles produce the same rendered value in
// a different FIELD ORDER: a blueprint contributes
// "core.opmodel.dev/workload-type" to metadata.labels at a different point in
// the component body than a hand-written label does, and CUE emits struct
// fields in source order. A Kubernetes label map is unordered, so hashing the
// unsorted bytes would report a difference that does not exist in the object.
// Numbers are decoded as json.Number so a large integer is not round-tripped
// through float64.
func canonicalJSON(b []byte) ([]byte, error) {
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.UseNumber()
	var v any
	if err := dec.Decode(&v); err != nil {
		return nil, err
	}
	// encoding/json sorts map keys on the way out, which is the canonical form.
	return json.Marshal(v)
}

// dumpParts is a diagnostic hook: when -dump is set, the first render of every
// (point, arm) writes its canonicalized parts here so a digest mismatch can be
// read rather than guessed at.
var dumpParts func(tag string, parts map[string][]byte)

// digests is the pair of readings taken from one render: STRICT is the bytes as
// rendered (object keys sorted, array order preserved), LOOSE additionally
// sorts arrays. Equal strict digests mean identical output; equal loose but
// different strict digests mean the same objects in a different list order.
type digests struct {
	Strict string
	Loose  string
}

// looseDigest is digestOf with every JSON ARRAY of objects sorted too.
//
// A diagnostic, not a guard. It exists because the single build and the
// baseline were found to render the same objects with container `env` lists in
// a DIFFERENT ORDER: finalization re-emits a component through
// Syntax(cue.Final()), which hoists comprehension-produced fields ahead of
// plainly-declared ones, and the catalog converts the env MAP to a Kubernetes
// LIST downstream. Comparing both digests is what lets the report say "the same
// objects in a different list order" instead of "different".
func looseDigest(parts map[string][]byte) string {
	loose := make(map[string][]byte, len(parts))
	for k, v := range parts {
		dec := json.NewDecoder(bytes.NewReader(v))
		dec.UseNumber()
		var any0 any
		if err := dec.Decode(&any0); err != nil {
			return ""
		}
		b, err := json.Marshal(sortDeep(any0))
		if err != nil {
			return ""
		}
		loose[k] = b
	}
	return digestOf(loose)
}

// sortDeep sorts every array by the serialization of its elements. Order is
// meaningful in JSON, which is exactly why this is a separate reading rather
// than the canonical form.
func sortDeep(v any) any {
	switch t := v.(type) {
	case map[string]any:
		for k, e := range t {
			t[k] = sortDeep(e)
		}
		return t
	case []any:
		for i, e := range t {
			t[i] = sortDeep(e)
		}
		sort.Slice(t, func(i, j int) bool {
			bi, _ := json.Marshal(t[i])
			bj, _ := json.Marshal(t[j])
			return string(bi) < string(bj)
		})
		return t
	default:
		return v
	}
}

func digestOf(parts map[string][]byte) string {
	keys := make([]string, 0, len(parts))
	for k := range parts {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	h := sha256.New()
	for _, k := range keys {
		h.Write([]byte(k))
		h.Write([]byte{0})
		h.Write(parts[k])
		h.Write([]byte{0})
	}
	return hex.EncodeToString(h.Sum(nil))[:16]
}

// ---------------------------------------------------------------------------
// The baseline arm: today's path
// ---------------------------------------------------------------------------

// platformHold mirrors library/opm/compile/execute.go: the platform and its
// catalog are built ONCE and held, and each instance is filled into the held
// transformer values across the build boundary.
//
// It is deliberately NOT parity-correct. Finalization is the strip this whole
// enhancement exists to remove, and the #context here is constructed in Go
// exactly because the definition fields a CUE projection would read are gone by
// then. It is a cost yardstick and nothing else.
//
// Experiment 06 additionally measured that sharing one held platform across
// goroutines races (2321 reports), so nothing here may be reused concurrently.
// This harness is sequential, which is the shape 06 measured as safe.
type platformHold struct {
	transformers cue.Value
	build        time.Duration
}

func holdPlatform(cctx *cue.Context, renderDir string) (*platformHold, error) {
	t0 := time.Now()
	insts := load.Instances([]string{"./baseline"}, &load.Config{Dir: renderDir})
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
	// Force it concrete once, outside every timed render, so the hold is a
	// hold rather than a promise the first render would pay for.
	if err := transformers.Validate(); err != nil {
		return nil, fmt.Errorf("baseline validate: %w", err)
	}
	return &platformHold{transformers: transformers, build: time.Since(t0)}, nil
}

// pair is one (component, transformer FQN) to execute.
type pair struct {
	component string
	fqn       string
}

// resolvePairs turns the point's short names into FQNs against the held
// transformer map. Same lookup the CUE glue does, resolved the same way, so no
// version is restated as data on either side.
func resolvePairs(transformers cue.Value, wants map[string][]string) ([]pair, error) {
	it, err := transformers.Fields()
	if err != nil {
		return nil, fmt.Errorf("iterating transformers: %w", err)
	}
	var keys []string
	for it.Next() {
		keys = append(keys, it.Selector().Unquoted())
	}
	comps := make([]string, 0, len(wants))
	for c := range wants {
		comps = append(comps, c)
	}
	sort.Strings(comps)

	var out []pair
	for _, comp := range comps {
		for _, short := range wants[comp] {
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

func baselineRender(cctx *cue.Context, instDir string, hold *platformHold, pairs []pair) (phases, digests, int, error) {
	var p phases

	t0 := time.Now()
	insts := load.Instances([]string{"."}, &load.Config{Dir: instDir})
	p.Load = time.Since(t0)
	if len(insts) == 0 || insts[0].Err != nil {
		return p, digests{}, 0, fmt.Errorf("load: %v", loadErr(insts))
	}

	t1 := time.Now()
	v := cctx.BuildInstance(insts[0])
	p.Build = time.Since(t1)
	if err := v.Err(); err != nil {
		return p, digests{}, 0, fmt.Errorf("build: %w", err)
	}

	t2 := time.Now()
	inst := v.LookupPath(pathInstance)
	schemaComponents := inst.LookupPath(pathComponents)
	dataComponents, err := finalizeValue(cctx, schemaComponents)
	if err != nil {
		p.Eval = time.Since(t2)
		return p, digests{}, 0, fmt.Errorf("finalize: %w", err)
	}

	// #context is built in Go, which is what the kernel does today
	// (library/opm/schema/context.go decodes into structs and re-encodes). The
	// instance-level half is identical for every pair, so it is built once per
	// render rather than once per pair, matching the kernel's shape.
	mim, err := instanceContext(inst)
	if err != nil {
		p.Eval = time.Since(t2)
		return p, digests{}, 0, err
	}

	outputs := make([]cue.Value, 0, len(pairs))
	for _, pr := range pairs {
		transform := hold.transformers.
			LookupPath(cue.MakePath(cue.Str(pr.fqn))).
			LookupPath(pathTransform)
		if !transform.Exists() {
			p.Eval = time.Since(t2)
			return p, digests{}, 0, fmt.Errorf("#transform not found for %s", pr.fqn)
		}

		dataComp := dataComponents.LookupPath(cue.MakePath(cue.Str(pr.component)))
		unified := transform.FillPath(pathComponent, dataComp)
		if err := unified.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, digests{}, 0, fmt.Errorf("fill #component (%s): %w", pr.fqn, err)
		}

		ctxVal := cctx.CompileString(fmt.Sprintf(`{
	#moduleInstanceMetadata: %s
	#componentMetadata: %s
	#runtimeName: "concurrent-render-at-scale"
}`, mim, componentContext(dataComponents, pr.component)))
		if err := ctxVal.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, digests{}, 0, fmt.Errorf("build #context: %w", err)
		}
		unified = unified.FillPath(pathContext, ctxVal)
		if err := unified.Err(); err != nil {
			p.Eval = time.Since(t2)
			return p, digests{}, 0, fmt.Errorf("fill #context (%s): %w", pr.fqn, err)
		}

		out := unified.LookupPath(pathOutput)
		if err := out.Validate(cue.Concrete(true)); err != nil {
			p.Eval = time.Since(t2)
			return p, digests{}, 0, fmt.Errorf("eval output (%s): %w", pr.fqn, err)
		}
		outputs = append(outputs, out)
	}
	p.Eval = time.Since(t2)

	t3 := time.Now()
	parts := map[string][]byte{}
	for i, o := range outputs {
		b, err := o.MarshalJSON()
		if err != nil {
			return p, digests{}, 0, fmt.Errorf("export: %w", err)
		}
		c, err := canonicalJSON(b)
		if err != nil {
			return p, digests{}, 0, fmt.Errorf("canonicalize: %w", err)
		}
		parts[pairs[i].component+" :: "+pairs[i].fqn] = c
	}
	p.Export = time.Since(t3)

	if dumpParts != nil {
		dumpParts("base__"+instDir[strings.LastIndex(instDir, "/")+1:], parts)
	}
	return p, digests{Strict: digestOf(parts), Loose: looseDigest(parts)}, len(outputs), nil
}

// finalizeValue is library/opm/compile/finalize.go, copied verbatim in
// behaviour: export through cue.Final() and rebuild. cue.Final() sets
// omitDefinitions, which is precisely why the value it returns cannot carry
// #names, #resources, #traits or #blueprints into a transformer -- and, for
// this experiment, why the baseline never pays for the definitional payload the
// single build carries.
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
	// labels and annotations are projected too, which experiment 04's
	// baseline did not do. They are not decoration: core puts the module's
	// and the instance's identity labels on #ModuleInstance.metadata.labels,
	// and #TransformerContext folds them onto every rendered object through
	// moduleLabels. Omitting them here made the baseline render five fewer
	// labels than the single build on the same input -- a difference in the
	// harness, not in the design, and one that would have been invisible
	// without the cross-arm digest comparison.
	extra := ""
	for _, field := range []string{"labels", "annotations"} {
		v := inst.LookupPath(cue.ParsePath("metadata." + field))
		if !v.Exists() {
			continue
		}
		j, err := v.MarshalJSON()
		if err != nil {
			continue
		}
		extra += fmt.Sprintf(", %s: %s", field, string(j))
	}
	return fmt.Sprintf("{name: %q, namespace: %q, fqn: %q, uuid: %q, version: %q%s}",
		name, ns, fqn, uuid, version, extra), nil
}

// componentContext renders #componentMetadata for one component. Unlike
// experiment 04's fixture, these components carry labels AND annotations that
// reach rendered output, so the baseline has to project both or its bytes would
// differ from the single build's for a reason that is the harness's fault
// rather than the design's.
func componentContext(dataComponents cue.Value, id string) string {
	comp := dataComponents.LookupPath(cue.MakePath(cue.Str(id)))
	var b strings.Builder
	fmt.Fprintf(&b, "{name: %q", id)
	for _, field := range []string{"labels", "annotations"} {
		v := comp.LookupPath(cue.ParsePath("metadata." + field))
		if !v.Exists() {
			continue
		}
		j, err := v.MarshalJSON()
		if err != nil {
			continue
		}
		fmt.Fprintf(&b, ", %s: %s", field, string(j))
	}
	b.WriteString("}")
	return b.String()
}

func loadErr(insts []*build.Instance) error {
	if len(insts) == 0 {
		return fmt.Errorf("no instances")
	}
	return insts[0].Err
}
