#!/usr/bin/env bash
# Experiment 05 verdict table: one row per claim readout.
# Run from the experiment directory: bash run.sh
set -u
cd "$(dirname "$0")"

export CUE_REGISTRY="${CUE_REGISTRY:-opmodel.dev=ghcr.io/open-platform-model,registry.cue.works}"

pass=0
fail=0
row() { # row <expected> <observed> <label>
	local want="$1" got="$2" label="$3"
	if [ "$want" = "$got" ]; then
		printf 'PASS  %-58s %s\n' "$label" "$got"
		pass=$((pass + 1))
	else
		printf 'FAIL  %-58s want=%s got=%s\n' "$label" "$want" "$got"
		fail=$((fail + 1))
	fi
}

echo "== claim 1: same pairs as the kernel (expected/pairs.json) =="
cue_pairs=$(cue export ./healthy/ -e '{p: pairs}' --out json 2>/dev/null |
	python3 -c 'import json,sys; print(sorted((x["component"],x["transformer"]) for x in json.load(sys.stdin)["p"]))')
kernel_pairs=$(python3 -c 'import json; print(sorted((x["component"],x["transformer"]) for x in json.load(open("expected/pairs.json"))["pairs"]))')
row "$kernel_pairs" "$cue_pairs" "healthy: CUE pairs == vendored kernel pairs"

echo "== claim 2: D30 carve-out unnecessary in one build =="
row "true" "$(cue eval ./healthy/ -e provenanceCatalogVersionEqual 2>&1)" "healthy: provenance catalogVersion identical both sides"
row "true" "$(cue eval ./healthy/ -e provenanceDescriptionEqual 2>&1)" "healthy: provenance description identical both sides"
row "0" "$(cue eval ./healthy/ -e disqualifiedCount 2>&1)" "healthy: plain-& disqualifies nothing"
row "1" "$(cue export ./broken/conflict/ -e '{n: len(match.unifyFailures)}' --out json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"])')" "conflict: genuine body conflict still disqualifies (as data)"
row "1" "$(cue export ./broken/conflict/ -e '{n: len(diagnostics.pairs)}' --out json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"])')" "conflict: unnarrowed candidate still pairs beside it"
row "true" "$(cue eval ./broken/conflict/ -e resolved 2>&1)" "conflict: demand satisfied through surviving candidate"

echo "== claim 3: fail-closed survives, evidence as data =="
row "false" "$(cue eval ./broken/missing/ -e resolved 2>&1)" "missing: resolved verdict is false (data)"
row "1" "$(cue export ./broken/missing/ -e '{n: len(diagnostics.unresolved)}' --out json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"])')" "missing: unresolved names the demand (data)"
row "1" "$(cue export ./broken/missing/ -e '{n: len(diagnostics.pairs)}' --out json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"])')" "missing: healthy sibling demand still paired"
gate_vet=$(cue vet ./broken/missing/gate/ 2>&1 | head -1)
row "resolvedGate: conflicting values false and true:" "$gate_vet" "missing: in-build gate refuses the render"
unstated_vetc=$(cue vet -c ./broken/unstated/ 2>&1 | grep -cE "incomplete bool|not concrete")
row "2" "$unstated_vetc" "unstated: posture refusal arrives as incomplete-value errors"
row "1" "$(cue export ./broken/unstated/ -e '{n: len(diagnostics.pairs)}' --out json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"])')" "unstated: pairs stay readable beside the stall"

echo "== claim 4: failure isolation =="
row "1" "$(cue export ./broken/pair/ -e '{n: len(failedPairs)}' --out json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"])')" "pair: error-style failure named as data"
row "6" "$(cue export ./broken/pair/ -e '{n: len(renderedKeys)}' --out json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["n"])')" "pair: 5 healthy pairs + 1 incomplete land in rendered"
incomplete_path=$(cue vet -c ./broken/pair/ 2>&1 | grep -c 'rendered."config :: .*incomplete-pair-transformer')
row "1" "$incomplete_path" "pair: incomplete-style failure caught by vet -c, names the pair key"
row "0" "$(cue eval ./healthy/ -e failedCount 2>&1)" "healthy: no failed pairs"

echo "== whole-module hygiene =="
row "" "$(cue vet -c ./healthy/ 2>&1)" "healthy: cue vet -c exits clean"

echo
echo "== Go API coexistence probe (claim 3 residue) =="
(cd capture && go run . probe)

echo
echo "$pass passed, $fail failed"
exit "$fail"
