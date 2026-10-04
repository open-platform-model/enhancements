#!/usr/bin/env bash
# flip.sh <namespace> <instance> [serviceAccountName] [prune]
# Reproduces the removed `opm instance handoff` flip (cli 7ae153f7^,
# internal/workflow/handoff/handoff.go + inventory.ApplySpec): ONE server-side
# apply with field manager opm-cli, force, restating the CR labels,
# spec.module and spec.values exactly as recorded, with spec.owner: operator.
# Optional args add spec.serviceAccountName / spec.prune to the same document
# (the redesigned handoff must fill these in; the old one never did).
set -euo pipefail
NS=$1; MI=$2; SA=${3:-}; PRUNE=${4:-}; K="kubectl --context ${CTX:-kind-opm-handoff-id}"
$K -n "$NS" get moduleinstance "$MI" -o json | jq --arg sa "$SA" --arg prune "$PRUNE" '{
  apiVersion, kind,
  metadata: {name: .metadata.name, namespace: .metadata.namespace,
    labels: (.metadata.labels | with_entries(select(.key == "app.kubernetes.io/managed-by" or (.key | startswith("module-instance.opmodel.dev/")))))},
  spec: ({module: .spec.module, values: .spec.values, owner: "operator"}
    + (if $sa != "" then {serviceAccountName: $sa} else {} end)
    + (if $prune != "" then {prune: ($prune == "true")} else {} end))
}' | $K apply --server-side --field-manager=opm-cli --force-conflicts -f - -o jsonpath='{.metadata.generation}{"\n"}'
