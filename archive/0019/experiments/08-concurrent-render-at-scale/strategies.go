package main

// The three strategies, the worker pool, and the memory instrumentation.
//
// The pool and the sampler are copied from
// experiments/06-concurrent-render/strategies.go. The strategies are a subset:
// 06 measured five to find out which shapes are safe, and this experiment
// re-asks 06's questions at experiment 07's module sizes, so it carries the
// one 06 left standing, the one 06 disqualified on memory, and a yardstick for
// what today's path can safely do.

import (
	"fmt"
	"os"
	"runtime"
	"runtime/debug"
	"runtime/metrics"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"cuelang.org/go/cue/cuecontext"
)

// renderFunc renders instance idx and returns its timing and an output digest.
type renderFunc func(idx int) (phases, digests, error)

// family names which sequential reference an output digest is compared
// against. The single-build path and the baseline path render the same objects
// but not always the same BYTES (experiment 07: finalization reorders
// map-derived lists), so their digests are not comparable to each other and
// must not be pooled.
type family string

const (
	familySingle   family = "single"
	familyBaseline family = "baseline"
)

type strategy struct {
	ID     string
	Label  string
	Family family
	Note   string
	// newPoint builds whatever the workers share, then returns a factory for
	// per-worker render funcs. Both run outside the timed window; the returned
	// duration is the one-time cost, reported separately rather than amortised
	// into the per-render numbers.
	newPoint func(t *tree, p point, workers int) (factory func(worker int) renderFunc, oneTime time.Duration, err error)
}

func strategies() []strategy {
	return []strategy{
		{
			ID:     "S2",
			Label:  "S2-ctx-per-render",
			Family: familySingle,
			Note:   "a fresh cue.Context per render. Experiments 04 and 06 leave this one standing; this is the test of whether it survives a large module",
			newPoint: func(t *tree, p point, workers int) (func(int) renderFunc, time.Duration, error) {
				return func(int) renderFunc {
					return func(idx int) (phases, digests, error) {
						ph, dg, n, err := renderOnce(cuecontext.New(), t.renderDir(p, idx))
						return ph, dg, outputsErr(p, n, err)
					}
				}, 0, nil
			},
		},
		{
			ID:     "S1",
			Label:  "S1-ctx-per-worker",
			Family: familySingle,
			Note:   "one cue.Context per worker, reused across that worker's renders. Experiment 06 measured 37.5 MB retained per render on a 2-component module; this is the same reading with a render that churns 900 MB",
			newPoint: func(t *tree, p point, workers int) (func(int) renderFunc, time.Duration, error) {
				return func(int) renderFunc {
					cctx := cuecontext.New()
					return func(idx int) (phases, digests, error) {
						ph, dg, n, err := renderOnce(cctx, t.renderDir(p, idx))
						return ph, dg, outputsErr(p, n, err)
					}
				}, 0, nil
			},
		},
		{
			ID:     "SB",
			Label:  "SB-base-serialised",
			Family: familyBaseline,
			Note:   "today's path made safe: one held platform, one cue.Context, one mutex. The concurrent form of this is what produced 2321 data races in experiment 06, so a serialised version is the honest yardstick for what an operator can do today",
			newPoint: func(t *tree, p point, workers int) (func(int) renderFunc, time.Duration, error) {
				cctx := cuecontext.New()
				hold, err := holdPlatform(cctx, t.Render)
				if err != nil {
					return nil, 0, err
				}
				pairs, err := resolvePairs(hold.transformers, p.wants())
				if err != nil {
					return nil, 0, err
				}
				var mu sync.Mutex
				return func(int) renderFunc {
					return func(idx int) (phases, digests, error) {
						mu.Lock()
						defer mu.Unlock()
						ph, dg, n, err := baselineRender(cctx, t.instDir(p, idx), hold, pairs)
						return ph, dg, outputsErr(p, n, err)
					}
				}, hold.build, nil
			},
		},
	}
}

// outputsErr folds the output-count assertion into the render error. An empty
// `rendered` evaluates instantly, so without it a strategy that silently
// rendered nothing would report as the fastest.
func outputsErr(p point, n int, err error) error {
	if err != nil {
		return err
	}
	if n != p.outputs() {
		return fmt.Errorf("rendered %d outputs, expected %d", n, p.outputs())
	}
	return nil
}

func strategyByID(id string) (strategy, bool) {
	for _, s := range strategies() {
		if strings.EqualFold(s.ID, id) {
			return s, true
		}
	}
	return strategy{}, false
}

// ---------------------------------------------------------------------------
// One point: N renders across P workers
// ---------------------------------------------------------------------------

type sample struct {
	Index  int
	Worker int
	P      phases
	Digest digests
	Err    error
}

type pointResult struct {
	Strategy string
	Label    string
	Point    point
	Workers  int
	Wall     time.Duration
	OneTime  time.Duration
	Samples  []sample
	Mismatch []int // indices whose digest disagreed with the sequential reference
	Mem      memReading
	Capped   bool // the RSS guard stopped this point before every render ran
}

func (r pointResult) throughput() float64 {
	if r.Wall == 0 {
		return 0
	}
	return float64(len(r.Samples)) / r.Wall.Seconds()
}

// runPoint renders indices [0,n) across `workers` goroutines.
//
// Copied from experiment 06, with one addition this experiment needs: an RSS
// ceiling. A 129-component render churns about 900 MB (experiment 07), so a
// strategy that retains per render can exhaust a 46 GB machine inside one
// point. The guard stops handing out jobs when resident memory crosses the
// ceiling and the point is reported as CAPPED, which turns "this does not fit"
// into a measurement instead of an OOM kill.
func runPoint(s strategy, t *tree, p point, workers, n int, ref map[int]digests, rssCeiling uint64) (pointResult, error) {
	res := pointResult{Strategy: s.ID, Label: s.Label, Point: p, Workers: workers}

	factory, oneTime, err := s.newPoint(t, p, workers)
	if err != nil {
		return res, err
	}
	res.OneTime = oneTime

	renders := make([]renderFunc, workers)
	for w := 0; w < workers; w++ {
		renders[w] = factory(w)
	}

	jobs := make(chan int, n)
	for i := 0; i < n; i++ {
		jobs <- i
	}
	close(jobs)

	out := make(chan sample, n)
	var wg sync.WaitGroup
	var capped atomic.Bool

	// A settled heap before the sampler starts, so peak-minus-start is this
	// point's own growth rather than the previous point's garbage.
	runtime.GC()
	debug.FreeOSMemory()
	mem := startMemSampler(rssCeiling, &capped)

	start := time.Now()
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func(w int, render renderFunc) {
			defer wg.Done()
			for idx := range jobs {
				if capped.Load() {
					return
				}
				t0 := time.Now()
				ph, dig, err := guard(func() (phases, digests, error) { return render(idx) })
				ph.Wall = time.Since(t0)
				out <- sample{Index: idx, Worker: w, P: ph, Digest: dig, Err: err}
			}
		}(w, renders[w])
	}
	wg.Wait()
	res.Wall = time.Since(start)
	res.Mem = mem.stop()
	res.Capped = capped.Load()

	// Retention, measured with the workers' contexts deliberately still alive.
	// KeepAlive is load-bearing: without it Go's liveness analysis frees the
	// contexts before the GC runs and every strategy reports the same near-zero
	// number, which is precisely the reading that would hide a per-render leak.
	runtime.GC()
	res.Mem.HeapKept = heapLive()
	runtime.KeepAlive(renders)

	close(out)

	for sm := range out {
		if sm.Err == nil && ref != nil {
			if want, ok := ref[sm.Index]; ok && want.Strict != sm.Digest.Strict {
				res.Mismatch = append(res.Mismatch, sm.Index)
			}
		}
		res.Samples = append(res.Samples, sm)
	}
	return res, nil
}

// reference renders every index sequentially in one context and records the
// digests. It is the oracle for "did concurrency change the ANSWER", and it
// doubles as the P=1 control: its per-render cost should reproduce experiment
// 07's number for the same size.
func reference(s strategy, t *tree, p point, n int) (map[int]digests, error) {
	factory, _, err := s.newPoint(t, p, 1)
	if err != nil {
		return nil, err
	}
	render := factory(0)
	ref := make(map[int]digests, n)
	for i := 0; i < n; i++ {
		_, dig, err := guard(func() (phases, digests, error) { return render(i) })
		if err != nil {
			return nil, fmt.Errorf("reference render %d: %w", i, err)
		}
		ref[i] = dig
	}
	return ref, nil
}

// guard turns a panic inside one render into an error for that render. Copied
// from experiment 06: without it a single strategy throwing takes the whole
// sweep's results with it, and the throw is itself a result worth recording.
func guard(f func() (phases, digests, error)) (p phases, dig digests, err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic: %v", r)
		}
	}()
	return f()
}

// ---------------------------------------------------------------------------
// Memory
// ---------------------------------------------------------------------------
//
// Sampled DURING the point rather than read after it, because the question is
// whether P workers each holding a large module's working set fit in an
// operator's budget at the moment they are all holding one, and that peak is
// gone by the time the point ends.

type memReading struct {
	RSSStart  uint64
	RSSPeak   uint64
	HeapStart uint64
	HeapPeak  uint64
	// HeapKept is live heap after a forced GC at the end of the point, taken
	// while the strategy's contexts are still referenced. It is the difference
	// between "this point churned a lot" and "this point is HOLDING a lot".
	HeapKept uint64
	Samples  int
}

type memSampler struct {
	stopc chan struct{}
	done  chan memReading
}

const memSampleInterval = 20 * time.Millisecond

func startMemSampler(rssCeiling uint64, capped *atomic.Bool) *memSampler {
	m := &memSampler{stopc: make(chan struct{}), done: make(chan memReading, 1)}
	go func() {
		r := memReading{RSSStart: rss(), HeapStart: heapLive()}
		r.RSSPeak, r.HeapPeak = r.RSSStart, r.HeapStart
		tick := time.NewTicker(memSampleInterval)
		defer tick.Stop()
		for {
			select {
			case <-m.stopc:
				m.done <- r
				return
			case <-tick.C:
				v := rss()
				if v > r.RSSPeak {
					r.RSSPeak = v
				}
				if rssCeiling > 0 && v > rssCeiling {
					capped.Store(true)
				}
				if h := heapLive(); h > r.HeapPeak {
					r.HeapPeak = h
				}
				r.Samples++
			}
		}
	}()
	return m
}

func (m *memSampler) stop() memReading {
	close(m.stopc)
	return <-m.done
}

// rss reads resident set size from /proc/self/statm. Cheap enough to poll at
// 50 Hz and, unlike ReadMemStats, it does not stop the world, which matters
// when the thing being measured is throughput.
func rss() uint64 {
	b, err := os.ReadFile("/proc/self/statm")
	if err != nil {
		return 0
	}
	f := strings.Fields(string(b))
	if len(f) < 2 {
		return 0
	}
	pages, err := strconv.ParseUint(f[1], 10, 64)
	if err != nil {
		return 0
	}
	return pages * uint64(os.Getpagesize())
}

var heapMetric = []metrics.Sample{{Name: "/memory/classes/heap/objects:bytes"}}

// heapLive reads live heap bytes through runtime/metrics rather than
// ReadMemStats, for the same no-stop-the-world reason.
func heapLive() uint64 {
	metrics.Read(heapMetric)
	if heapMetric[0].Value.Kind() != metrics.KindUint64 {
		return 0
	}
	return heapMetric[0].Value.Uint64()
}
