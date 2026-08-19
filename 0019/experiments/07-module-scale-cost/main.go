// Experiment 07 harness: what does module SIZE cost the single-build render?
//
// Experiment 04 measured a per-render single build at 2.1x today's path on a
// two-component module producing five outputs, and said in its own outcome that
// the number should not be quoted as general until a large module was measured.
// This harness measures it across a size sweep, on two fixtures that grow in
// different directions, each authored two ways.
//
//	fleet     breadth: K servers plus one router that folds over all of them
//	complex   depth:   K services, each with a deep guarded configuration body
//	bp        every workload attached as a Blueprint
//	raw       the same workloads attached as Resources and Traits directly
//
// Two arms per point:
//
//	single    the collapse: one CUE build per render, nothing stripped
//	base      today's path: platform held, components finalized, filled in Go
//
// Everything timed goes through the cuelang.org/go API. Setup (materializing
// the tree, generating the render module's cue.mod/local-module.cue) shells out
// to the `cue` CLI and is deliberately outside every measurement.
package main

import (
	"flag"
	"fmt"
	"os"
	"runtime"
	"runtime/pprof"
	"sort"
	"strconv"
	"strings"
	"time"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
)

// defaultRegistry is the workspace's canonical developer mapping. Used only
// when CUE_REGISTRY is absent, so a run always states which mapping it resolved
// against rather than failing obscurely.
const defaultRegistry = "opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"

// phases is the per-render breakdown. The split matters more than the total: a
// cost that is all Load is resolution and parse, which grows with the generated
// render module; a cost that is all Build is the catalog and the component
// payload being evaluated, which is what this experiment is about.
type phases struct {
	Load   time.Duration
	Build  time.Duration
	Eval   time.Duration
	Export time.Duration
}

func (p phases) total() time.Duration { return p.Load + p.Build + p.Eval + p.Export }

type sample struct {
	Index   int
	P       phases
	Outputs int
	Digest  digests
	Err     error
}

type pointResult struct {
	P              point
	Arm            string
	Samples        []sample
	OneTime        time.Duration
	AllocPerRender uint64
	Distinct       bool // consecutive renders produced different bytes
}

func main() {
	fixtureSel := flag.String("fixture", "all", "fleet, complex, or all")
	styleSel := flag.String("style", "all", "bp, raw, or all")
	fleetSizes := flag.String("fleet-sizes", "1,2,4,8,16,32,64,128", "component sweep for the fleet fixture (servers; +1 router)")
	complexSizes := flag.String("complex-sizes", "1,2,4,8,16,32", "component sweep for the complex fixture (services)")
	armSel := flag.String("arm", "all", "single, base, or all")
	n := flag.Int("n", 8, "renders per point")
	maxSeconds := flag.Float64("max-seconds", 90, "per-point wall-clock cap; a point stops early and reports how many renders it got")
	ctxPolicy := flag.String("ctx", "fresh", "single-build context policy: fresh (a cue.Context per render, experiment 06's S2) or shared (one for the point, experiment 04's arm C)")
	fixturesDir := flag.String("fixtures", "fixtures", "fixture tree to materialize from")
	workDir := flag.String("work", "_out/run", "scratch tree")
	reuse := flag.Bool("reuse", false, "reuse an existing scratch tree instead of rebuilding it")
	keep := flag.Bool("keep", false, "keep the scratch tree for inspection")
	setupOnly := flag.Bool("setup-only", false, "materialize the tree and exit")
	cpuProfile := flag.String("profile", "", "write a CPU profile to this path")
	dump := flag.String("dump", "", "write each point's first rendered output set to this directory (diagnostics)")
	flag.Parse()

	if os.Getenv("CUE_REGISTRY") == "" {
		os.Setenv("CUE_REGISTRY", defaultRegistry)
	}

	if *dump != "" {
		if err := os.MkdirAll(*dump, 0o755); err != nil {
			fatal(err)
		}
		dumpParts = func(tag string, parts map[string][]byte) {
			for k, v := range parts {
				name := strings.NewReplacer("/", "_", " ", "", ":", "-").Replace(tag + "__" + k)
				_ = os.WriteFile(*dump+"/"+name+".json", v, 0o644)
			}
		}
	}

	points := buildPoints(*fixtureSel, *styleSel, *fleetSizes, *complexSizes)
	if len(points) == 0 {
		fatal(fmt.Errorf("no points selected"))
	}

	fmt.Printf("GOMAXPROCS=%d go=%s n=%d ctx=%s max-seconds=%.0f\n",
		runtime.GOMAXPROCS(0), runtime.Version(), *n, *ctxPolicy, *maxSeconds)
	fmt.Printf("CUE_REGISTRY=%s\n", os.Getenv("CUE_REGISTRY"))
	fmt.Printf("points: %d\n", len(points))

	if *cpuProfile != "" {
		f, err := os.Create(*cpuProfile)
		if err != nil {
			fatal(err)
		}
		defer f.Close()
		if err := pprof.StartCPUProfile(f); err != nil {
			fatal(err)
		}
		defer pprof.StopCPUProfile()
	}

	setupStart := time.Now()
	t, reused, err := materialize(*fixturesDir, *workDir, points, *n, *reuse)
	if err != nil {
		fatal(err)
	}
	if reused {
		fmt.Printf("reusing scratch tree at %s\n", t.Root)
	} else {
		fmt.Printf("materialized %d points x %d renders under %s in %.1f s\n",
			len(points), *n, t.Root, time.Since(setupStart).Seconds())
	}
	if *setupOnly {
		return
	}
	if !*keep {
		defer os.RemoveAll(t.Root)
	}

	// Priming is a render that is thrown away. Without it the first timed
	// sample would carry the whole dependency fetch and the medians would be a
	// mixture of two populations. Experiment 04 measured that cost at 1.76 s,
	// once per cold module cache.
	fmt.Print("priming the module cache ... ")
	primeStart := time.Now()
	if _, _, _, err := renderOnce(cuecontext.New(), t.renderDir(points[0], 0)); err != nil {
		fatal(fmt.Errorf("prime: %w", err))
	}
	fmt.Printf("%.1f ms\n\n", ms(time.Since(primeStart)))

	arms := selected(*armSel, "single", "base")
	var results []pointResult

	header()
	for _, p := range points {
		for _, arm := range []string{"single", "base"} {
			if !arms[arm] {
				continue
			}
			r := runPoint(t, p, arm, *n, *ctxPolicy, time.Duration(*maxSeconds*float64(time.Second)))
			results = append(results, r)
			row(r)
		}
	}

	report(results)
}

// ---------------------------------------------------------------------------
// Running one point
// ---------------------------------------------------------------------------

func runPoint(t *tree, p point, arm string, n int, ctxPolicy string, cap time.Duration) pointResult {
	r := pointResult{P: p, Arm: arm}

	var shared *cue.Context
	if arm == "single" && ctxPolicy == "shared" {
		shared = cuecontext.New()
	}

	var hold *platformHold
	var pairs []pair
	if arm == "base" {
		cctx := cuecontext.New()
		shared = cctx
		h, err := holdPlatform(cctx, t.Render)
		if err != nil {
			r.Samples = append(r.Samples, sample{Err: err})
			r.Distinct = true
			return r
		}
		ps, err := resolvePairs(h.transformers, p.wants())
		if err != nil {
			r.Samples = append(r.Samples, sample{Err: err})
			r.Distinct = true
			return r
		}
		hold, pairs = h, ps
		r.OneTime = h.build
	}

	var before, after runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&before)

	start := time.Now()
	for i := 0; i < n; i++ {
		var (
			ph  phases
			dig digests
			out int
			err error
		)
		if arm == "single" {
			cctx := shared
			if cctx == nil {
				cctx = cuecontext.New()
			}
			ph, dig, out, err = renderOnce(cctx, t.renderDir(p, i))
		} else {
			ph, dig, out, err = baselineRender(shared, t.instDir(p, i), hold, pairs)
		}
		if err == nil && out != p.outputs() {
			err = fmt.Errorf("rendered %d outputs, expected %d", out, p.outputs())
		}
		r.Samples = append(r.Samples, sample{Index: i, P: ph, Outputs: out, Digest: dig, Err: err})
		if time.Since(start) > cap {
			break
		}
	}

	runtime.GC()
	runtime.ReadMemStats(&after)
	if k := len(r.Samples); k > 0 && after.TotalAlloc > before.TotalAlloc {
		r.AllocPerRender = (after.TotalAlloc - before.TotalAlloc) / uint64(k)
	}

	// Distinctness: consecutive renders differ only in metadata.name, which
	// reaches every rendered resource. Equal digests would mean a render was
	// answered out of another render's evaluation state, which would make every
	// number in the point a cache reading.
	ok := okSamples(r.Samples)
	r.Distinct = len(ok) < 2
	for i := 1; i < len(ok); i++ {
		if ok[i].Digest.Strict != ok[i-1].Digest.Strict {
			r.Distinct = true
			break
		}
	}
	return r
}

// ---------------------------------------------------------------------------
// Point selection
// ---------------------------------------------------------------------------

func buildPoints(fixtureSel, styleSel, fleetSizes, complexSizes string) []point {
	fixtures := selected(fixtureSel, "fleet", "complex")
	styles := selected(styleSel, "bp", "raw")

	var out []point
	for _, f := range []string{"fleet", "complex"} {
		if !fixtures[f] {
			continue
		}
		sizes := fleetSizes
		if f == "complex" {
			sizes = complexSizes
		}
		for _, k := range ints(sizes) {
			for _, s := range []string{"bp", "raw"} {
				if !styles[s] {
					continue
				}
				out = append(out, point{Fixture: f, Style: s, K: k})
			}
		}
	}
	return out
}

func selected(s string, all ...string) map[string]bool {
	out := map[string]bool{}
	if s == "all" || s == "" {
		for _, a := range all {
			out[a] = true
		}
		return out
	}
	for _, part := range strings.Split(s, ",") {
		out[strings.TrimSpace(part)] = true
	}
	return out
}

func ints(s string) []int {
	var out []int
	for _, part := range strings.Split(s, ",") {
		v, err := strconv.Atoi(strings.TrimSpace(part))
		if err == nil && v > 0 {
			out = append(out, v)
		}
	}
	sort.Ints(out)
	return out
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

func header() {
	fmt.Printf("%-9s %-4s %5s %5s %5s %4s %9s %9s %9s %9s %9s %9s %5s\n",
		"FIXTURE", "STYL", "K", "COMPS", "OUTS", "N", "LOAD", "BUILD", "EVAL", "EXPORT", "TOTAL", "TOTAL_p90", "ERRS")
	fmt.Println(rule(118))
}

func row(r pointResult) {
	ok := okSamples(r.Samples)
	label := r.P.Fixture + "/" + r.Arm
	if len(ok) == 0 {
		fmt.Printf("%-9s %-4s %5d %5d %5d %4d   FAILED: %v\n",
			label, r.P.Style, r.P.K, r.P.components(), r.P.outputs(), len(r.Samples), firstErr(r.Samples))
		return
	}
	fmt.Printf("%-9s %-4s %5d %5d %5d %4d %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f %5d",
		label, r.P.Style, r.P.K, r.P.components(), r.P.outputs(), len(ok),
		ms(pct(ok, func(s sample) time.Duration { return s.P.Load }, 50)),
		ms(pct(ok, func(s sample) time.Duration { return s.P.Build }, 50)),
		ms(pct(ok, func(s sample) time.Duration { return s.P.Eval }, 50)),
		ms(pct(ok, func(s sample) time.Duration { return s.P.Export }, 50)),
		ms(pct(ok, func(s sample) time.Duration { return s.P.total() }, 50)),
		ms(pct(ok, func(s sample) time.Duration { return s.P.total() }, 90)),
		len(r.Samples)-len(ok),
	)
	if !r.Distinct {
		fmt.Print("  !! renders NOT distinct")
	}
	fmt.Println()
}

func report(results []pointResult) {
	byKey := map[string]*pointResult{}
	for i := range results {
		byKey[key(results[i].P, results[i].Arm)] = &results[i]
	}

	// ---- the ratio, at every size --------------------------------------
	fmt.Println()
	fmt.Println("SINGLE BUILD vs BASELINE, per point")
	fmt.Println("  (experiment 04 measured 2.1x on a 2-component module producing 5 outputs)")
	fmt.Println()
	fmt.Printf("  %-9s %-4s %5s %6s %10s %10s %7s %11s %11s\n",
		"FIXTURE", "STYL", "K", "OUTS", "SINGLE_ms", "BASE_ms", "RATIO", "SINGLE/comp", "SINGLE/out")
	fmt.Println("  " + rule(88))
	for _, r := range results {
		if r.Arm != "single" {
			continue
		}
		s := medianOf(&r)
		b := medianOf(byKey[key(r.P, "base")])
		if s == 0 {
			continue
		}
		ratio := 0.0
		if b > 0 {
			ratio = float64(s) / float64(b)
		}
		fmt.Printf("  %-9s %-4s %5d %6d %10.1f %10.1f %6.2fx %11.2f %11.2f\n",
			r.P.Fixture, r.P.Style, r.P.K, r.P.outputs(), ms(s), ms(b), ratio,
			ms(s)/float64(r.P.components()), ms(s)/float64(r.P.outputs()))
	}

	// ---- does the ratio itself grow with size? -------------------------
	fmt.Println()
	fmt.Println("VERDICT 1 -- does the single-build penalty grow with module size?")
	fmt.Println("  README refutes the bounded-ratio claim if the ratio at the largest size")
	fmt.Println("  exceeds twice the ratio at the smallest.")
	for _, f := range []string{"fleet", "complex"} {
		for _, st := range []string{"bp", "raw"} {
			var ks []int
			for _, r := range results {
				if r.Arm == "single" && r.P.Fixture == f && r.P.Style == st {
					ks = append(ks, r.P.K)
				}
			}
			if len(ks) < 2 {
				continue
			}
			sort.Ints(ks)
			lo := ratioAt(byKey, point{f, st, ks[0]})
			hi := ratioAt(byKey, point{f, st, ks[len(ks)-1]})
			if lo == 0 || hi == 0 {
				continue
			}
			verdict := "HELD"
			if hi > 2*lo {
				verdict = "REFUTED"
			}
			fmt.Printf("  %-9s %-4s ratio %.2fx at k=%d -> %.2fx at k=%d  (%.2fx growth) -> %s\n",
				f, st, lo, ks[0], hi, ks[len(ks)-1], hi/lo, verdict)
		}
	}

	// ---- linearity in component count ----------------------------------
	fmt.Println()
	fmt.Println("VERDICT 2 -- is per-render cost linear in component count?")
	fmt.Println("  Reported as ms per component at each end of the sweep. Rising = super-linear.")
	for _, f := range []string{"fleet", "complex"} {
		for _, st := range []string{"bp", "raw"} {
			for _, arm := range []string{"single", "base"} {
				var ks []int
				for _, r := range results {
					if r.Arm == arm && r.P.Fixture == f && r.P.Style == st && len(okSamples(r.Samples)) > 0 {
						ks = append(ks, r.P.K)
					}
				}
				if len(ks) < 2 {
					continue
				}
				sort.Ints(ks)
				loP := point{f, st, ks[0]}
				hiP := point{f, st, ks[len(ks)-1]}
				lo := ms(medianOf(byKey[key(loP, arm)])) / float64(loP.components())
				hi := ms(medianOf(byKey[key(hiP, arm)])) / float64(hiP.components())
				if lo == 0 {
					continue
				}
				shape := "sub-linear"
				switch {
				case hi > 1.25*lo:
					shape = "SUPER-linear"
				case hi > 0.9*lo:
					shape = "linear"
				}
				fmt.Printf("  %-9s %-4s %-6s %7.2f ms/comp at k=%d -> %7.2f ms/comp at k=%d  (%s)\n",
					f, st, arm, lo, ks[0], hi, ks[len(ks)-1], shape)
			}
		}
	}

	// ---- the authoring-style gap ---------------------------------------
	fmt.Println()
	fmt.Println("VERDICT 3 -- what does blueprint authoring cost, and where?")
	fmt.Println("  README refutes the payload claim if bp and raw are within 10% everywhere,")
	fmt.Println("  or if the gap in the single build is not larger than the gap in the baseline.")
	fmt.Println()
	fmt.Printf("  %-9s %5s %12s %12s %12s %12s\n", "FIXTURE", "K", "SINGLE_gap", "BASE_gap", "SINGLE_bp/raw", "BASE_bp/raw")
	fmt.Println("  " + rule(70))
	widerCount, comparable := 0, 0
	for _, r := range results {
		if r.Arm != "single" || r.P.Style != "bp" {
			continue
		}
		bpS := medianOf(byKey[key(r.P, "single")])
		rawP := point{r.P.Fixture, "raw", r.P.K}
		rawS := medianOf(byKey[key(rawP, "single")])
		bpB := medianOf(byKey[key(r.P, "base")])
		rawB := medianOf(byKey[key(rawP, "base")])
		if bpS == 0 || rawS == 0 || bpB == 0 || rawB == 0 {
			continue
		}
		gapS := (float64(bpS)/float64(rawS) - 1) * 100
		gapB := (float64(bpB)/float64(rawB) - 1) * 100
		comparable++
		if gapS > gapB {
			widerCount++
		}
		fmt.Printf("  %-9s %5d %11.1f%% %11.1f%% %12.2fx %12.2fx\n",
			r.P.Fixture, r.P.K, gapS, gapB,
			float64(bpS)/float64(rawS), float64(bpB)/float64(rawB))
	}
	if comparable > 0 {
		fmt.Printf("\n  the single-build gap is the wider one in %d of %d sizes\n", widerCount, comparable)
	}

	// ---- guards --------------------------------------------------------
	fmt.Println()
	fmt.Println("GUARDS")
	sameCount, diffCount := 0, 0
	for _, r := range results {
		if r.P.Style != "bp" {
			continue
		}
		bp := firstDigest(byKey[key(r.P, r.Arm)])
		raw := firstDigest(byKey[key(point{r.P.Fixture, "raw", r.P.K}, r.Arm)])
		if bp.Strict == "" || raw.Strict == "" {
			continue
		}
		if bp.Strict == raw.Strict {
			sameCount++
		} else {
			diffCount++
			fmt.Printf("  !! %s k=%d arm=%s: bp and raw rendered DIFFERENT bytes (%s vs %s, list-order-insensitive %s vs %s)\n",
				r.P.Fixture, r.P.K, r.Arm, bp.Strict, raw.Strict, bp.Loose, raw.Loose)
		}
	}
	fmt.Printf("  bp/raw output identity: %d identical, %d divergent\n", sameCount, diffCount)

	agree, orderOnly, disagree := 0, 0, 0
	for _, r := range results {
		if r.Arm != "single" {
			continue
		}
		s := firstDigest(byKey[key(r.P, "single")])
		b := firstDigest(byKey[key(r.P, "base")])
		if s.Strict == "" || b.Strict == "" {
			continue
		}
		switch {
		case s.Strict == b.Strict:
			agree++
		case s.Loose == b.Loose:
			orderOnly++
		default:
			disagree++
		}
	}
	fmt.Printf("  single vs baseline: %d byte-identical, %d identical modulo LIST ORDER, %d genuinely different\n", agree, orderOnly, disagree)
	fmt.Println("    (reported, not asserted: the baseline finalizes the component, which this enhancement exists to remove)")

	nd := 0
	for _, r := range results {
		if !r.Distinct {
			nd++
		}
	}
	fmt.Printf("  render distinctness: %d points where consecutive renders produced identical bytes\n", nd)

	errs := 0
	for _, r := range results {
		errs += len(r.Samples) - len(okSamples(r.Samples))
	}
	fmt.Printf("  failed renders: %d\n", errs)
	for _, r := range results {
		if err := firstErr(r.Samples); err != nil {
			fmt.Printf("  first error (%s/%s k=%d %s): %v\n", r.P.Fixture, r.P.Style, r.P.K, r.Arm, err)
			break
		}
	}

	// ---- allocation ----------------------------------------------------
	fmt.Println()
	fmt.Println("ALLOCATION per render (churn, not retention -- experiment 06 owns retention)")
	fmt.Printf("  %-9s %-4s %5s %12s %12s\n", "FIXTURE", "STYL", "K", "SINGLE", "BASE")
	fmt.Println("  " + rule(48))
	for _, r := range results {
		if r.Arm != "single" {
			continue
		}
		b := byKey[key(r.P, "base")]
		bAlloc := uint64(0)
		if b != nil {
			bAlloc = b.AllocPerRender
		}
		fmt.Printf("  %-9s %-4s %5d %12s %12s\n",
			r.P.Fixture, r.P.Style, r.P.K, human(r.AllocPerRender), human(bAlloc))
	}
}

func key(p point, arm string) string { return p.id() + "/" + arm }

func ratioAt(byKey map[string]*pointResult, p point) float64 {
	s := medianOf(byKey[key(p, "single")])
	b := medianOf(byKey[key(p, "base")])
	if s == 0 || b == 0 {
		return 0
	}
	return float64(s) / float64(b)
}

func medianOf(r *pointResult) time.Duration {
	if r == nil {
		return 0
	}
	ok := okSamples(r.Samples)
	if len(ok) == 0 {
		return 0
	}
	return pct(ok, func(s sample) time.Duration { return s.P.total() }, 50)
}

func firstDigest(r *pointResult) digests {
	if r == nil {
		return digests{}
	}
	for _, s := range r.Samples {
		if s.Err == nil {
			return s.Digest
		}
	}
	return digests{}
}

func okSamples(ss []sample) []sample {
	var out []sample
	for _, s := range ss {
		if s.Err == nil {
			out = append(out, s)
		}
	}
	return out
}

func firstErr(ss []sample) error {
	for _, s := range ss {
		if s.Err != nil {
			return s.Err
		}
	}
	return nil
}

func pct(ss []sample, f func(sample) time.Duration, p int) time.Duration {
	if len(ss) == 0 {
		return 0
	}
	vals := make([]time.Duration, len(ss))
	for i, s := range ss {
		vals[i] = f(s)
	}
	sort.Slice(vals, func(i, j int) bool { return vals[i] < vals[j] })
	return vals[(p*(len(vals)-1))/100]
}

func ms(d time.Duration) float64 { return float64(d) / float64(time.Millisecond) }

func human(b uint64) string {
	switch {
	case b > 1<<30:
		return fmt.Sprintf("%.1fG", float64(b)/(1<<30))
	case b > 1<<20:
		return fmt.Sprintf("%.1fM", float64(b)/(1<<20))
	case b > 1<<10:
		return fmt.Sprintf("%.1fK", float64(b)/(1<<10))
	default:
		return fmt.Sprintf("%dB", b)
	}
}

func rule(n int) string { return strings.Repeat("-", n) }

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "error: %v\n", err)
	os.Exit(1)
}
