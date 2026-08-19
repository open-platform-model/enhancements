#!/usr/bin/env bash
# 0019 experiment 08 - do experiment 06's concurrency answers survive
# experiment 07's module sizes?
#
# Same fixtures as 07, byte for byte. Three strategies (S2 fresh context per
# render, S1 context per worker, SB today's path serialised behind a mutex)
# across a worker sweep at four module sizes.
#
#   ./run.sh                 the full sweep
#   ./run.sh --fresh         rebuild the scratch tree first
#   ./run.sh --race          the safety half: race detector on, one size
#   ./run.sh -sizes 128 -renders 16 -workers 1,16
#
# Everything is assembled under ${WORK:-./_out/run}. Pass -keep to inspect it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CUE_REGISTRY="${CUE_REGISTRY:-opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works}"
cd "$HERE"

FRESH=0
RACE=0
ARGS=()
for a in "$@"; do
	case "$a" in
	--fresh) FRESH=1 ;;
	--race) RACE=1 ;;
	*) ARGS+=("$a") ;;
	esac
done

if [[ $FRESH -eq 1 ]]; then
	rm -rf _out/run
fi

echo "== setup"
go run . -setup-only -keep "${ARGS[@]+"${ARGS[@]}"}"

if [[ $RACE -eq 1 ]]; then
	# The race detector multiplies both time and memory, so the safety half
	# runs one size with few renders. Experiment 06 already established that
	# S2 is race-clean on a small module; this asks only whether size changes
	# that answer.
	echo
	echo "== measure (race detector ON)"
	# S1 is deliberately excluded: it holds 9.8 GB at this size without the
	# detector, and the detector multiplies that. Experiment 06 already
	# established S1 is race-clean; what is unknown is whether SIZE changes the
	# answer for the shapes an operator would actually run.
	exec go run -race . -reuse -keep -sizes 32 -renders 8 -workers 1,8 -strategy S2,SB -max-rss-gb 20 "${ARGS[@]+"${ARGS[@]}"}"
fi

echo
echo "== measure"
exec go run . -reuse -keep "${ARGS[@]+"${ARGS[@]}"}"
