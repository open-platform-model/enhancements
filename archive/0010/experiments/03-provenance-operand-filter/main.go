// Experiment 03 — provenance exclusion as an OPERAND filter.
//
// Enhancement 0010 D26 decided that provenance is removed from the match
// comparison BEFORE unification rather than forgiven after it, and left the
// mechanism open as OQ12. The user picked candidate (a): a Go-side filter that
// builds both operands minus the excluded fields, leaving `core` untouched.
//
// Experiment 02 measured candidate (c) — unify everything, discard conflicts
// whose path passes through `metadata` — and got the full predicted matrix.
// (a) has never been measured, and it is not obviously equivalent: `cue.Value`
// is immutable with no field-delete operation, so removing a field means a
// SYNTAX ROUND-TRIP (Syntax -> edit AST -> Build). Experiment 02's own finding
// 1 showed that changing what is fed to Unify can silently drop closedness:
// under spec-only unification case 1 PASSES, dropping a field the module set.
//
// The hypothesis under test:
//
//	An operand-side filter that strips provenance fields via a syntax
//	round-trip PRESERVES the closedness that makes a lagging provider fail,
//	and therefore reproduces experiment 02's matrix.
//
// If closedness does not survive the round-trip, candidate (a) is unavailable
// and OQ12 must take candidate (b) — a structural split in `core`.
//
// A second question rides along, because it decides the filter's field list:
// is `catalogVersion` alone sufficient, or must `description` go too? Case 8
// is a build whose only difference from the provider's, once catalogVersion is
// excluded, is a reworded description.
//
// Faithfulness notes:
//   - Fixtures copied verbatim 2026-07-29 from experiments/02, plus one new
//     build (catalog_v1_1_desc) and one new demand (demand_11_desc).
//   - The unify + Validate(cue.Concrete(false)) call is copied from
//     library/opm/compile/match.go:264, not approximated.
//   - Two module roots, one shared *cue.Context — the shape compile and
//     materialize actually have.
package main

import (
	"fmt"
	"os"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/ast"
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
	demand string // package dir under mod/
	supply string // package dir under prov/
	expect verdict
	why    string
	probe  string
}

// scope selects HOW the two operands are compared.
//
//	dropErrPaths — candidate (c): unify the whole value, then discard errors
//	               whose path passes through `metadata`. What experiment 02
//	               measured.
//	dropOperands — candidate (a): remove the named metadata fields from BOTH
//	               operands via a syntax round-trip, then unify. What OQ12
//	               chose, and what this experiment exists to measure.
type scope struct {
	name         string
	dropErrPaths bool
	dropOperands map[string]bool
}

var scopes = []scope{
	{name: "whole value (match.go today)"},
	{name: "(c) error-path filter", dropErrPaths: true},
	{name: "(a) operand: -catalogVersion", dropOperands: map[string]bool{"catalogVersion": true}},
	{name: "(a) operand: -catalogVersion -description", dropOperands: map[string]bool{"catalogVersion": true, "description": true}},
}

// recommended names the scope carrying the predictions — the field list under
// test. The other three are characterised, not predicted.
const recommended = "(a) operand: -catalogVersion -description"

var cases = []testCase{
	{
		name:   "1. lagging provider, module USES the added field",
		demand: "demand_11_uses", supply: "supply_10",
		expect: wantFail,
		why:    "THE decisive case for closedness: module on 1.1.0 sets `retention`; the 1.0.0 provider never declared it",
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
		why:    "1.2.0 narrowed `schedule`; the module's value is legal in 1.0.0 and not in 1.2.0",
	},
	{
		name:   "6. default drift — nothing added, nothing removed",
		demand: "demand_13_default", supply: "supply_10",
		expect: wantPass,
		why:    "1.3.0 flipped `mode`'s default; the probe shows what the render would get",
		probe:  "spec.backup.mode",
	},
	{
		name:   "7. pattern-constraint shape, module USES the added field",
		demand: "demand_11p_uses", supply: "supply_10p",
		expect: wantFail,
		why:    "case 1 against a named-schema spec body — the second shape catalog_opm ships",
	},
	{
		name:   "8. description drift (NEW) — provenance that is not catalogVersion",
		demand: "demand_11_desc", supply: "supply_10",
		expect: wantPass,
		why:    "contract surfaces agree completely; the builds differ in catalogVersion AND a reworded description",
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
			results := unifyIntersection(ctx, comp, tf, sc)
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
				if r.harnessErr != nil {
					fmt.Printf("  [%-38s] \033[31mHARNESS ERROR\033[0m %v\n", sc.name, r.harnessErr)
					failures++
					continue
				}
				fmt.Printf("  [%-38s] ", sc.name)
				if r.err == nil {
					fmt.Printf("\033[32munify PASSES\033[0m")
				} else {
					fmt.Printf("\033[33munify FAILS\033[0m")
				}
				if sc.dropOperands != nil {
					fmt.Printf("   \033[2m(stripped %d field(s); closed after round-trip: %t)\033[0m", r.stripped, r.stillClosed)
				}
				fmt.Println()
				if r.err != nil {
					for _, line := range strings.Split(strings.TrimSpace(r.err.Error()), "\n") {
						fmt.Printf("                                          %s\n", line)
					}
				}
				if tc.probe != "" && sc.name == recommended {
					printProbe(r.unified, tc.probe)
				}

				if sc.name != recommended {
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

	fmt.Printf("\n\033[1m%d of %d cases behaved as predicted under %q.\033[0m\n", len(cases)-failures, len(cases), recommended)
	if failures > 0 {
		os.Exit(1)
	}
}

type unifyResult struct {
	fqn         string
	haveVersion string
	reqVersion  string
	unified     cue.Value
	err         error
	harnessErr  error
	stripped    int  // fields actually removed across both operands
	stillClosed bool // does the round-tripped supply operand still reject an undeclared field?
}

// unifyIntersection is copied from library/opm/compile/match.go:247-273, with
// the plan-recording replaced by a returned slice and the scope's operand
// filter applied between lookup and Unify.
func unifyIntersection(ctx *cue.Context, comp, tf cue.Value, sc scope) []unifyResult {
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
			continue
		}
		rv := iter.Value()
		res := unifyResult{
			fqn:         fqn,
			haveVersion: str(cv.LookupPath(cue.ParsePath("metadata.catalogVersion"))),
			reqVersion:  str(rv.LookupPath(cue.ParsePath("metadata.catalogVersion"))),
		}

		if sc.dropOperands != nil {
			var nHave, nReq int
			cv, nHave, err = stripMetadata(ctx, cv, sc.dropOperands)
			if err != nil {
				res.harnessErr = fmt.Errorf("filtering component operand: %w", err)
				out = append(out, res)
				continue
			}
			rv, nReq, err = stripMetadata(ctx, rv, sc.dropOperands)
			if err != nil {
				res.harnessErr = fmt.Errorf("filtering transformer operand: %w", err)
				out = append(out, res)
				continue
			}
			res.stripped = nHave + nReq
			if res.stripped == 0 {
				res.harnessErr = fmt.Errorf("filter removed nothing — the measurement would be vacuous")
				out = append(out, res)
				continue
			}
			res.stillClosed = rejectsUndeclaredField(ctx, rv)
		}

		unified := cv.Unify(rv)
		vErr := unified.Validate(cue.Concrete(false))
		if sc.dropErrPaths {
			vErr = dropMetadataErrors(vErr)
		}
		res.unified = unified
		res.err = vErr
		out = append(out, res)
	}
	return out
}

// stripMetadata is candidate (a): render the value to syntax, delete the named
// fields from every `metadata` block, and rebuild. `cue.Value` is immutable and
// exposes no field removal, so the round-trip is the mechanism — which is
// precisely what makes closedness survival an open question.
//
// InlineImports is required: these values come from imported packages, and an
// unresolved cross-package reference would not rebuild in a bare context.
func stripMetadata(ctx *cue.Context, v cue.Value, names map[string]bool) (cue.Value, int, error) {
	node := v.Syntax(cue.All(), cue.InlineImports(true))
	if node == nil {
		return cue.Value{}, 0, fmt.Errorf("Syntax() returned nil")
	}

	removed := 0
	walkFields(topDecls(node), func(f *ast.Field) {
		name, _, err := ast.LabelName(f.Label)
		if err != nil || name != "metadata" {
			return
		}
		for _, sl := range structLits(f.Value) {
			kept := sl.Elts[:0]
			for _, d := range sl.Elts {
				if mf, ok := d.(*ast.Field); ok {
					if mn, _, err := ast.LabelName(mf.Label); err == nil && names[mn] {
						removed++
						continue
					}
				}
				kept = append(kept, d)
			}
			sl.Elts = kept
		}
	})

	var built cue.Value
	switch n := node.(type) {
	case *ast.File:
		built = ctx.BuildFile(n)
	case ast.Expr:
		built = ctx.BuildExpr(n)
	default:
		return cue.Value{}, removed, fmt.Errorf("Syntax() returned unsupported node %T", node)
	}
	if err := built.Err(); err != nil {
		return cue.Value{}, removed, fmt.Errorf("rebuilding filtered operand: %w", err)
	}
	return built, removed, nil
}

// rejectsUndeclaredField is the closedness probe. If the round-trip preserved
// closedness, unifying an undeclared field into the primitive's spec body is a
// "field not allowed" error. If it did not, the unification succeeds and the
// whole additive-promise enforcement (D27) is gone.
func rejectsUndeclaredField(ctx *cue.Context, v cue.Value) bool {
	probe := ctx.CompileString(`{spec: {[_]: zzz_closedness_probe: "x"}}`)
	if probe.Err() != nil {
		return false
	}
	return v.Unify(probe).Validate(cue.Concrete(false)) != nil
}

// --- syntax helpers -------------------------------------------------------

// structLits returns every struct literal reachable from an expression that
// behaves as a struct: a plain literal, a `close(...)` call, or the operands of
// a `&` conjunction. Syntax() emits all three shapes.
func structLits(n ast.Node) []*ast.StructLit {
	switch v := n.(type) {
	case *ast.StructLit:
		return []*ast.StructLit{v}
	case *ast.BinaryExpr:
		return append(structLits(v.X), structLits(v.Y)...)
	case *ast.CallExpr:
		var out []*ast.StructLit
		for _, a := range v.Args {
			out = append(out, structLits(a)...)
		}
		return out
	case *ast.ParenExpr:
		return structLits(v.X)
	}
	return nil
}

func topDecls(n ast.Node) []ast.Decl {
	switch v := n.(type) {
	case *ast.File:
		return v.Decls
	case ast.Expr:
		var out []ast.Decl
		for _, sl := range structLits(v) {
			out = append(out, sl.Elts...)
		}
		return out
	}
	return nil
}

// walkFields visits every field at any depth, so a `metadata` block is found
// wherever Syntax() chose to put it.
func walkFields(decls []ast.Decl, fn func(*ast.Field)) {
	for _, d := range decls {
		switch v := d.(type) {
		case *ast.Field:
			fn(v)
			for _, sl := range structLits(v.Value) {
				walkFields(sl.Elts, fn)
			}
		case *ast.EmbedDecl:
			for _, sl := range structLits(v.Expr) {
				walkFields(sl.Elts, fn)
			}
		}
	}
}

// --- candidate (c), kept for side-by-side comparison ----------------------

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
