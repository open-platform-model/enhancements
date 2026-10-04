#!/usr/bin/env bash
# edit-values.sh <namespace> <instance> <jq-expression-on-values>
# Spec edit of an operator-owned instance the way the CLI's thin editor writes
# it: one SSA as opm-cli restating every field opm-cli owns (labels, module,
# owner, serviceAccountName, prune) with the edited values.
set -euo pipefail
NS=$1; MI=$2; EXPR=$3; K="kubectl --context ${CTX:-kind-opm-handoff-id}"
$K -n "$NS" get moduleinstance "$MI" -o json | jq "{apiVersion, kind,
  metadata: {name: .metadata.name, namespace: .metadata.namespace,
    labels: (.metadata.labels | with_entries(select(.key == \"app.kubernetes.io/managed-by\" or (.key | startswith(\"module-instance.opmodel.dev/\")))))},
  spec: (.spec | {module, owner, values, serviceAccountName, prune} | with_entries(select(.value != null)) | .values |= ($EXPR))
}" | $K apply --server-side --field-manager=opm-cli --force-conflicts -f - -o jsonpath='{.metadata.generation}{"\n"}'
