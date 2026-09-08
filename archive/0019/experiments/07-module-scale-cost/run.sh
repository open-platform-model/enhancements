#!/usr/bin/env bash
# 0019 experiment 07 - what does module SIZE cost the single-build render?
#
# Two fixtures (fleet = breadth, complex = depth), each authored two ways
# (blueprints vs raw resources and traits), swept across component counts, with
# the single build and today's held-platform path measured at every point.
#
# Everything is assembled under ${WORK:-./_out/run}. The tree is expensive to
# materialize (one generated CUE package per render), so it is built once with
# -setup-only and then reused; pass --fresh to rebuild it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CUE_REGISTRY="${CUE_REGISTRY:-opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works}"
cd "$HERE"

FRESH=0
ARGS=()
for a in "$@"; do
	case "$a" in
	--fresh) FRESH=1 ;;
	*) ARGS+=("$a") ;;
	esac
done

if [[ $FRESH -eq 1 ]]; then
	rm -rf _out/run
fi

# Setup pass: materialize once, so every measurement below reads an identical
# tree and the `cue mod edit` call is not repeated.
echo "== setup"
go run . -setup-only -keep "${ARGS[@]+"${ARGS[@]}"}"

echo
echo "== measure"
exec go run . -reuse -keep "${ARGS[@]+"${ARGS[@]}"}"
