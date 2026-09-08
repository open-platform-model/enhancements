package main

// The four strategies and the worker pool that runs them.
//
// Each strategy is one way of handing a cue.Context to a worker. They render
// the same N instances from the same tree and assert the same five outputs, so
// the only thing that varies across a point is what is shared between workers.

import (
	"fmt"
	"os"
	"runtime"
	"runtime/debug"
	"runtime/metrics"
	"strconv"
	"strings"
	"sync"
	"time"

	"cuelang.org/go/cue/cuecontext"
)

// renderFunc renders instance idx and returns its timing and an output digest.
type renderFunc func(idx int) (phases, string, error)

// family names which sequential reference an output digest is compared
// against. The single-build path and the baseline path render genuinely
// different shapes -- the baseline's components are finalized and its #context
// is Go-built -- so their digests are not comparable to each other and must
// not be pooled.
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
	newPoint func(t *tree, workers int) (factory func(worker int) renderFunc, oneTime time.Duration, err error)
}

func strategies() []strategy {
	return []strategy{
		{
			ID:     "S1",
			Label:  "S1-ctx-per-worker",
			Family: familySingle,
			Note:   "one cue.Context per worker, reused across that worker's renders. The shape the hypothesis rests on",
			newPoint: func(t *tree, workers int) (func(int) renderFunc, time.Duration, error) {
				return func(int) renderFunc {
					cctx := cuecontext.New()
					return func(idx int) (phases, string, error) {
						return renderOnce(cctx, t.Renders[idx])
					}
				}, 0, nil
			},
		},
		{
			ID:     "S2",
			Label:  "S2-ctx-per-render",
			Family: familySingle,
			Note:   "a fresh cue.Context per render. The safest possible shape, and the one that shares nothing",
			newPoint: func(t *tree, workers int) (func(int) renderFunc, time.Duration, error) {
				return func(int) renderFunc {
					return func(idx int) (phases, string, error) {
						return renderOnce(cuecontext.New(), t.Renders[idx])
					}
				}, 0, nil
			},
		},
		{
			ID:     "S3",
			Label:  "S3-ctx-shared",
			Family: familySingle,
			Note:   "ONE cue.Context for every worker. The direct test of execute.go's comment; the value is in how it fails",
			newPoint: func(t *tree, workers int) (func(int) renderFunc, time.Duration, error) {
				shared := cuecontext.New()
				return func(int) renderFunc {
					return func(idx int) (phases, string, error) {
						return renderOnce(shared, t.Renders[idx])
					}
				}, 0, nil
			},
		},
		{
			ID:     "S4",
			Label:  "S4-baseline",
			Family: familyBaseline,
			Note:   "ADR-002's model: one prebuilt platform held read-only, per-worker contexts, cross-context fill. Yardstick and independent check on the ADR",
			newPoint: func(t *tree, workers int) (func(int) renderFunc, time.Duration, error) {
				owner := cuecontext.New()
				hold, err := holdPlatform(owner, t.Renders[0])
				if err != nil {
					return nil, 0, err
				}
				return func(int) renderFunc {
					cctx := cuecontext.New()
					return func(idx int) (phases, string, error) {
						return baselineRender(cctx, t.Instances[idx], hold)
					}
				}, hold.build, nil
			},
		},
		{
			ID:     "S5",
			Label:  "S5-base-prewalked",
			Family: familyBaseline,
			Note:   "S4 with the held platform walked to completion before any worker touches it. Isolates lazy evaluation of a shared value from sharing itself",
			newPoint: func(t *tree, workers int) (func(int) renderFunc, time.Duration, error) {
				owner := cuecontext.New()
				t0 := time.Now()
				hold, err := holdPlatform(owner, t.Renders[0])
				if err != nil {
					return nil, 0, err
				}
				forceWalk(hold.transformers, 0)
				return func(int) renderFunc {
					cctx := cuecontext.New()
					return func(idx int) (phases, string, error) {
						return baselineRender(cctx, t.Instances[idx], hold)
					}
				}, time.Since(t0), nil
			},
		},
	}
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
	Digest string
	Err    error
}

type pointResult struct {
	Strategy string
	Label    string
	Workers  int
	Wall     time.Duration
	OneTime  time.Duration
	Samples  []sample
	Mismatch []int // indices whose digest disagreed with the sequential reference
	Mem      memReading
}

func (r pointResult) throughput() float64 {
	if r.Wall == 0 {
		return 0
	}
	return float64(len(r.Samples)) / r.Wall.Seconds()
}

// runPoint renders indices [0,n) across `workers` goroutines.
//
// The jobs channel hands each index to whichever worker is free, which is the
// scheduling an operator's work queue would do. Wall time brackets only the
// pool: the shared state and the per-worker contexts are built before it
// starts, so a strategy is never charged for setup another strategy avoids.
func runPoint(s strategy, t *tree, workers, n int, ref map[int]string) (pointResult, error) {
	res := pointResult{Strategy: s.ID, Label: s.Label, Workers: workers}

	factory, oneTime, err := s.newPoint(t, workers)
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

	// A settled heap before the sampler starts, so peak-minus-start is this
	// point's own growth rather than the previous point's garbage.
	runtime.GC()
	debug.FreeOSMemory()
	mem := startMemSampler()

	start := time.Now()
	for w := 0; w < workers; w++ {
		wg.Add(1)
		go func(w int, render renderFunc) {
			defer wg.Done()
			for idx := range jobs {
				t0 := time.Now()
				p, dig, err := guard(func() (phases, string, error) { return render(idx) })
				p.Wall = time.Since(t0)
				out <- sample{Index: idx, Worker: w, P: p, Digest: dig, Err: err}
			}
		}(w, renders[w])
	}
	wg.Wait()
	res.Wall = time.Since(start)
	res.Mem = mem.stop()

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
			if want, ok := ref[sm.Index]; ok && want != sm.Digest {
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
// 04's 90.2 ms (single build) and 42.3 ms (baseline).
func reference(s strategy, t *tree, n int) (map[int]string, []sample, error) {
	factory, _, err := s.newPoint(t, 1)
	if err != nil {
		return nil, nil, err
	}
	render := factory(0)
	ref := make(map[int]string, n)
	var samples []sample
	for i := 0; i < n; i++ {
		t0 := time.Now()
		p, dig, err := guard(func() (phases, string, error) { return render(i) })
		p.Wall = time.Since(t0)
		if err != nil {
			return nil, nil, fmt.Errorf("reference render %d: %w", i, err)
		}
		ref[i] = dig
		samples = append(samples, sample{Index: i, P: p, Digest: dig})
	}
	return ref, samples, nil
}

// ---------------------------------------------------------------------------
// Memory
// ---------------------------------------------------------------------------
//
// Sampled DURING the point rather than read after it. Experiment 04 read
// HeapInuse once at the end, which answers "what did the arm retain"; the
// question here is whether P workers each holding a catalog fit in an
// operator's budget at the moment they are all holding one, and that peak is
// gone by the time the point ends.

type memReading struct {
	RSSStart  uint64
	RSSPeak   uint64
	HeapStart uint64
	HeapPeak  uint64
	// HeapKept is live heap after a forced GC at the end of the point, taken
	// while the strategy's contexts are still referenced. It is the difference
	// between "this point churned a lot" and "this point is HOLDING a lot",
	// and it is the reading experiment 04 could not take: there the context was
	// already dead by the time its heap was measured.
	HeapKept uint64
	Samples  int
}

type memSampler struct {
	stopc chan struct{}
	done  chan memReading
}

const memSampleInterval = 20 * time.Millisecond

func startMemSampler() *memSampler {
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
				if v := rss(); v > r.RSSPeak {
					r.RSSPeak = v
				}
				if v := heapLive(); v > r.HeapPeak {
					r.HeapPeak = v
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
// 50 Hz and, unlike ReadMemStats, it does not stop the world -- which matters
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
