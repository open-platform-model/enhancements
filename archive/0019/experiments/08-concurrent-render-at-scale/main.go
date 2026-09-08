// Experiment 08 harness: do experiment 06's concurrency answers survive
// experiment 07's module sizes?
//
// 06 measured throughput, retention and safety on a two-component module whose
// renders churn about 60 MB. 07 then measured that a 129-component module
// churns about 900 MB per render. Nothing has checked whether P workers each
// doing that still behave the way 06 measured, and the enhancement's standing
// recommendation (a fresh cue.Context per render, nothing shared) rests on it.
//
// Same fixtures as 07, byte for byte. Three strategies:
//
//	S2  a fresh cue.Context per render          the shape 04 and 06 leave standing
//	S1  one cue.Context per worker, reused      the shape 06 disqualified on memory
//	SB  today's path, held platform, mutex      the yardstick an operator can safely run
//
// The RSS ceiling is not a convenience: a strategy that retains per render can
// exhaust the machine inside one point at these sizes, and a point that stops
// at the ceiling is a measurement where an OOM kill would be a lost run.
package main

import (
	"flag"
	"fmt"
	"os"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"cuelang.org/go/cue/cuecontext"
)

// defaultRegistry is the workspace's canonical developer mapping. Used only
// when CUE_REGISTRY is absent, so a run always states which mapping it resolved
// against rather than failing obscurely.
const defaultRegistry = "opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"

// phases is the per-render breakdown, plus the wall time that render occupied a
// worker. Under contention Wall exceeds the sum of the phases, and the gap is
// scheduler and GC time rather than CUE.
type phases struct {
	Load   time.Duration
	Build  time.Duration
	Eval   time.Duration
	Export time.Duration
	Wall   time.Duration
}

func (p phases) total() time.Duration { return p.Load + p.Build + p.Eval + p.Export }

func main() {
	sizesFlag := flag.String("sizes", "1,8,32,128", "fleet sizes (servers; components are this +1)")
	rendersFlag := flag.String("renders", "64,64,48,32", "renders per point, one per size; large modules get fewer because a render costs seconds")
	workersFlag := flag.String("workers", "1,2,4,8,16", "worker counts; 1 must be present and is used as each strategy's own sequential reference")
	stratFlag := flag.String("strategy", "S2,S1,SB", "strategies to run")
	maxRSS := flag.Float64("max-rss-gb", 24, "stop handing out jobs when resident memory crosses this; 0 disables the guard")
	fixturesDir := flag.String("fixtures", "fixtures", "fixture tree to materialize from")
	workDir := flag.String("work", "_out/run", "scratch tree")
	reuse := flag.Bool("reuse", false, "reuse an existing scratch tree instead of rebuilding it")
	keep := flag.Bool("keep", false, "keep the scratch tree for inspection")
	setupOnly := flag.Bool("setup-only", false, "materialize the tree and exit")
	fixture := flag.String("fixture", "fleet", "which experiment 07 fixture to use: fleet (breadth) or complex (depth)")
	style := flag.String("style", "bp", "authoring style: bp (blueprints) or raw (resources and traits)")
	split := flag.Bool("timesplit", false, "instead of the sweep: hold the instance fixed and vary how many components the render module asks for, to find what fraction of a render a split could divide")
	flag.Parse()

	if os.Getenv("CUE_REGISTRY") == "" {
		os.Setenv("CUE_REGISTRY", defaultRegistry)
	}

	sizes := ints(*sizesFlag)
	renders := ints(*rendersFlag)
	workers := ints(*workersFlag)
	if len(sizes) == 0 || len(renders) != len(sizes) || len(workers) == 0 {
		fatal(fmt.Errorf("-sizes and -renders must be non-empty and the same length, and -workers non-empty"))
	}
	if workers[0] != 1 {
		fatal(fmt.Errorf("-workers must include 1: each strategy's P=1 point IS its sequential reference"))
	}

	var points []point
	maxN := 0
	for i, k := range sizes {
		points = append(points, point{Fixture: *fixture, Style: *style, K: k})
		if renders[i] > maxN {
			maxN = renders[i]
		}
	}

	var sel []strategy
	for _, id := range strings.Split(*stratFlag, ",") {
		s, ok := strategyByID(strings.TrimSpace(id))
		if !ok {
			fatal(fmt.Errorf("unknown strategy %q", id))
		}
		sel = append(sel, s)
	}

	ceiling := uint64(*maxRSS * float64(1<<30))

	fmt.Printf("GOMAXPROCS=%d NumCPU=%d race=%v go=%s\n", runtime.GOMAXPROCS(0), runtime.NumCPU(), raceEnabled, runtime.Version())
	fmt.Printf("CUE_REGISTRY=%s\n", os.Getenv("CUE_REGISTRY"))
	fmt.Printf("fixture=%s style=%s sizes=%v renders=%v workers=%v strategies=%s rss-ceiling=%.1fG\n",
		*fixture, *style, sizes, renders, workers, *stratFlag, *maxRSS)

	t, reused, err := materialize(*fixturesDir, *workDir, points, maxN, *reuse)
	if err != nil {
		fatal(err)
	}
	if reused {
		fmt.Printf("reusing scratch tree at %s\n", t.Root)
	} else {
		fmt.Printf("materialized %d sizes x %d renders under %s\n", len(points), maxN, t.Root)
	}
	if *setupOnly {
		return
	}
	if !*keep {
		defer os.RemoveAll(t.Root)
	}

	fmt.Print("priming the module cache ... ")
	t0 := time.Now()
	if _, _, _, err := renderOnce(cuecontext.New(), t.renderDir(points[0], 0)); err != nil {
		fatal(fmt.Errorf("prime: %w", err))
	}
	fmt.Printf("%.1f ms\n\n", ms(time.Since(t0)))

	if *split {
		p := points[len(points)-1]
		if err := timeSplit(t, p, []int{1, p.components() / 4, p.components() / 2, p.components()}, 3); err != nil {
			fatal(err)
		}
		return
	}

	var all []pointResult
	// refs[strategy][size][idx]: the digests that strategy's own P=1 point
	// produced. P=1 is sequential by construction, so it is the oracle for
	// "did concurrency change the ANSWER" without paying for a separate
	// reference pass, which at these sizes would double the run.
	refs := map[string]map[int]map[int]digests{}

	header()
	for si, p := range points {
		n := renders[si]
		for _, s := range sel {
			for _, w := range workers {
				var ref map[int]digests
				if w != 1 {
					ref = refs[s.ID][p.K]
				}
				r, err := runPoint(s, t, p, w, n, ref, ceiling)
				if err != nil {
					fmt.Printf("%-18s k=%-4d P=%-3d FAILED: %v\n", s.Label, p.K, w, err)
					continue
				}
				if w == 1 {
					if refs[s.ID] == nil {
						refs[s.ID] = map[int]map[int]digests{}
					}
					m := map[int]digests{}
					for _, sm := range r.Samples {
						if sm.Err == nil {
							m[sm.Index] = sm.Digest
						}
					}
					refs[s.ID][p.K] = m
				}
				all = append(all, r)
				row(r)
			}
		}
		fmt.Println()
	}

	report(all, refs, sizes, workers, sel)
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

func header() {
	fmt.Printf("%-18s %5s %5s %4s %4s %9s %9s %10s %10s %10s %10s %5s %5s\n",
		"STRATEGY", "K", "COMPS", "P", "N", "WALL_s", "RENDER/s", "LAT_p50", "LAT_p90", "RSS_PEAK", "HEAP_KEPT", "ERRS", "WRONG")
	fmt.Println(rule(126))
}

func row(r pointResult) {
	ok := okSamples(r.Samples)
	fmt.Printf("%-18s %5d %5d %4d %4d %9.2f %9.1f %10.1f %10.1f %10s %10s %5d %5d",
		r.Label, r.Point.K, r.Point.components(), r.Workers, len(r.Samples),
		r.Wall.Seconds(), r.throughput(),
		ms(pct(ok, func(s sample) time.Duration { return s.P.Wall }, 50)),
		ms(pct(ok, func(s sample) time.Duration { return s.P.Wall }, 90)),
		human(r.Mem.RSSPeak), human(r.Mem.HeapKept),
		len(r.Samples)-len(ok), len(r.Mismatch),
	)
	if r.Capped {
		fmt.Print("  !! CAPPED by the RSS ceiling")
	}
	fmt.Println()
}

func report(all []pointResult, refs map[string]map[int]map[int]digests, sizes, workers []int, sel []strategy) {
	get := func(id string, k, w int) *pointResult {
		for i := range all {
			if all[i].Strategy == id && all[i].Point.K == k && all[i].Workers == w {
				return &all[i]
			}
		}
		return nil
	}

	// ---- throughput and speedup ----------------------------------------
	fmt.Println("THROUGHPUT (renders/s) and SPEEDUP over that strategy's own P=1")
	for _, s := range sel {
		fmt.Printf("\n  %s\n", s.Label)
		fmt.Printf("  %6s %7s", "K", "COMPS")
		for _, w := range workers {
			fmt.Printf(" %11s", fmt.Sprintf("P=%d", w))
		}
		fmt.Println()
		fmt.Println("  " + rule(13+12*len(workers)))
		for _, k := range sizes {
			base := get(s.ID, k, 1)
			fmt.Printf("  %6d %7d", k, k+1)
			for _, w := range workers {
				r := get(s.ID, k, w)
				if r == nil || base == nil || base.throughput() == 0 {
					fmt.Printf(" %11s", "-")
					continue
				}
				fmt.Printf(" %6.1f/%3.1fx", r.throughput(), r.throughput()/base.throughput())
			}
			fmt.Println()
		}
	}

	// ---- verdict 1: does scaling survive scale? -------------------------
	fmt.Println()
	fmt.Println("VERDICT 1 -- does concurrent scaling survive a large module?")
	fmt.Println("  README refutes if peak speedup at P>=4 falls below 2x at any size.")
	for _, s := range sel {
		for _, k := range sizes {
			base := get(s.ID, k, 1)
			best, bestW := 0.0, 0
			for _, w := range workers {
				if w < 4 {
					continue
				}
				if r := get(s.ID, k, w); r != nil && base != nil && base.throughput() > 0 {
					if sp := r.throughput() / base.throughput(); sp > best {
						best, bestW = sp, w
					}
				}
			}
			if bestW == 0 {
				continue
			}
			// The serialised yardstick cannot scale by construction, so it is
			// reported and not judged. Judging it would turn a design fact
			// into a fake refutation.
			if s.Family == familyBaseline {
				fmt.Printf("  %-18s k=%-4d peak %.2fx at P=%d -> n/a (serialised by construction)\n", s.Label, k, best, bestW)
				continue
			}
			verdict := "HELD"
			if best < 2.0 {
				verdict = "REFUTED"
			}
			fmt.Printf("  %-18s k=%-4d peak %.2fx at P=%d -> %s\n", s.Label, k, best, bestW, verdict)
		}
	}

	// ---- verdict 2: memory in P ----------------------------------------
	fmt.Println()
	fmt.Println("VERDICT 2 -- does peak resident memory grow about linearly in P?")
	fmt.Println("  P=4 to P=16 is 4x the workers. README refutes above 6x the RSS growth.")
	for _, s := range sel {
		for _, k := range sizes {
			a, b := get(s.ID, k, 4), get(s.ID, k, 16)
			if a == nil || b == nil || a.Mem.RSSPeak == 0 {
				continue
			}
			g := float64(b.Mem.RSSPeak) / float64(a.Mem.RSSPeak)
			verdict := "HELD"
			if g > 6 {
				verdict = "REFUTED"
			}
			fmt.Printf("  %-18s k=%-4d RSS peak %s at P=4 -> %s at P=16  (%.2fx) -> %s\n",
				s.Label, k, human(a.Mem.RSSPeak), human(b.Mem.RSSPeak), g, verdict)
		}
	}

	// ---- verdict 3: retention per render at scale -----------------------
	fmt.Println()
	fmt.Println("VERDICT 3 -- what does a reused cue.Context retain per render at these sizes?")
	fmt.Println("  Experiment 06 measured 37.5 MB per render on a 2-component module.")
	fmt.Printf("  %-18s %6s %7s %4s %6s %12s %14s\n", "STRATEGY", "K", "COMPS", "P", "N", "HEAP_KEPT", "PER RENDER")
	fmt.Println("  " + rule(74))
	for _, s := range sel {
		for _, k := range sizes {
			r := get(s.ID, k, 4)
			if r == nil || len(r.Samples) == 0 {
				continue
			}
			fmt.Printf("  %-18s %6d %7d %4d %6d %12s %14s\n",
				s.Label, k, k+1, r.Workers, len(r.Samples),
				human(r.Mem.HeapKept), human(r.Mem.HeapKept/uint64(len(r.Samples))))
		}
	}

	// ---- the yardstick --------------------------------------------------
	fmt.Println()
	fmt.Println("S2 CONCURRENT vs TODAY'S PATH SERIALISED (renders/s at best P)")
	fmt.Printf("  %6s %7s %14s %14s %9s\n", "K", "COMPS", "S2_best", "SB_best", "RATIO")
	fmt.Println("  " + rule(56))
	for _, k := range sizes {
		bestOf := func(id string) float64 {
			b := 0.0
			for _, w := range workers {
				if r := get(id, k, w); r != nil && r.throughput() > b {
					b = r.throughput()
				}
			}
			return b
		}
		s2, sb := bestOf("S2"), bestOf("SB")
		if s2 == 0 || sb == 0 {
			continue
		}
		fmt.Printf("  %6d %7d %14.2f %14.2f %8.2fx\n", k, k+1, s2, sb, s2/sb)
	}

	// ---- guards ---------------------------------------------------------
	fmt.Println()
	fmt.Println("GUARDS")
	wrong, errs, capped := 0, 0, 0
	for _, r := range all {
		wrong += len(r.Mismatch)
		errs += len(r.Samples) - len(okSamples(r.Samples))
		if r.Capped {
			capped++
		}
	}
	fmt.Printf("  wrong values (digest differs from that strategy's own P=1 render): %d\n", wrong)
	fmt.Printf("  failed renders: %d\n", errs)
	fmt.Printf("  points stopped by the RSS ceiling: %d\n", capped)
	for _, r := range all {
		if err := firstErr(r.Samples); err != nil {
			fmt.Printf("  first error (%s k=%d P=%d): %v\n", r.Label, r.Point.K, r.Workers, err)
			break
		}
	}

	// Cross-strategy agreement at P=1: the check that the per-strategy
	// references are themselves right, which a strategy compared only against
	// itself could never catch.
	for _, k := range sizes {
		var ids []string
		for id := range refs {
			if refs[id][k] != nil {
				ids = append(ids, id)
			}
		}
		sort.Strings(ids)
		if len(ids) < 2 {
			continue
		}
		agree, order, differ := 0, 0, 0
		for _, id := range ids[1:] {
			a, b := refs[ids[0]][k], refs[id][k]
			for idx, da := range a {
				db, ok := b[idx]
				if !ok {
					continue
				}
				switch {
				case da.Strict == db.Strict:
					agree++
				case da.Loose == db.Loose:
					order++
				default:
					differ++
				}
			}
		}
		fmt.Printf("  k=%d cross-strategy P=1 agreement: %d byte-identical, %d identical modulo list order, %d different\n",
			k, agree, order, differ)
	}

	fmt.Println()
	fmt.Printf("race detector: %s\n", raceWord())
}

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

func ints(s string) []int {
	var out []int
	for _, part := range strings.Split(s, ",") {
		if v, err := strconv.Atoi(strings.TrimSpace(part)); err == nil && v > 0 {
			out = append(out, v)
		}
	}
	return out
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
