#!/usr/bin/env bash
# 0019 experiment 06 - do renders run at the same time?
#
# Four strategies across a worker sweep, each rendering the same fixed number of
# instances against one identical platform. See README.md.
#
# Every strategy runs in its OWN process. That is not tidiness: a shared
# cue.Context is expected to be unsafe, and the unsafe outcomes CUE can produce
# include a fatal runtime throw (a concurrent map write is not recoverable by
# design), which would take the other strategies' numbers down with it. One
# process per strategy means a crash is recorded as this strategy's result
# instead of erasing the run.
#
# Everything is assembled under ${WORK:-./_out/run} and removed afterwards;
# nothing in this directory is mutated. Pass --keep to inspect the tree.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

export CUE_REGISTRY="${CUE_REGISTRY:-opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works}"

WORK="${WORK:-_out/run}"
RACE=()
KEEP=0
MEM=0
STRATEGIES=(S1 S2 S3 S4 S5)
PASSTHROUGH=()

while [[ $# -gt 0 ]]; do
	case "$1" in
	--race | -race)
		# The instrument for the safety half. It slows every render by roughly
		# an order of magnitude, so a race run is for verdicts, never for the
		# throughput table.
		RACE=(-race)
		shift
		;;
	--keep) KEEP=1; shift ;;
	--mem)
		# Does peak memory grow per worker or per render? Fixed worker count,
		# rising N, one process each so the peaks do not carry over.
		MEM=1
		shift
		;;
	--strategy | -strategy)
		IFS=', ' read -r -a STRATEGIES <<<"$2"
		shift 2
		;;
	*) PASSTHROUGH+=("$1"); shift ;;
	esac
done

# One shared scratch tree and one warm module cache for every process below.
# Materialization shells out to `cue mod edit` per render and would otherwise be
# paid four times over.
N_SETUP=80
for ((i = 0; i < ${#PASSTHROUGH[@]}; i++)); do
	[[ "${PASSTHROUGH[$i]}" == "-n" ]] && N_SETUP="${PASSTHROUGH[$((i + 1))]}"
done
[[ $MEM -eq 1 ]] && N_SETUP=160

echo "== setup: one scratch tree of $N_SETUP instances, shared by every process below"
go run . -setup-only -n "$N_SETUP" -work "$WORK" -keep || exit 1

cleanup() {
	if [[ $KEEP -eq 0 ]]; then
		rm -rf "$WORK"
	else
		echo "scratch tree kept at $WORK"
	fi
}
trap cleanup EXIT

if [[ $MEM -eq 1 ]]; then
	echo
	echo "== memory scaling: fixed P=4, rising N, one process per point."
	echo "   Kept heap rising with N is memory per RENDER (the shape that makes a long-lived"
	echo "   process untenable); kept heap flat in N is memory per WORKER."
	for s in S1 S2 S4; do
		for n in 20 40 80 160; do
			go run "${RACE[@]}" . -strategy "$s" -workers 4 -n "$n" -work "$WORK" -reuse -keep -skip-ref
			echo
		done
	done
	exit 0
fi

status=0
for s in "${STRATEGIES[@]}"; do
	echo
	echo "== strategy $s"
	go run "${RACE[@]}" . -strategy "$s" -work "$WORK" -reuse -keep "${PASSTHROUGH[@]}"
	rc=$?
	if [[ $rc -ne 0 ]]; then
		echo "!! strategy $s exited $rc. For S3 that is the result, not an accident: record how it died."
		status=$rc
	fi
done

exit $status
