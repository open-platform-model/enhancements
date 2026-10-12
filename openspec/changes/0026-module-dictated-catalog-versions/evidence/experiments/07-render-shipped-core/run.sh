#!/usr/bin/env bash
# Enhancement 0026, experiment 07. Checks out library at the pinned commit in
# a fresh work directory, copies overlay/ over it (one test file plus render
# fixtures, no library file changed) and runs the probe test. Nothing outside
# the work directory is written.
#
#   LIBRARY_SRC  where to clone library from (default: GitHub; a local clone
#                works too, the pinned commit is all that is read from it)
#   WORK         work directory (default: a new mktemp -d)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
library_sha=30f08c1208c6dca893f08f2c9255165328ee2668
library_src="${LIBRARY_SRC:-https://github.com/open-platform-model/library.git}"
work="${WORK:-$(mktemp -d)}"

git clone --quiet "$library_src" "$work/library"
git -C "$work/library" -c advice.detachedHead=false checkout --quiet "$library_sha"
cp -R "$here/overlay/." "$work/library/"

cd "$work/library"
# Test temp dirs go under the work directory too.
mkdir -p "$work/tmp"
export TMPDIR="$work/tmp"
# core 2.0.0-alpha.12 resolves from GHCR (public, anonymous); the fixtures are
# served in-process by the test itself.
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
go test ./opm/kernel -run '^TestExp07$' -count=1 -v 2>&1 | tee "$work/render.log"
echo "log: $work/render.log"
