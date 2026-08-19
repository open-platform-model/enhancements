// Experiment 04 harness: what does a per-render single CUE build cost?
//
// Four arms render the same N instances against one identical platform. The
// arms differ only in what is reused between renders, so the spread between
// them is the answer to OQ8:
//
//	A-cold   fresh module cache, fresh cue.Context   what a cold pod pays once
//	B-warm   warm module cache, fresh cue.Context    parse and eval without I/O
//	C-shared warm module cache, ONE cue.Context      the arm the hypothesis rests on
//	D-base   platform built once, instance filled    today's path, as the yardstick
//
// Everything timed goes through the cuelang.org/go API. Setup (materializing
// the fixture tree, generating each render module's cue.mod/local-module.cue)
// shells out to the `cue` CLI and is deliberately outside every measurement.
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"runtime/pprof"
	"sort"
	"time"
)

// defaultRegistry is the workspace's canonical developer mapping. Used only
// when CUE_REGISTRY is absent from the environment, so a run always states
// which mapping it resolved against rather than failing obscurely.
const defaultRegistry = "opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"

// phases is the per-render breakdown. The split matters more than the total:
// a cost that is all Load is an I/O and resolution problem with known fixes,
// and a cost that is all Eval is the catalog being re-evaluated per render,
// which is the thing OQ8 is actually about.
type phases struct {
	Load   time.Duration // load.Instances: resolution, fetch, parse
	Build  time.Duration // ctx.BuildInstance
	Eval   time.Duration // forcing `rendered` concrete
	Export time.Duration // marshalling the rendered value
}

func (p phases) total() time.Duration { return p.Load + p.Build + p.Eval + p.Export }

// sample is one render.
type sample struct {
	Index   int
	P       phases
	Outputs int
	Err     error
}

// armResult is everything one arm produced.
type armResult struct {
	Name    string
	Note    string
	OneTime time.Duration // work done once before the timed renders (arm D's platform build)
	Samples []sample
	// Memory is read once after the arm completes, with a GC forced first, so
	// HeapInuse reflects what the arm RETAINED rather than what it churned.
	AllocPerRender uint64
	HeapInuse      uint64
}

func main() {
	n := flag.Int("n", 50, "instances rendered per arm (arms B, C, D)")
	coldN := flag.Int("cold", 3, "samples for arm A; each one refetches the whole dependency set from the registry")
	armSel := flag.String("arm", "all", "which arms to run: all, or a comma-separated subset of A,B,C,D")
	fixturesDir := flag.String("fixtures", "fixtures", "fixture tree to materialize from")
	workDir := flag.String("work", "_out/run", "scratch tree; recreated on every run")
	keep := flag.Bool("keep", false, "keep the scratch tree for inspection")
	cpuProfile := flag.String("profile", "", "write a CPU profile to this path")
	flag.Parse()

	if os.Getenv("CUE_REGISTRY") == "" {
		os.Setenv("CUE_REGISTRY", defaultRegistry)
	}
	fmt.Printf("CUE_REGISTRY=%s\n", os.Getenv("CUE_REGISTRY"))

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

	// Setup. Untimed by construction: every arm reads the same tree, and the
	// only thing that varies between the N instance modules is metadata.name.
	fmt.Printf("materializing %d instances under %s ...\n", *n, *workDir)
	setupStart := time.Now()
	t, err := materialize(*fixturesDir, *workDir, *n)
	if err != nil {
		fatal(err)
	}
	setup := time.Since(setupStart)
	if !*keep {
		defer os.RemoveAll(t.Root)
	}

	want := selected(*armSel)
	var results []armResult

	if want["A"] {
		fmt.Printf("arm A-cold  (%d samples, each refetching the dependency set) ...\n", *coldN)
		results = append(results, armCold(t, *coldN))
	}

	// Arms B, C and D all read a warm cache. Priming is a render that is
	// thrown away: without it the first timed sample of arm B would carry the
	// whole fetch cost and the median would be a mixture of two populations.
	if want["B"] || want["C"] || want["D"] {
		fmt.Println("priming the shared module cache ...")
		if err := prime(t); err != nil {
			fatal(err)
		}
	}
	if want["B"] {
		fmt.Printf("arm B-warm  (%d renders, fresh cue.Context each) ...\n", *n)
		results = append(results, armWarm(t, *n))
	}
	if want["C"] {
		fmt.Printf("arm C-shared (%d renders, one cue.Context) ...\n", *n)
		results = append(results, armShared(t, *n))
	}
	if want["D"] {
		fmt.Printf("arm D-base  (%d renders against one pre-built platform) ...\n", *n)
		results = append(results, armBaseline(t, *n))
	}

	report(results)

	// Stated rather than folded into an arm. Generating the render module is
	// real per-render work that a kernel would do (OQ6), but this number is
	// harness-shaped: it copies a tree and spawns `cue mod edit` per render,
	// where a kernel would write two files in-process. It is here so the
	// omission is visible, not so it can be added to the totals.
	fmt.Println()
	fmt.Printf("SETUP (excluded from every arm): %d render modules materialized in %.1f ms, %.1f ms each.\n",
		*n, ms(setup), ms(setup)/float64(*n))
	fmt.Println("Harness-shaped: a tree copy plus one `cue mod edit` process per render. Not a kernel cost.")
}

func selected(s string) map[string]bool {
	if s == "all" || s == "" {
		return map[string]bool{"A": true, "B": true, "C": true, "D": true}
	}
	out := map[string]bool{}
	for _, part := range splitComma(s) {
		out[part] = true
	}
	return out
}

func splitComma(s string) []string {
	var out []string
	cur := ""
	for _, r := range s {
		if r == ',' || r == ' ' {
			if cur != "" {
				out = append(out, cur)
				cur = ""
			}
			continue
		}
		cur += string(r)
	}
	if cur != "" {
		out = append(out, cur)
	}
	return out
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

func report(results []armResult) {
	fmt.Println()
	fmt.Println("PER-RENDER COST (milliseconds)")
	fmt.Println()
	fmt.Printf("%-10s %5s %9s %9s %9s %9s %9s %9s %7s %9s\n",
		"ARM", "N", "LOAD", "BUILD", "EVAL", "EXPORT", "TOTAL", "TOTAL_p90", "ERRS", "ALLOC/rnd")
	fmt.Println(rule(100))

	for _, r := range results {
		ok := okSamples(r.Samples)
		if len(ok) == 0 {
			fmt.Printf("%-10s %5d   all samples failed: %v\n", r.Name, len(r.Samples), firstErr(r.Samples))
			continue
		}
		fmt.Printf("%-10s %5d %9.1f %9.1f %9.1f %9.1f %9.1f %9.1f %7d %9s\n",
			r.Name, len(ok),
			ms(pct(ok, func(s sample) time.Duration { return s.P.Load }, 50)),
			ms(pct(ok, func(s sample) time.Duration { return s.P.Build }, 50)),
			ms(pct(ok, func(s sample) time.Duration { return s.P.Eval }, 50)),
			ms(pct(ok, func(s sample) time.Duration { return s.P.Export }, 50)),
			ms(pct(ok, func(s sample) time.Duration { return s.P.total() }, 50)),
			ms(pct(ok, func(s sample) time.Duration { return s.P.total() }, 90)),
			len(r.Samples)-len(ok),
			human(r.AllocPerRender),
		)
	}

	fmt.Println()
	for _, r := range results {
		if r.OneTime > 0 {
			fmt.Printf("%-10s one-time setup outside the per-render loop: %.1f ms\n", r.Name, ms(r.OneTime))
		}
		if r.Note != "" {
			fmt.Printf("%-10s %s\n", r.Name, r.Note)
		}
		if err := firstErr(r.Samples); err != nil {
			fmt.Printf("%-10s first error: %v\n", r.Name, err)
		}
	}

	// The flat-versus-linear question. If a shared cue.Context amortises the
	// catalog, the last renders cost what the first ones cost; if the context
	// accumulates state, the tail drifts upward. This is the single reading
	// OQ8 turns on, so it is printed separately rather than buried in a p90.
	fmt.Println()
	fmt.Println("DRIFT (median of first fifth vs last fifth, per arm)")
	for _, r := range results {
		ok := okSamples(r.Samples)
		if len(ok) < 10 {
			continue
		}
		k := len(ok) / 5
		head := median(ok[:k], func(s sample) time.Duration { return s.P.total() })
		tail := median(ok[len(ok)-k:], func(s sample) time.Duration { return s.P.total() })
		delta := 0.0
		if head > 0 {
			delta = (float64(tail)/float64(head) - 1) * 100
		}
		fmt.Printf("  %-10s first %.1f ms -> last %.1f ms  (%+.1f%%)  heap retained %s\n",
			r.Name, ms(head), ms(tail), delta, human(r.HeapInuse))
	}

	// The comparison the hypothesis is stated against.
	c := findArm(results, "C-shared")
	d := findArm(results, "D-base")
	if c != nil && d != nil {
		co, do := okSamples(c.Samples), okSamples(d.Samples)
		if len(co) > 0 && len(do) > 0 {
			cm := median(co, func(s sample) time.Duration { return s.P.total() })
			dm := median(do, func(s sample) time.Duration { return s.P.total() })
			fmt.Println()
			fmt.Printf("SINGLE BUILD vs BASELINE: C-shared is %.1fx D-base (%.1f ms vs %.1f ms per render)\n",
				float64(cm)/float64(dm), ms(cm), ms(dm))
			fmt.Println("The hypothesis in README.md is refuted above roughly 10x.")
		}
	}
}

func findArm(rs []armResult, name string) *armResult {
	for i := range rs {
		if rs[i].Name == name {
			return &rs[i]
		}
	}
	return nil
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
	idx := (p * (len(vals) - 1)) / 100
	return vals[idx]
}

func median(ss []sample, f func(sample) time.Duration) time.Duration {
	return pct(ss, f, 50)
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

func rule(n int) string {
	s := ""
	for i := 0; i < n; i++ {
		s += "-"
	}
	return s
}

// memSnapshot forces a GC first so HeapInuse reports retention rather than
// churn, which is the distinction that matters for an operator holding many
// renders' worth of state.
func memSnapshot() runtime.MemStats {
	runtime.GC()
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	return m
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "error: %v\n", err)
	os.Exit(1)
}

func abs(p string) string {
	a, err := filepath.Abs(p)
	if err != nil {
		return p
	}
	return a
}
