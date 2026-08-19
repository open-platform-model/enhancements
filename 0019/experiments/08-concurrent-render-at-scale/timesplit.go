package main

// Where does a single-build render's time actually go, and is any of it
// splittable?
//
// Added after this experiment concluded, to answer a design question its own
// outcome raised: if renders parallelise across instances, could ONE large
// render be split by handing subsets of its (component, transformer) pairs to
// separate builds?
//
// The measurement holds the instance fixed and varies only how many components
// the generated render module asks for. Whatever cost stays flat as that subset
// shrinks is cost every split would re-pay; whatever falls is cost a split could
// divide. Each sample gets a fresh cue.Context and a fresh load, so nothing is
// warmed by the sample before it.

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/load"
)

// timeSplit generates subset render packages for one point and times them.
func timeSplit(t *tree, p point, fracs []int, reps int) error {
	full := p.wants()
	ids := make([]string, 0, len(full))
	for id := range full {
		ids = append(ids, id)
	}
	sort.Strings(ids)

	fmt.Printf("\nWHERE THE TIME GOES: one %d-component instance, varying only how many\n", p.components())
	fmt.Printf("components the render module ASKS FOR. The instance is identical in every row.\n\n")
	fmt.Printf("%10s %10s %9s %9s %9s %9s\n", "RENDERED", "OUTPUTS", "LOAD_ms", "BUILD_ms", "FORCE_ms", "TOTAL_ms")
	fmt.Println(rule(62))

	type row struct {
		comps, total int
		ms           float64
	}
	var rows []row

	for _, f := range fracs {
		if f > len(ids) {
			f = len(ids)
		}
		subset := map[string][]string{}
		outs := 0
		for _, id := range ids[:f] {
			subset[id] = full[id]
			outs += len(full[id])
		}
		dir := filepath.Join(t.Render, "r", fmt.Sprintf("split_%s_c%04d", p.id(), f))
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
		src := renderCUE(p, 0)
		// Swap the generated _wanted literal for the subset's.
		start := strings.Index(src, "_wanted: {")
		if start < 0 {
			return fmt.Errorf("no _wanted block in the generated render module")
		}
		end := strings.Index(src[start:], "\n}\n")
		if end < 0 {
			return fmt.Errorf("unterminated _wanted block")
		}
		src = src[:start] + "_wanted: " + wantedLiteral(subset) + src[start+end+3:]
		if err := os.WriteFile(filepath.Join(dir, "render.cue"), []byte(src), 0o644); err != nil {
			return err
		}

		var best time.Duration
		var bl, bb, be time.Duration
		for i := 0; i < reps; i++ {
			l, b, e, err := buildAndForce(dir, "rendered")
			if err != nil {
				return fmt.Errorf("%d components: %w", f, err)
			}
			if i == 0 || l+b+e < best {
				best, bl, bb, be = l+b+e, l, b, e
			}
		}
		fmt.Printf("%10d %10d %9.1f %9.1f %9.1f %9.1f\n", f, outs, ms(bl), ms(bb), ms(be), ms(best))
		rows = append(rows, row{f, outs, ms(best)})
	}

	if len(rows) < 2 {
		return nil
	}
	lo, hi := rows[0], rows[len(rows)-1]
	perComp := (hi.ms - lo.ms) / float64(hi.comps-lo.comps)
	floor := lo.ms - perComp*float64(lo.comps)
	fmt.Printf("\n  fixed floor (paid whatever the subset): %.0f ms\n", floor)
	fmt.Printf("  per component actually rendered:        %.2f ms\n", perComp)
	fmt.Printf("  so %.0f%% of this render is work every split would re-pay\n\n", 100*floor/hi.ms)
	fmt.Println("  Ceiling on splitting one module's pairs across K parallel builds:")
	for _, k := range []int{2, 4, 8, 16} {
		each := floor + perComp*float64(hi.comps)/float64(k)
		fmt.Printf("    K=%-3d each build %7.0f ms, wall %7.0f ms -> %.2fx  (and K times the working set)\n",
			k, each, each, hi.ms/each)
	}
	fmt.Printf("    K=inf                      %7.0f ms -> %.2fx  (the asymptote)\n", floor, hi.ms/floor)
	return nil
}

func wantedLiteral(w map[string][]string) string {
	keys := make([]string, 0, len(w))
	for k := range w {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var b strings.Builder
	b.WriteString("{\n")
	for _, k := range keys {
		q := make([]string, len(w[k]))
		for i, n := range w[k] {
			q[i] = fmt.Sprintf("%q", n)
		}
		fmt.Fprintf(&b, "\t%q: [%s]\n", k, strings.Join(q, ", "))
	}
	b.WriteString("}\n")
	return b.String()
}

// buildAndForce splits one render into load, build, and forcing one expression
// concrete. The third number is the interesting one: if CUE deferred the
// transforms, it would be large.
func buildAndForce(dir, expr string) (l, b, e time.Duration, err error) {
	cctx := cuecontext.New()

	t0 := time.Now()
	insts := load.Instances([]string{"."}, &load.Config{Dir: dir})
	l = time.Since(t0)
	if len(insts) == 0 {
		return l, 0, 0, fmt.Errorf("no instances in %s", dir)
	}
	if insts[0].Err != nil {
		return l, 0, 0, fmt.Errorf("load: %w", insts[0].Err)
	}

	t1 := time.Now()
	v := cctx.BuildInstance(insts[0])
	b = time.Since(t1)
	if v.Err() != nil {
		return l, b, 0, fmt.Errorf("build: %w", v.Err())
	}

	t2 := time.Now()
	err = v.LookupPath(cue.ParsePath(expr)).Validate(cue.Concrete(true))
	e = time.Since(t2)
	return l, b, e, err
}
