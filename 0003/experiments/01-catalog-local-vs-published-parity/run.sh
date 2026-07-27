#!/usr/bin/env bash
# Experiment 01 driver — catalog local-vs-published FQN parity.
#
# Publishes two catalogs to the local dev registry under the throwaway
# namespace testing.opmodel.dev/exp0003/:
#
#   cat_a — METHOD A: dev sentinel in the committed tree, concrete version
#           stamped into a temp build dir at publish (enhancement 0001 D9/D19).
#   cat_b — METHOD B: concrete version committed; publish derives the tag
#           from it and stamps nothing (enhancement 0003 D4).
#
# Then evaluates each catalog TWICE — once from its local source checkout,
# once through a consumer module that resolves it from the registry — and
# prints both FQN sets side by side.
#
# Requires: cue >= v0.17, a registry at localhost:5000, and CUE_REGISTRY
# mapping testing.opmodel.dev to it.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${VERSION:-v1.0.0}"
BARE="${VERSION#v}"

export CUE_REGISTRY="${CUE_REGISTRY:-testing.opmodel.dev=localhost:5000+insecure,registry.cue.works}"

echo "=== preflight ==="
curl -sf --max-time 4 http://localhost:5000/v2/ >/dev/null || {
	echo "FAIL: no registry at localhost:5000" >&2
	exit 1
}
echo "registry OK; CUE_REGISTRY=$CUE_REGISTRY"

echo
echo "=== [1] LOCAL SOURCE EVALUATION (what a local checkout / local-module.cue replaceWith sees) ==="
echo "--- method A (committed tree, unstamped) ---"
( cd catalog_a && cue export . --out yaml )
echo "--- method B (committed tree) ---"
( cd catalog_b && cue export . --out yaml )

echo
echo "=== [2] PUBLISH ==="
echo "--- method A: stamp into temp build dir, then publish ---"
rm -rf .build/cat_a
mkdir -p .build
cp -r catalog_a .build/cat_a
cat > .build/cat_a/identity/version_override.cue <<EOF
package identity

Version: "${BARE}"
EOF
( cd .build/cat_a && cue mod publish "${VERSION}" )
echo "source tree vs published build dir:"
diff -r catalog_a .build/cat_a || true

echo "--- method B: publish the committed tree as-is ---"
( cd catalog_b && cue mod publish "${VERSION}" )

echo
echo "=== [3] REGISTRY RESOLUTION (what every downstream consumer sees) ==="
( cd consumer && cue mod tidy >/dev/null 2>&1 || true; cue export . -e fromRegistry --out yaml )

echo
echo "=== [4] VERDICT ==="
echo "Compare [1] against [3]. Parity holds for a method iff its local and"
echo "registry FQNs are byte-identical."
