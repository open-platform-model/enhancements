#!/usr/bin/env bash
# Experiment 04 driver — does a local-module.cue replacement chain survive
# more than one hop?
#
# Chain: inst -> mod -> cat. Both mod and cat are published to the local dev
# registry carrying Origin: "REGISTRY"; local checkouts of both carry
# Origin: "LOCAL-CHECKOUT". `mod` re-exports the Origin of whichever `cat` it
# resolved against, so the instance can report the INNER hop from outside.
#
# local/mod carries its OWN cue.mod/local-module.cue replacing cat with
# local/cat. CUE honours local-module.cue only for the MAIN module, so that
# inner file is expected to be ignored when local/mod is reached as a
# replaced dependency.
set -euo pipefail
cd "$(dirname "$0")"

NS="testing.opmodel.dev/exp0003h"
export CUE_REGISTRY="${CUE_REGISTRY:-testing.opmodel.dev=localhost:5000+insecure,registry.cue.works}"

echo "=== preflight ==="
curl -sf --max-time 4 http://localhost:5000/v2/ >/dev/null || {
	echo "FAIL: no registry at localhost:5000" >&2
	exit 1
}

echo
echo "=== [1] publish the registry side of the chain ==="
( cd registry/cat && cue mod publish v1.0.0 )
( cd registry/mod && cue mod publish v0.1.0 )

echo
echo "=== [2] resolve each case ==="
for c in case1_baseline case2_one_hop case3_two_entry case4_two_entry_no_dep; do
	echo "--- $c ---"
	if [ -f "$c/cue.mod/local-module.cue" ]; then
		echo "    local-module.cue:"
		sed 's/^/      /' "$c/cue.mod/local-module.cue"
	else
		echo "    (no local-module.cue)"
	fi
	( cd "$c" && cue export . --out yaml 2>&1 | sed 's/^/    /' ) || true
	echo
done

echo "=== [3] does 'cue mod tidy' preserve a two-entry local-module.cue? ==="
cp case3_two_entry/cue.mod/module.cue /tmp/exp04-module-before.cue
cp case3_two_entry/cue.mod/local-module.cue /tmp/exp04-local-before.cue
( cd case3_two_entry && cue mod tidy 2>&1 | sed 's/^/    /' ) || true
echo "--- module.cue diff (before -> after) ---"
diff /tmp/exp04-module-before.cue case3_two_entry/cue.mod/module.cue && echo "    (unchanged)"
echo "--- local-module.cue diff (before -> after) ---"
diff /tmp/exp04-local-before.cue case3_two_entry/cue.mod/local-module.cue && echo "    (unchanged)"

echo
echo "=== [4] re-resolve case3 after tidy ==="
( cd case3_two_entry && cue export . --out yaml 2>&1 | sed 's/^/    /' ) || true
