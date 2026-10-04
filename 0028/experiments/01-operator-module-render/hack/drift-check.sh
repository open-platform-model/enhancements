#!/usr/bin/env bash
# Fail when module/zz_generated_*.cue no longer matches the YAML it was
# generated from. The CI shape for opm-operator: run after `make manifests`,
# against config/ (SRC=<repo>/config CRD_SUBDIR=crd/bases).
#
#   hack/drift-check.sh                                   # against source/
#   SRC=$OPERATOR/config CRD_SUBDIR=crd/bases hack/drift-check.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
OUT=$tmp "$HERE/hack/generate.sh" >/dev/null
rc=0
for f in zz_generated_crds.cue zz_generated_rbac.cue; do
	# The header names the source dir; compare the bodies only.
	if ! diff -u <(sed 1,4d "$HERE/module/$f") <(sed 1,4d "$tmp/$f") >"$tmp/$f.diff"; then
		echo "DRIFT: module/$f is stale against ${SRC:-source/}"
		head -40 "$tmp/$f.diff"
		rc=1
	fi
done
[ $rc -eq 0 ] && echo "no drift: module/zz_generated_*.cue match ${SRC:-source/}"
exit $rc
