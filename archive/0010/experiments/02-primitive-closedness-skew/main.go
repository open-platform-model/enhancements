// Experiment 02 — primitive closedness under build skew.
//
// Replicates library/opm/compile/match.go's always-unify rung
// (unifyIntersection, match.go:243-278) verbatim, over a component and a
// transformer built from DIFFERENT builds of one primitive that share one
// MAJOR-keyed FQN. The question: does CUE's closedness make a component field
// the provider's build never declared a hard failure, or does the unification
// succeed and the field silently disappear?
//
// Faithfulness notes:
//   - The two sides are loaded from two separate module roots (mod/, prov/)
//     that declare the same module path, mirroring 0001/experiments/11. That
//     is how the real system sees it: the component comes from the module's
//     own build (compile/module.go) and the transformer from materialize's
//     separate pullCatalog build (materialize/pull.go:23).
//   - Both are built with ONE shared *cue.Context, exactly as materialize's
//     octx is shared with the compile path.
//   - The unify + Validate(cue.Concrete(false)) call is copied, not
//     approximated. `cue vet` is NOT the code path and is not used here.
package main

import (
	"fmt"
	"os"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	cueerrors "cuelang.org/go/cue/errors"
	"cuelang.org/go/cue/load"
)

// Paths copied from library/opm/schema/paths.go.
var (
	componentResources           = cue.MakePath(cue.Def("resources"))
	transformerRequiredResources = cue.ParsePath("requiredResources")
)

type verdict int

const (
	wantPass verdict = iota
	wantFail
)

func (v verdict) String() string {
	if v == wantPass {
		return "unify PASSES"
	}
	return "unify FAILS"
}

type testCase struct {
	name   string
	demand string  // package dir under mod/
	supply string  // package dir under prov/
	expect verdict // predicted outcome for SPEC-ONLY unification
	why    string
	// probe, when set, is a path inside the unified resource whose resolved
	// value is printed — used for the default-drift case, where the question
	// is not whether unification errors but what value survives it.
	probe string
}

// scope selects what gets unified. `whole` is what match.go does today: the
// entire primitive value, metadata included. `specOnly` unifies just the
// contract surface. The difference turned out to be the experiment's main
// finding, so both are measured for every case.
type scope struct {
	name string
	path string // "" = the whole value
	// skipMetadata keeps the whole (closed) value in the unification but
	// discards conflicts under metadata — the candidate fix for provenance
	// fields that legitimately differ between builds.
	skipMetadata bool
}

var scopes = []scope{
	{name: "whole value (match.go today)", path: ""},
	{name: "spec only", path: "spec"},
	{name: "whole value, metadata ignored", path: "", skipMetadata: true},
}

var cases = []testCase{
	{
		name:   "1. lagging provider, module USES the added field",
		demand: "demand_11_uses", supply: "supply_10",
		expect: wantFail,
		why:    "the decisive case: module on 1.1.0 sets `retention`; provider compiled on 1.0.0 never declared it",
	},
	{
		name:   "2. lagging provider, module does not use it",
		demand: "demand_11_plain", supply: "supply_10",
		expect: wantPass,
		why:    "same skew as case 1, but the module stays inside the fields both builds share",
	},
	{
		name:   "3. provider ahead of module",
		demand: "demand_10_plain", supply: "supply_11",
		expect: wantPass,
		why:    "the direction the additive promise is supposed to make free",
	},
	{
		name:   "4. same build (control)",
		demand: "demand_11_plain", supply: "supply_11",
		expect: wantPass,
		why:    "no skew at all; must not fail or the harness is measuring itself",
	},
	{
		name:   "5. provider ahead, but its build BROKE the promise (narrowing)",
		demand: "demand_10_hourly", supply: "supply_12",
		expect: wantFail,
		why:    "1.2.0 narrowed `schedule` to a disjunction; the module's value is legal in 1.0.0 and not in 1.2.0",
	},
	{
		name:   "6. default drift — nothing added, nothing removed",
		demand: "demand_13_default", supply: "supply_10",
		expect: wantPass,
		why:    "1.3.0 flipped `mode`'s default; subsumption-clean, and the probe shows what the render would get",
		probe:  "spec.backup.mode",
	},
	{
		name:   "7. pattern-constraint shape, module USES the added field",
		demand: "demand_11p_uses", supply: "supply_10p",
		expect: wantFail,
		why:    "case 1 against a spec whose body is a pattern constraint, the other shape catalog_opm ships",
	},
}

func main() {
	ctx := cuecontext.New()

	failures := 0
	for _, tc := range cases {
		fmt.Printf("\n\033[1m%s\033[0m\n", tc.name)
		fmt.Printf("  %s\n", tc.why)
		fmt.Printf("  demand mod/%s   supply prov/%s\n", tc.demand, tc.supply)

		comp, err := lookup(ctx, "mod", tc.demand, "components.web")
		if err != nil {
			fmt.Printf("  \033[31mHARNESS ERROR\033[0m %v\n", err)
			failures++
			continue
		}
		tf, err := lookup(ctx, "prov", tc.supply, "transformer")
		if err != nil {
			fmt.Printf("  \033[31mHARNESS ERROR\033[0m %v\n", err)
			failures++
			continue
		}

		printedKey := false
		for _, sc := range scopes {
			results := unifyIntersection(comp, tf, sc)
			if len(results) == 0 {
				fmt.Printf("  \033[31mHARNESS ERROR\033[0m no FQN in the intersection — the two sides do not share a key\n")
				failures++
				continue
			}

			for _, r := range results {
				if !printedKey {
					fmt.Printf("  key            %s\n", r.fqn)
					fmt.Printf("  built against  component %s   transformer %s\n", r.haveVersion, r.reqVersion)
					printedKey = true
				}
				fmt.Printf("  [%-29s] ", sc.name)
				if r.err == nil {
					fmt.Printf("\033[32munify PASSES\033[0m\n")
				} else {
					fmt.Printf("\033[33munify FAILS\033[0m\n")
					for _, line := range strings.Split(strings.TrimSpace(r.err.Error()), "\n") {
						fmt.Printf("                                 %s\n", line)
					}
				}
				if tc.probe != "" && sc.skipMetadata {
					printProbe(r.unified, tc.probe)
				}

				// Only the candidate scope carries a prediction. The other two
				// are characterised, not predicted — the gap between them is
				// what this experiment measures.
				if !sc.skipMetadata {
					continue
				}
				got := wantPass
				if r.err != nil {
					got = wantFail
				}
				if got == tc.expect {
					fmt.Printf("  verdict        \033[32mAS PREDICTED\033[0m (%s)\n", tc.expect)
				} else {
					fmt.Printf("  verdict        \033[31mUNEXPECTED\033[0m — predicted %s\n", tc.expect)
					failures++
				}
			}
		}
	}

	fmt.Printf("\n\033[1m%d of %d cases behaved as predicted.\033[0m\n", len(cases)-failures, len(cases))
	if failures > 0 {
		os.Exit(1)
	}
}

type unifyResult struct {
	fqn         string
	haveVersion string // catalogVersion the component's copy carries
	reqVersion  string // catalogVersion the transformer's copy carries
	unified     cue.Value
	err         error
}

// unifyIntersection is copied from library/opm/compile/match.go:243-278, with
// the plan-recording replaced by a returned slice and the two catalogVersion
// values read out alongside (the provenance the transformer's map already
// carries, with no extra field).
func unifyIntersection(comp, tf cue.Value, sc scope) []unifyResult {
	have := comp.LookupPath(componentResources)
	required := tf.LookupPath(transformerRequiredResources)
	if !required.Exists() {
		return nil
	}
	iter, err := required.Fields(cue.Optional(true))
	if err != nil {
		return nil
	}
	var out []unifyResult
	for iter.Next() {
		fqn := iter.Selector().Unquoted()
		cv := have.LookupPath(cue.MakePath(cue.Str(fqn)))
		if !cv.Exists() {
			// Not in the intersection — the predicate's subset check handles a
			// required primitive the component lacks.
			continue
		}
		rv := iter.Value()
		haveVersion := str(cv.LookupPath(cue.ParsePath("metadata.catalogVersion")))
		reqVersion := str(rv.LookupPath(cue.ParsePath("metadata.catalogVersion")))
		if sc.path != "" {
			cv = cv.LookupPath(cue.ParsePath(sc.path))
			rv = rv.LookupPath(cue.ParsePath(sc.path))
		}
		unified := cv.Unify(rv)
		vErr := unified.Validate(cue.Concrete(false))
		if sc.skipMetadata {
			vErr = dropMetadataErrors(vErr)
		}
		out = append(out, unifyResult{
			fqn:         fqn,
			haveVersion: haveVersion,
			reqVersion:  reqVersion,
			unified:     unified,
			err:         vErr,
		})
	}
	return out
}

// dropMetadataErrors filters out every conflict whose path passes through a
// `metadata` segment, leaving contract-surface conflicts intact. A real
// implementation would compare the two metadata blocks structurally rather
// than filter error paths; this is the cheapest way to measure whether the
// remaining signal is the one the design needs.
func dropMetadataErrors(err error) error {
	if err == nil {
		return nil
	}
	var kept []error
	for _, e := range cueerrors.Errors(err) {
		isMeta := false
		for _, seg := range e.Path() {
			if seg == "metadata" {
				isMeta = true
				break
			}
		}
		if !isMeta {
			kept = append(kept, e)
		}
	}
	if len(kept) == 0 {
		return nil
	}
	var b strings.Builder
	for i, e := range kept {
		if i > 0 {
			b.WriteString("\n")
		}
		b.WriteString(e.Error())
	}
	return fmt.Errorf("%s", b.String())
}

func printProbe(v cue.Value, path string) {
	p := v.LookupPath(cue.ParsePath(path))
	if !p.Exists() {
		fmt.Printf("  probe %-8s \033[31mabsent\033[0m\n", path)
		return
	}
	concrete := p.Validate(cue.Concrete(true)) == nil
	fmt.Printf("  probe %s = %v   (concrete after unification: %t)\n", path, p, concrete)
	if !concrete {
		fmt.Printf("                 \033[33m^ neither build's default survives; the render has no value here\033[0m\n")
	}
}

func str(v cue.Value) string {
	s, err := v.String()
	if err != nil {
		return "<none>"
	}
	return s
}

// lookup builds one package from one module root and returns the value at
// exprPath. Each root is loaded independently — separate load.Instances calls,
// one shared context — which is the shape materialize + compile actually have.
func lookup(ctx *cue.Context, root, pkg, exprPath string) (cue.Value, error) {
	insts := load.Instances([]string{"./" + pkg}, &load.Config{Dir: root})
	if len(insts) == 0 {
		return cue.Value{}, fmt.Errorf("%s/%s: no instances", root, pkg)
	}
	if insts[0].Err != nil {
		return cue.Value{}, fmt.Errorf("loading %s/%s: %w", root, pkg, insts[0].Err)
	}
	v := ctx.BuildInstance(insts[0])
	if v.Err() != nil {
		return cue.Value{}, fmt.Errorf("building %s/%s: %w", root, pkg, v.Err())
	}
	out := v.LookupPath(cue.ParsePath(exprPath))
	if !out.Exists() {
		return cue.Value{}, fmt.Errorf("%s/%s: %s not found", root, pkg, exprPath)
	}
	return out, nil
}
