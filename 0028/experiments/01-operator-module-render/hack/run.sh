#!/usr/bin/env bash
# Reproduce experiment 01 end to end, no cluster:
#   OPM=/path/to/opm hack/run.sh
# Needs: cue v0.17.x, python3 + PyYAML, /usr/bin/time, network to GHCR and
# registry.cue.works (and 127.0.0.1:5000 only for the published-module arm).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
OPM=${OPM:?set OPM to an opm binary built from cli main}
# No kubeconfig: proves the render never needs a cluster or a cluster Platform.
export KUBECONFIG=/nonexistent
export OPM_REGISTRY=${OPM_REGISTRY:-'testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'}
export CUE_REGISTRY=$OPM_REGISTRY
OUT=$HERE/out
mkdir -p "$OUT"

echo "== 1. generate + drift check"
"$HERE/hack/generate.sh"
"$HERE/hack/drift-check.sh"

echo "== 2. render (module build, generated platform from the module's deps)"
cd "$HERE/module"
/usr/bin/time -v "$OPM" module build . --name opm-operator -n opm-operator-system \
	>"$OUT/rendered.yaml" 2>"$OUT/render-stderr.txt"
grep -E 'platform:|Elapsed|Maximum resident' "$OUT/render-stderr.txt"

echo "== 3. compare with install.yaml"
python3 "$HERE/hack/compare.py" "$HERE/source/install.yaml" "$OUT/rendered.yaml" >"$OUT/compare.txt"
sed -n '1,12p' "$OUT/compare.txt"
grep -c '^  spec ' "$OUT/compare.txt" | sed 's/^/spec-level differences: /'

echo "== 4. every #config knob"
"$OPM" module build . --name opm-operator -n opm-operator-system -f "$HERE/values/knobs.cue" \
	>"$OUT/rendered-knobs.yaml" 2>/dev/null
grep -A12 '        - --metrics-bind-address' "$OUT/rendered-knobs.yaml" | head -8

if [ "${PUBLISHED:-0}" = 1 ]; then
	echo "== 5. render the published 0.1.0 from the local registry"
	"$OPM" module build testing.opmodel.dev/modules/experiments/opm-operator-render/opm_operator \
		--version 0.1.0 --name opm-operator -n opm-operator-system >"$OUT/rendered-published.yaml" 2>/dev/null
	norm() { python3 -c "import yaml,json,sys;print('\n'.join(sorted(json.dumps(d,sort_keys=True) for d in yaml.safe_load_all(open(sys.argv[1])) if d)))" "$1"; }
	diff <(norm "$OUT/rendered.yaml") <(norm "$OUT/rendered-published.yaml") >/dev/null &&
		echo "published render == local render"
fi
