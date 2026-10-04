#!/usr/bin/env bash
# Print what the operator did with a ModuleInstance: owner, annotation,
# conditions, digests, inventory, events, and the applied objects' data.
set -uo pipefail
name=$1 ns=${NS:-default} ctx=${CTX:-kind-opm-handoff-src}
k() { kubectl --context "$ctx" "$@"; }
k -n "$ns" get moduleinstance "$name" -o json | jq '{gen: .metadata.generation,
  owner: .spec.owner, module: .spec.module, values: .spec.values,
  annotations: .metadata.annotations,
  conditions: [.status.conditions[]? | {type, status, reason, message: (.message|.[0:300])}],
  observedGeneration: .status.observedGeneration,
  lastAppliedRenderDigest: .status.lastAppliedRenderDigest,
  lastAttemptedSourceDigest: .status.lastAttemptedSourceDigest,
  lastAppliedSourceDigest: .status.lastAppliedSourceDigest,
  inventoryRevision: .status.inventory.revision,
  inventory: [.status.inventory.entries[]? | "\(.kind)/\(.name)"]}'
echo "--- events"
k -n "$ns" get events --field-selector involvedObject.name="$name" -o json | jq -r '.items[] | "\(.type) \(.reason): \(.message|.[0:300])"' | tail -8
echo "--- configmaps (managed-by, data)"
k -n "$ns" get configmaps -l module-instance.opmodel.dev/name="$name" -o json | jq -c '.items[] | {name: .metadata.name, managedBy: .metadata.labels["app.kubernetes.io/managed-by"], data}'
