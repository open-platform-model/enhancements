package main

import (
	"fmt"
	"os"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
)

type tc struct {
	name, prev, next string
	legal            bool // does D27 permit this change?
}

// The change classes D27 names, plus the two label cases OQ16 turns on.
var cases = []tc{
	{"add OPTIONAL field", `#X: {x: string}`, `#X: {x: string, y?: string}`, true},
	{"add DEFAULTED field", `#X: {x: string}`, `#X: {x: string, y: string | *"z"}`, true},
	{"add REQUIRED field", `#X: {x: string}`, `#X: {x: string, y: string}`, false},
	{"remove field", `#X: {x: string, y: string}`, `#X: {x: string}`, false},
	{"widen disjunction", `#X: {t: "a"|"b"}`, `#X: {t: "a"|"b"|"c"}`, true},
	{"narrow disjunction", `#X: {t: "a"|"b"|"c"}`, `#X: {t: "a"|"b"}`, false},
	{"change concrete value", `#X: {t: "a"}`, `#X: {t: "b"}`, false},
	{"change default", `#X: {t: string | *"a"}`, `#X: {t: string | *"b"}`, false},
	{"identical", `#X: {x: string, t: "a"|"b"}`, `#X: {x: string, t: "a"|"b"}`, true},
	{"nested field removed", `#X: {s: {a: string, b: string}}`, `#X: {s: {a: string}}`, false},
	{"nested option widened", `#X: {s: {t: "a"}}`, `#X: {s: {t: "a"|"b"}}`, true},
	{"label disjunction narrowed",
		`#X: {metadata: labels: "wt": "stateless"|"stateful"|"daemon"}`,
		`#X: {metadata: labels: "wt": "stateless"|"stateful"}`, false},
	{"label value changed",
		`#X: {metadata: labels: "wt": "stateful"}`,
		`#X: {metadata: labels: "wt": "daemon"}`, false},
	{"label key added (optional)",
		`#X: {metadata: labels: {}}`, `#X: {metadata: labels: "tier"?: string}`, true},
}

func main() {
	ctx := cuecontext.New()
	fail := 0

	fail += partOne(ctx)
	fail += partTwo(ctx)
	fail += partThree(ctx)

	fmt.Println()
	if fail > 0 {
		fmt.Printf("FAILED: %d assertion(s) did not hold\n", fail)
		os.Exit(1)
	}
	fmt.Println("All assertions held.")
}

// Part 1 — a single Subsume call, in either direction, does not implement D27.
func partOne(ctx *cue.Context) int {
	fmt.Println("PART 1 — can one cue.Value.Subsume call implement D27?")
	fmt.Printf("  %-28s %-8s %-18s %s\n", "change", "D27", "next.Subsume(prev)", "prev.Subsume(next)")
	fmt.Println("  " + dash(78))
	fwdOK, revOK := 0, 0
	for _, c := range cases {
		p, n := compile(ctx, c.prev), compile(ctx, c.next)
		fwd := n.Subsume(p, cue.Schema()) == nil
		rev := p.Subsume(n, cue.Schema()) == nil
		if fwd == c.legal {
			fwdOK++
		}
		if rev == c.legal {
			revOK++
		}
		fmt.Printf("  %-28s %-8s %-18s %s\n", c.name, legal(c.legal), mark(fwd, c.legal), mark(rev, c.legal))
	}
	fmt.Printf("\n  agreement: next.Subsume(prev) = %d/%d   prev.Subsume(next) = %d/%d\n",
		fwdOK, len(cases), revOK, len(cases))
	if fwdOK == len(cases) || revOK == len(cases) {
		fmt.Println("  UNEXPECTED: a single direction agreed with D27 everywhere.")
		return 1
	}
	fmt.Println("  → neither direction implements D27, as claimed.")
	return 0
}

// Part 2 — the three-rule field-wise walk does.
func partTwo(ctx *cue.Context) int {
	fmt.Println("\nPART 2 — does the field-wise walk implement D27?")
	fmt.Printf("  %-28s %-8s %-8s %s\n", "change", "D27", "gate", "first violation")
	fmt.Println("  " + dash(78))
	bad := 0
	for _, c := range cases {
		p, n := compile(ctx, c.prev), compile(ctx, c.next)
		vs := Check(p, n)
		accepted := len(vs) == 0
		ok := accepted == c.legal
		if !ok {
			bad++
		}
		d := ""
		if len(vs) > 0 {
			d = vs[0].String()
		}
		if len(d) > 40 {
			d = d[:40] + "…"
		}
		fmt.Printf("  %-28s %-8s %-8s %s %s\n", c.name, legal(c.legal), accept(accepted), tick(ok), d)
	}
	fmt.Printf("\n  agreement: %d/%d\n", len(cases)-bad, len(cases))
	return bad
}

// Part 3 — D34 level-awareness: the same illegal change is refused at beta and
// GA, and accepted at alpha.
func partThree(ctx *cue.Context) int {
	fmt.Println("\nPART 3 — is the gate level-aware (D34)?")
	breaking := tc{"remove field", `#X: {x: string, y: string}`, `#X: {x: string}`, false}
	p, n := compile(ctx, breaking.prev), compile(ctx, breaking.next)
	bad := 0
	for _, av := range []string{"v1alpha1", "v1alpha2", "v1beta1", "v1", "v2"} {
		lvl, _ := ParseLevel(av)
		vs := CheckAtLevel(av, p, n)
		refused := len(vs) > 0
		want := lvl.Enforced() // enforced levels must refuse the removal
		ok := refused == want
		if !ok {
			bad++
		}
		fmt.Printf("  apiVersion %-10s level=%-6s field removal → %-8s %s\n",
			av, lvl, accept(!refused), tick(ok))
	}
	if bad == 0 {
		fmt.Println("  → alpha waves the removal through; beta and GA refuse it.")
	}
	return bad
}

func compile(ctx *cue.Context, src string) cue.Value {
	return ctx.CompileString(src).LookupPath(cue.ParsePath("#X"))
}
func legal(b bool) string {
	if b {
		return "legal"
	}
	return "ILLEGAL"
}
func accept(b bool) string {
	if b {
		return "accept"
	}
	return "REFUSE"
}
func mark(got, want bool) string {
	return accept(got) + " " + tick(got == want)
}
func tick(ok bool) string {
	if ok {
		return "OK"
	}
	return "XX"
}
func dash(n int) string {
	s := ""
	for i := 0; i < n; i++ {
		s += "-"
	}
	return s
}
