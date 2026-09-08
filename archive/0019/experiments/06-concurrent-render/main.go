// Experiment 06 harness: do renders run at the same time?
//
// Experiment 04 measured what one render costs, sequentially. This one asks
// whether that cost sits under a throughput ceiling. Four strategies, each a
// way of handing a cue.Context to a worker, are run across a worker sweep
// rendering the same fixed number of instances:
//
//	S1-ctx-per-worker   one context per worker, reused
//	S2-ctx-per-render   a fresh context every render
//	S3-ctx-shared       one context for every worker (execute.go says unsafe)
//	S4-baseline         ADR-002: platform held read-only, per-worker contexts
//
// Three instruments rather than one. Throughput and latency answer the scaling
// half; a memory sampler running DURING the point answers whether P workers
// each holding a catalog fit in a budget; and every render's output is hashed
// and compared against a sequential reference, because a concurrency bug that
// returns a WRONG value rather than crashing is the failure a throughput
// number would hide.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"cuelang.org/go/cue/cuecontext"
)

// defaultRegistry is the workspace's canonical developer mapping, used only
// when CUE_REGISTRY is absent, so a run always states what it resolved against.
const defaultRegistry = "opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"

func main() {
	n := flag.Int("n", 80, "renders per point; the same total at every worker count, so throughput is comparable across the sweep")
	workersFlag := flag.String("workers", "1,2,4,8,16", "worker sweep")
	stratFlag := flag.String("strategy", "all", "S1, S2, S3, S4, a comma-separated subset, or all")
	fixturesDir := flag.String("fixtures", "fixtures", "fixture tree to materialize from")
	workDir := flag.String("work", "_out/run", "scratch tree")
	reuse := flag.Bool("reuse", false, "adopt an existing complete scratch tree instead of rebuilding it")
	keep := flag.Bool("keep", false, "keep the scratch tree on exit")
	skipRef := flag.Bool("skip-ref", false, "skip the sequential reference pass (drops the wrong-value check)")
	setupOnly := flag.Bool("setup-only", false, "materialize the scratch tree, warm the module cache, and exit; used by run.sh so the per-strategy processes share one tree")
	flag.Parse()

	if os.Getenv("CUE_REGISTRY") == "" {
		os.Setenv("CUE_REGISTRY", defaultRegistry)
	}

	workers, err := parseInts(*workersFlag)
	if err != nil {
		fatal(err)
	}
	sels, err := selectStrategies(*stratFlag)
	if err != nil {
		fatal(err)
	}

	fmt.Printf("GOMAXPROCS=%d NumCPU=%d race=%v go=%s n=%d workers=%v\n",
		runtime.GOMAXPROCS(0), runtime.NumCPU(), raceEnabled, runtime.Version(), *n, workers)
	fmt.Printf("CUE_REGISTRY=%s\n", os.Getenv("CUE_REGISTRY"))

	t, reused, err := materialize(*fixturesDir, *workDir, *n, *reuse)
	if err != nil {
		fatal(err)
	}
	if reused {
		fmt.Printf("reusing scratch tree at %s (%d instances)\n", t.Root, *n)
	} else {
		fmt.Printf("materialized %d instances under %s\n", *n, t.Root)
	}
	if !*keep && !*reuse {
		defer os.RemoveAll(t.Root)
	}

	// One throwaway render warms the module cache, so the first timed render is
	// not a registry fetch in disguise. Nothing in the sweep is comparable to a
	// cold cache; experiment 04 measured that separately and found it a
	// one-off 1.76 s per process rather than a per-render cost.
	fmt.Print("priming the module cache ... ")
	primeStart := time.Now()
	if _, _, err := renderOnce(cuecontext.New(), t.Renders[0]); err != nil {
		fatal(fmt.Errorf("prime: %w", err))
	}
	fmt.Printf("%.1f ms\n\n", ms(time.Since(primeStart)))

	if *setupOnly {
		return
	}

	refs := map[family]map[int]string{}
	var results []pointResult

	for _, s := range sels {
		if !*skipRef {
			ref, seq, err := referenceFor(s.Family, t, *n, filepath.Join(filepath.Dir(*workDir), fmt.Sprintf("ref-%s.json", s.Family)), refs)
			if err != nil {
				fatal(err)
			}
			refs[s.Family] = ref
			if seq != nil {
				fmt.Printf("sequential reference (%s family): %.1f ms per render, n=%d  [experiment 04 measured 90.2 ms single-build, 42.3 ms baseline]\n\n",
					s.Family, ms(median(seq)), len(seq))
			}
		}

		fmt.Printf("%s -- %s\n", s.Label, s.Note)
		header()
		var pts []pointResult
		for _, w := range workers {
			pt, err := runPoint(s, t, w, *n, refs[s.Family])
			if err != nil {
				fmt.Printf("  %-4d point failed: %v\n", w, err)
				continue
			}
			row(pt, pts)
			pts = append(pts, pt)
			results = append(results, pt)
		}
		verdict(s, pts)
		fmt.Println()
	}

	summary(results)
}

// ---------------------------------------------------------------------------
// Reference digests
// ---------------------------------------------------------------------------

// referenceFor returns the sequential digest of every index for one family,
// from the in-process map, then from the on-disk cache, then by rendering.
// The cache exists because run.sh gives each strategy its own process and the
// reference is identical across them; recomputing it four times would cost more
// than the sweep.
func referenceFor(f family, t *tree, n int, cachePath string, inProc map[family]map[int]string) (map[int]string, []sample, error) {
	if ref, ok := inProc[f]; ok {
		return ref, nil, nil
	}
	if ref, ok := loadRef(cachePath, n); ok {
		fmt.Printf("sequential reference (%s family): loaded %d digests from %s\n\n", f, n, cachePath)
		return ref, nil, nil
	}

	var s strategy
	switch f {
	case familySingle:
		s, _ = strategyByID("S1")
	case familyBaseline:
		s, _ = strategyByID("S4")
	}
	fmt.Printf("sequential reference (%s family): rendering %d instances in one goroutine ...\n", f, n)
	ref, seq, err := reference(s, t, n)
	if err != nil {
		return nil, nil, err
	}
	saveRef(cachePath, ref)
	return ref, seq, nil
}

func loadRef(path string, n int) (map[int]string, bool) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, false
	}
	var raw map[string]string
	if json.Unmarshal(b, &raw) != nil {
		return nil, false
	}
	out := make(map[int]string, len(raw))
	for k, v := range raw {
		i, err := strconv.Atoi(k)
		if err != nil {
			return nil, false
		}
		out[i] = v
	}
	for i := 0; i < n; i++ {
		if _, ok := out[i]; !ok {
			return nil, false
		}
	}
	return out, true
}

func saveRef(path string, ref map[int]string) {
	raw := make(map[string]string, len(ref))
	for k, v := range ref {
		raw[strconv.Itoa(k)] = v
	}
	b, err := json.Marshal(raw)
	if err != nil {
		return
	}
	_ = os.MkdirAll(filepath.Dir(path), 0o755)
	_ = os.WriteFile(path, b, 0o644)
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

func header() {
	fmt.Printf("  %-4s %8s %9s %8s %9s %9s %6s %6s %10s %10s %10s\n",
		"P", "WALL_s", "RENDER/s", "SPEEDUP", "LAT_p50", "LAT_p90", "ERRS", "WRONG", "RSS_PEAK", "HEAP_PEAK", "HEAP_KEPT")
	fmt.Println("  " + strings.Repeat("-", 108))
}

func row(pt pointResult, prev []pointResult) {
	ok := okSamples(pt.Samples)
	speed := ""
	if len(prev) > 0 && prev[0].throughput() > 0 {
		speed = fmt.Sprintf("%.2fx", pt.throughput()/prev[0].throughput())
	} else {
		speed = "1.00x"
	}
	fmt.Printf("  %-4d %8.2f %9.1f %8s %9.1f %9.1f %6d %6d %10s %10s %10s\n",
		pt.Workers,
		pt.Wall.Seconds(),
		pt.throughput(),
		speed,
		ms(pct(ok, 50)),
		ms(pct(ok, 90)),
		len(pt.Samples)-len(ok),
		len(pt.Mismatch),
		human(pt.Mem.RSSPeak),
		human(pt.Mem.HeapPeak),
		human(pt.Mem.HeapKept),
	)
	if err := firstErr(pt.Samples); err != nil {
		fmt.Printf("       first error: %s\n", indent(err.Error()))
	}
	if len(pt.Mismatch) > 0 {
		fmt.Printf("       WRONG VALUE at indices %v -- a concurrent render disagreed with the sequential one\n", pt.Mismatch)
	}
	if pt.OneTime > 0 && len(prev) == 0 {
		fmt.Printf("       one-time platform hold, outside the timed window: %.1f ms\n", ms(pt.OneTime))
	}
}

// verdict states the two falsification criteria the README fixed before the
// harness was written, so the reading is not chosen after seeing the numbers.
func verdict(s strategy, pts []pointResult) {
	if len(pts) < 2 {
		return
	}
	base := pts[0]
	best := pts[0]
	for _, p := range pts {
		if p.throughput() > best.throughput() {
			best = p
		}
	}
	if base.throughput() == 0 {
		return
	}
	peak := best.throughput() / base.throughput()

	// The stated threshold is "refuted on scaling if throughput plateaus below
	// roughly 2x at four or more workers".
	at4, measured4 := 0.0, false
	for _, p := range pts {
		if p.Workers >= 4 {
			measured4 = true
			if p.throughput()/base.throughput() > at4 {
				at4 = p.throughput() / base.throughput()
			}
		}
	}
	if measured4 {
		fmt.Printf("  scaling: peak %.2fx at P=%d; best at P>=4 is %.2fx (README refutes below ~2x) -> %s\n",
			peak, best.Workers, at4, held(at4 >= 2.0))
	} else {
		fmt.Printf("  scaling: peak %.2fx at P=%d; the sweep carries no point at P>=4, so the stated threshold is not measured here\n",
			peak, best.Workers)
	}

	// And "refuted on memory if peak resident grows per render rather than per
	// worker". Within one point that reads as: does per-worker growth stay
	// roughly flat as P rises?
	first, last := pts[0], pts[len(pts)-1]
	fmt.Printf("  memory: heap kept %s at P=%d vs %s at P=%d, %s per render at P=%d. Kept memory that scales with RENDERS rather than workers is the shape the README refutes on\n",
		human(first.Mem.HeapKept), first.Workers,
		human(last.Mem.HeapKept), last.Workers,
		human(first.Mem.HeapKept/uint64(len(first.Samples))), first.Workers)

	errs, wrong := 0, 0
	for _, p := range pts {
		errs += len(p.Samples) - len(okSamples(p.Samples))
		wrong += len(p.Mismatch)
	}
	fmt.Printf("  safety: %d failed renders, %d wrong values across the sweep, race detector %s\n",
		errs, wrong, raceWord())
}

func held(b bool) string {
	if b {
		return "HELD"
	}
	return "REFUTED"
}

func summary(all []pointResult) {
	if len(all) < 2 {
		return
	}
	fmt.Println("SUMMARY -- renders per second")
	fmt.Println()
	byStrategy := map[string][]pointResult{}
	var order []string
	for _, p := range all {
		if _, ok := byStrategy[p.Strategy]; !ok {
			order = append(order, p.Strategy)
		}
		byStrategy[p.Strategy] = append(byStrategy[p.Strategy], p)
	}
	var ws []int
	seen := map[int]bool{}
	for _, p := range all {
		if !seen[p.Workers] {
			seen[p.Workers] = true
			ws = append(ws, p.Workers)
		}
	}
	sort.Ints(ws)

	fmt.Printf("  %-18s", "STRATEGY")
	for _, w := range ws {
		fmt.Printf(" %9s", fmt.Sprintf("P=%d", w))
	}
	fmt.Println()
	for _, id := range order {
		pts := byStrategy[id]
		fmt.Printf("  %-18s", pts[0].Label)
		for _, w := range ws {
			v := ""
			for _, p := range pts {
				if p.Workers == w {
					v = fmt.Sprintf("%.1f", p.throughput())
				}
			}
			fmt.Printf(" %9s", v)
		}
		fmt.Println()
	}
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

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

func pct(ss []sample, p int) time.Duration {
	if len(ss) == 0 {
		return 0
	}
	vals := make([]time.Duration, len(ss))
	for i, s := range ss {
		vals[i] = s.P.Wall
	}
	sort.Slice(vals, func(i, j int) bool { return vals[i] < vals[j] })
	return vals[(p*(len(vals)-1))/100]
}

func median(ss []sample) time.Duration { return pct(ss, 50) }

func parseInts(s string) ([]int, error) {
	var out []int
	for _, part := range strings.Split(s, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		v, err := strconv.Atoi(part)
		if err != nil || v < 1 {
			return nil, fmt.Errorf("bad worker count %q", part)
		}
		out = append(out, v)
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("no worker counts given")
	}
	return out, nil
}

func selectStrategies(s string) ([]strategy, error) {
	if s == "all" || s == "" {
		return strategies(), nil
	}
	var out []strategy
	for _, part := range strings.Split(s, ",") {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}
		st, ok := strategyByID(part)
		if !ok {
			return nil, fmt.Errorf("unknown strategy %q", part)
		}
		out = append(out, st)
	}
	return out, nil
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

func humanSigned(v int64) string {
	if v < 0 {
		return "-" + human(uint64(-v))
	}
	return human(uint64(v))
}

func indent(s string) string {
	lines := strings.Split(s, "\n")
	for i := 1; i < len(lines); i++ {
		lines[i] = "         " + lines[i]
	}
	return strings.Join(lines, "\n")
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "error: %v\n", err)
	os.Exit(1)
}
