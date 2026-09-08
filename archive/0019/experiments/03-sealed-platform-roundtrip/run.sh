#!/usr/bin/env bash
# 0019 experiment 03 - can an evaluated platform be SEALED into self-contained
# CUE that no longer depends on the catalog module, while preserving the field
# classes a transformer needs (definitions, hidden fields, closedness) and
# rendering identically?
#
# Sealing is the alternative to re-evaluating the catalog on every render. It is
# what would let a platform be materialized once per Platform generation and
# reused across many instances, the way opm-operator's platform store works
# today (ADR-002), while still rendering in a single build.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-$HERE/_out}"
export CUE_REGISTRY="${CUE_REGISTRY:-opmodel.dev=ghcr.io/open-platform-model,registry.cue.works}"

TFPATH='#registry["opmodel.dev/catalogs/opm@v2"].#transformers'
DEPLOY='opmodel.dev/catalogs/opm/transformers/deployment-transformer@2.0.0-alpha.3'

rm -rf "$OUT"; mkdir -p "$OUT/sealed/cue.mod"
cp -r "$HERE/platform" "$OUT/"
chmod -R u+w "$OUT"

echo "== step 1: seal =="
( cd "$OUT/platform" && cue def --inline-imports -e "$TFPATH" . ) > "$OUT/sealed-raw.cue" 2>"$OUT/seal.err"
if [ ! -s "$OUT/sealed-raw.cue" ]; then echo "   SEAL FAILED:"; head -5 "$OUT/seal.err"; exit 1; fi
printf '   emitted %s lines\n' "$(wc -l < "$OUT/sealed-raw.cue")"

echo
echo "== step 2: is it self-contained? =="
echo "   imports surviving --inline-imports:"
sed -n '/^import (/,/^)/p' "$OUT/sealed-raw.cue" | grep -o '"[^"]*"' | tr -d '"' | while read -r imp; do
  case "$imp" in
    */*.*/*|opmodel.dev/*|cue.dev/*|github.com/*) echo "      NON-STDLIB  $imp" ;;
    *) echo "      stdlib      $imp" ;;
  esac
done

echo
echo "== step 3: does a module WITHOUT the catalog dependency load it? =="
cat > "$OUT/sealed/cue.mod/module.cue" <<'EOF'
// Deliberately omits opmodel.dev/catalogs/opm. A sealed platform that still
// needs the catalog on the module graph has not been sealed.
module: "experiments.opmodel.dev/0019/sealed@v0"
language: {
	version: "v0.17.0"
}
deps: {
	"opmodel.dev/core@v2": {
		v: "v2.0.0-alpha.4"
	}
}
EOF
{ echo "package sealed"; echo; cat "$OUT/sealed-raw.cue"; } > "$OUT/sealed/sealed.cue"
if ( cd "$OUT/sealed" && cue vet . ) >"$OUT/sealed-unrepaired.err" 2>&1; then
  echo "   PARSES AS EMITTED: yes"
else
  echo "   PARSES AS EMITTED: no"
  sed -n 1,4p "$OUT/sealed-unrepaired.err" | sed 's/^/      /'
  printf '   repairing printer output: '
  python3 "$HERE/repair.py" "$OUT/sealed/sealed.cue"
fi
if ( cd "$OUT/sealed" && cue vet . ) >"$OUT/sealed.err" 2>&1; then
  echo "   LOADS: yes"
else
  echo "   LOADS: no"
  sed -n 1,6p "$OUT/sealed.err" | sed 's/^/      /'
fi

echo
echo "== step 4: field classes preserved in the emitted source =="
printf '   %-24s %s\n' "#transform blocks:"  "$(grep -c '#transform:' "$OUT/sealed-raw.cue")"
printf '   %-24s %s\n' "hidden fields:"      "$(grep -cE '^[[:space:]]*_[A-Za-z]' "$OUT/sealed-raw.cue")"
printf '   %-24s %s\n' "close() calls:"      "$(grep -c 'close(' "$OUT/sealed-raw.cue")"
printf '   %-24s %s\n' "definition fields:"  "$(grep -cE '^[[:space:]]*#[A-Za-z]' "$OUT/sealed-raw.cue")"

echo
echo "== step 5: does the sealed transformer render what the imported one renders? =="
mkdir -p "$OUT/compare/cue.mod"
cat > "$OUT/compare/cue.mod/module.cue" <<'EOF'
// Keeps the catalog dependency ON PURPOSE. Step 3 asks whether the seal is
// self-contained; this step asks the independent question of whether the round
// trip preserved SEMANTICS, and answering it needs both sides in one build.
module: "experiments.opmodel.dev/0019/compare@v0"
language: {
	version: "v0.17.0"
}
deps: {
	"cue.dev/x/k8s.io@v0": {
		v:       "v0.7.0"
		default: true
	}
	"opmodel.dev/core@v2": {
		v: "v2.0.0-alpha.4"
	}
	"opmodel.dev/catalogs/opm@v2": {
		v: "v2.0.0-alpha.3"
	}
}
EOF
{ echo "package compare"; echo; sed 's/^_#def$/sealedMap:/; s/^_#def: {/sealedMap: {/' "$OUT/sealed-raw.cue"; } > "$OUT/compare/sealed.cue"
python3 "$HERE/repair.py" "$OUT/compare/sealed.cue" >/dev/null
cat > "$OUT/compare/compare.cue" <<EOF
package compare

import catalog "opmodel.dev/catalogs/opm@v2"

_fqn: "$DEPLOY"

// The same transformer reached two ways.
imported: catalog.#transformers[_fqn]
sealed:   sealedMap[_fqn]

// Structural agreement on the two things a renderer actually consumes.
sameRequiredResources: imported.requiredResources == sealed.requiredResources
sameTransformKeys: [for k, _ in imported.#transform {k}] == [for k, _ in sealed.#transform {k}]
EOF
if ( cd "$OUT/compare" && cue eval -e sameRequiredResources -e sameTransformKeys . ) >"$OUT/compare.out" 2>&1; then
  sed 's/^/   /' "$OUT/compare.out"
else
  echo "   COMPARE FAILED:"; sed -n 1,8p "$OUT/compare.out" | sed 's/^/      /'
fi

echo
echo "Artifacts under $OUT/"
