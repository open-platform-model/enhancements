#!/usr/bin/env bash
# Render the exact-objects variant (variants/exact_objects.cue) and compare it
# with install.yaml. Works on a throwaway copy of module/.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
OPM=${OPM:?set OPM}
export KUBECONFIG=/nonexistent
export OPM_REGISTRY=${OPM_REGISTRY:-'testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$HERE/module/." "$tmp/"
python3 - "$tmp/components.cue" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
for comp in ('"controller-manager"', '"manager-rbac"', '"metrics-auth-rbac"', '"leader-election"'):
    start = s.index("\t" + comp + ": {")
    # cut back to the comment block above the component
    head = s.rfind("\n\n", 0, start) + 2
    end = s.index("\n\t}\n", start) + 4
    s = s[:head] + s[end:]
# imports and the let only the removed components used
s = s.replace('\tbp "opmodel.dev/catalogs/opm/blueprints/v1beta1"\n', '')
s = s.replace('\ttr "opmodel.dev/catalogs/opm/traits/v1beta1"\n', '')
s = re.sub(r'\n// The controller.s ServiceAccount.*\nlet SA = .*\n', '\n', s)
open(p, "w").write(s)
PY
cp "$HERE/variants/exact_objects.cue" "$tmp/"
cd "$tmp"
"$OPM" module build . --name opm-operator -n opm-operator-system >"$HERE/out/rendered-variant.yaml" 2>"$tmp/err" || { cat "$tmp/err"; exit 1; }
python3 "$HERE/hack/compare.py" "$HERE/source/install.yaml" "$HERE/out/rendered-variant.yaml" >"$HERE/out/compare-variant.txt"
sed -n '4,12p' "$HERE/out/compare-variant.txt"
grep '^  spec ' "$HERE/out/compare-variant.txt" || echo "no spec-level differences"
