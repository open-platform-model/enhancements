#!/usr/bin/env bash
# 06-module-file-card-roundtrip: per fleet module, values before tidy, tidy,
# values after, card vet, publish to a throwaway in-memory registry, and
# compare the published module-file blob with the tidied file.
# Prints one TSV row per module.
#
# Needs: WS pointing at a workspace checkout holding opm-modules/ and
# modules/; cue v0.17.1, go, python3, curl, jq on PATH; GHCR reachable for
# opmodel.dev/core and the opm catalog. Port 5191 must be free.
set -u
X=$(cd "$(dirname "$0")" && pwd)
: "${WS:?set WS to the workspace checkout holding opm-modules/ and modules/}"
export WS
REG=127.0.0.1:5191
export CUE_CACHE_DIR=$X/.work/cuecache
export CUE_REGISTRY="jacero.se=$REG+insecure,opmodel.dev/modules=$REG+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"
mkdir -p "$X/.work/orig"

(cd "$X/reg" && go build -o "$X/.work/reg" .)
"$X/.work/reg" $REG > "$X/.work/reg.log" 2>&1 &
REGPID=$!
trap 'kill $REGPID' EXIT
sleep 1

python3 "$X/make_fleet.py"

printf "name\tvalues_equal\tcomments_after\tcard_vet\tcard_json_B\tmodfile_B\tpublished_equals_tidied\n"
for d in "$X"/.work/fleet/*/; do
  n=$(basename "$d")
  O=$X/.work/orig/$n
  cd "$d"
  cue export --out json cue.mod/module.cue > "$O.before.json"
  cue mod tidy || { echo "$n TIDY-FAIL"; continue; }
  cue export --out json cue.mod/module.cue > "$O.after.json"
  eq=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))==json.load(open(sys.argv[2])))" "$O.before.json" "$O.after.json")
  com=$(grep -cE '(^|[[:space:]])//' cue.mod/module.cue)
  jq '.custom["opmodel.dev@v0"]' "$O.after.json" > "$O.block.json"
  vet=$(cd "$X/schema" && cue vet -c -d '#ModuleFileCustom' ./open/ "$O.block.json" 2>&1 | head -2 | tr '\n' ' ')
  [ -z "$vet" ] && vet=PASS
  cj=$(jq -c '.listing' "$O.block.json" | tr -d '\n' | wc -c)
  mb=$(wc -c < cue.mod/module.cue)
  v=$(grep '^Version:' identity/identity.cue | cut -d'"' -f2)
  repo=$(grep '^module:' cue.mod/module.cue | cut -d'"' -f2 | sed 's/@v[0-9]*$//')
  cue mod publish "v$v" >/dev/null || echo "$n PUBLISH-FAIL"
  # A CUE module manifest's second layer is the module file itself.
  dg=$(curl -fsS -H 'Accept: application/vnd.oci.image.manifest.v1+json' \
    "http://$REG/v2/$repo/manifests/v$v" | jq -r '.layers[1].digest')
  curl -fsS "http://$REG/v2/$repo/blobs/$dg" > "$O.published.cue"
  same=$(cmp -s "$O.published.cue" cue.mod/module.cue && echo true || echo false)
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$n" "$eq" "$com" "$vet" "$cj" "$mb" "$same"
done
