#!/usr/bin/env bash
# capture.sh <namespace> <instance> <out-prefix>
# Writes <out-prefix>-cr.yaml (CR with managedFields) and <out-prefix>-objects.txt:
# one line per status.inventory entry with uid, resourceVersion, managed-by
# label, uuid label, and each managedFields manager/operation.
set -uo pipefail
NS=$1; MI=$2; OUT=$3; K="kubectl --context ${CTX:-kind-opm-handoff-id}"
$K -n "$NS" get moduleinstance "$MI" -o yaml --show-managed-fields > "$OUT-cr.yaml"
$K -n "$NS" get moduleinstance "$MI" -o json | jq -c '.status.inventory.entries[]' | while read -r e; do
  g=$(echo "$e" | jq -r '.group // ""'); kind=$(echo "$e" | jq -r .kind); n=$(echo "$e" | jq -r .name); ens=$(echo "$e" | jq -r '.namespace // ""')
  res=$($K api-resources --api-group="$g" --no-headers 2>/dev/null | awk -v k="$kind" '$NF==k {print $1}' | head -1)
  rg=$res; [ -n "$g" ] && rg="$res.$g"
  $K ${ens:+-n $ens} get "$rg" "$n" -o json --show-managed-fields 2>/dev/null | jq -r --arg k "$kind" '
    "\($k) \(.metadata.namespace // "-")/\(.metadata.name) uid=\(.metadata.uid) rv=\(.metadata.resourceVersion) managed-by=\(.metadata.labels["app.kubernetes.io/managed-by"]) uuid=\(.metadata.labels["module-instance.opmodel.dev/uuid"]) managers=[\([.metadata.managedFields[] | "\(.manager)/\(.operation)\(if .subresource then "/"+.subresource else "" end)"] | join(","))]"' \
    || echo "$kind ${ens:-}/$n MISSING"
done | sort > "$OUT-objects.txt"
cat "$OUT-objects.txt"
