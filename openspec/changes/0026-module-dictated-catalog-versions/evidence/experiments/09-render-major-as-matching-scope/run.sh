#!/usr/bin/env bash
# Enhancement 0026, experiment 09. Checks out library and core at pinned
# commits in a fresh work directory and:
#   1. applies library.patch (scoped matching in the render glue and the
#      inventory types) and shelves the one library test the type change
#      breaks (render_inventory_parity_test.go, which no longer compiles);
#   2. serves core in-process from the fixture registry: v2.0.0-alpha.12 is
#      core as shipped, v2.0.0-alpha.13 is core plus core.patch (the same
#      patch as experiment 05) without its _pins.cue files, which the
#      reshaped inventory breaks;
#   3. copies overlay/ (one test file plus fixtures) and runs the probe test.
# Nothing outside the work directory is written, and no registry is contacted
# for core.
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
git -C "$work/library" apply "$here/library.patch"
mv "$work/library/opm/kernel/render_inventory_parity_test.go" "$work/render_inventory_parity_test.go.shelved"

git clone --quiet "$core_src" "$work/core"
git -C "$work/core" -c advice.detachedHead=false checkout --quiet "$core_sha"
reg="$work/library/testdata/render/registry"
mkdir -p "$reg/opmodel.dev_core_v2.0.0-alpha.12" "$reg/opmodel.dev_core_v2.0.0-alpha.13"
cp -R "$work/core/src/." "$reg/opmodel.dev_core_v2.0.0-alpha.12/"
git -C "$work/core" apply "$here/core.patch"
cp -R "$work/core/src/." "$reg/opmodel.dev_core_v2.0.0-alpha.13/"
rm -f "$reg"/opmodel.dev_core_v2.0.0-alpha.13/*_pins.cue

cp -R "$here/overlay/." "$work/library/"

cd "$work/library"
# Test temp dirs go under the work directory too.
mkdir -p "$work/tmp"
export TMPDIR="$work/tmp"
go test ./opm/kernel -run '^TestExp09$' -count=1 -v 2>&1 | tee "$work/render.log"
echo "log: $work/render.log"
