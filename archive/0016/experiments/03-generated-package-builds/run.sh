#!/usr/bin/env bash
# Experiment 03: does the hand-written package tidy, load, and build?
# OPM: path to an opm binary built from cli (default: opm on PATH).
# PLATFORM: a platform file whose catalogs/opm subscription implements the
# module's contracts (the build half needs one; the package does not).
set -u
cd "$(dirname "$0")/pkg"
OPM=${OPM:-opm}
cp cue.mod/module.cue /tmp/e03-before.cue
echo "== cue mod tidy"; cue mod tidy 2>&1; echo "exit=$?"
echo "== tidy diff"; diff /tmp/e03-before.cue cue.mod/module.cue
echo "== pure CUE: cue vet"; cue vet ./... 2>&1 | head -5; echo "exit=${PIPESTATUS[0]}"
echo "== pure CUE: components fanned from the module"; cue eval . -e 'len(components)' 2>&1
echo "== offline (CUE_REGISTRY unset, warm cache): cue vet"; env -u CUE_REGISTRY cue vet ./... 2>&1 | head -3; echo "exit=${PIPESTATUS[0]}"
echo "== opm instance build (kinds), platform=${PLATFORM:-default}"
$OPM instance build ./instance.cue ${PLATFORM:+--platform "$PLATFORM"} 2>/tmp/e03-build.err | grep -E "^kind:" | sort | uniq -c; echo "exit=${PIPESTATUS[0]}"
grep -E "ERRO|unresolved" /tmp/e03-build.err | head -3
echo "== any instance.local lookup attempted?"; grep -c "instance.local" /tmp/e03-build.err || true
