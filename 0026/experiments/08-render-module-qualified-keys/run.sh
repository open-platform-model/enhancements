#!/usr/bin/env bash
# Enhancement 0026, experiment 08. Checks out library and core at pinned
# commits in a fresh work directory, applies core.patch to the core copy
# (module-qualified contract keys, the same patch as experiment 03), copies
# overlay/ over the library checkout (one test file plus fixtures, no library
# file changed) and runs the probe test. Nothing outside the work directory is
# written.
#
#   LIBRARY_SRC  where to clone library from (default: GitHub)
#   CORE_SRC     where to clone core from (default: GitHub)
#   WORK         work directory (default: a new mktemp -d)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
library_sha=30f08c1208c6dca893f08f2c9255165328ee2668
core_sha=cbe93e0aa003b8cd5bbc34420f021ec62694c079
library_src="${LIBRARY_SRC:-https://github.com/open-platform-model/library.git}"
core_src="${CORE_SRC:-https://github.com/open-platform-model/core.git}"
work="${WORK:-$(mktemp -d)}"

git clone --quiet "$library_src" "$work/library"
git -C "$work/library" -c advice.detachedHead=false checkout --quiet "$library_sha"
git clone --quiet "$core_src" "$work/core"
git -C "$work/core" -c advice.detachedHead=false checkout --quiet "$core_sha"
git -C "$work/core" apply "$here/core.patch"
cp -R "$here/overlay/." "$work/library/"

cd "$work/library"
# Test temp dirs go under the work directory too.
mkdir -p "$work/tmp"
export TMPDIR="$work/tmp"
# The stock-core case resolves core 2.0.0-alpha.12 from GHCR; the patched-core
# cases serve $LINEAGE_CORE in-process under the same version.
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
export LINEAGE_CORE="$work/core/src"
go test ./opm/kernel -run '^TestExp08$' -count=1 -v 2>&1 | tee "$work/render.log"
echo "log: $work/render.log"
