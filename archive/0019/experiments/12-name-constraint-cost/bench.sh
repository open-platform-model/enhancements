#!/usr/bin/env bash
# Times `cue vet -c` of core/src with the benchmark fixture at N components,
# for each named variant of component.cue. Run from core/src with the fixture
# copied in as zz_bench.cue and the variants in $VARIANTS/component.<v>.cue.
# Restores component.cue to the "with" variant on exit.
set -euo pipefail
VARIANTS=${VARIANTS:?dir holding component.<variant>.cue}
trap 'cp "$VARIANTS/component.with.cue" component.cue' EXIT
bench() {
  local variant=$1 n=$2 runs=$3
  cp "$VARIANTS/component.$variant.cue" component.cue
  python3 - "$variant" "$n" "$runs" <<'PY'
import subprocess, sys, time, statistics
v, n, runs = sys.argv[1], sys.argv[2], int(sys.argv[3])
ts = []
for _ in range(runs):
    t = time.perf_counter()
    subprocess.run(["cue", "vet", "-c", "-t", f"n={n}", "./..."], check=True, capture_output=True)
    ts.append(time.perf_counter() - t)
ts.sort()
print(f"{v:8s} n={n:>4s} runs={runs} min={ts[0]*1000:8.1f}ms median={statistics.median(ts)*1000:8.1f}ms")
PY
}
for n in 10 100 500; do for v in without with; do bench "$v" "$n" 5; done; done
for v in without collect with; do bench "$v" 500 7; done
for v in without with; do bench "$v" 2000 5; done
