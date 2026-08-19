#!/usr/bin/env bash
# 0019 experiment 04 - what does a per-render single CUE build cost?
#
# Four arms render the same N instances against one identical platform,
# differing only in what is reused between renders. See README.md.
#
# Everything is assembled under ${WORK:-./_out/run} and removed afterwards;
# nothing in this directory is mutated. Pass -keep to inspect the tree.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CUE_REGISTRY="${CUE_REGISTRY:-opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works}"

cd "$HERE"
exec go run . "$@"
