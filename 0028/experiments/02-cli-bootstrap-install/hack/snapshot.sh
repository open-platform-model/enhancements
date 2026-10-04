#!/usr/bin/env bash
# Prints kind/ns/name uid resourceVersion generation managers for the
# operator instance's inventory plus the ModuleInstance CR itself.
# Usage: hack/snapshot.sh [instance-name] [namespace]
set -euo pipefail
source "$(dirname "$0")/env.sh"
NAME="${1:-opm-operator}"; NS="${2:-opm-operator-system}"
$K -n "$NS" get mi "$NAME" -o json --show-managed-fields \
 | jq -r '.status.inventory.entries[] | [(if .group then .kind+"."+.group else .kind end), (.namespace // ""), .name] | join("|")' \
 | while IFS="|" read -r kind ns name; do
     if [ -n "$ns" ]; then obj=$($K -n "$ns" get "$kind" "$name" -o json --show-managed-fields 2>/dev/null || echo '{}');
     else obj=$($K get "$kind" "$name" -o json --show-managed-fields 2>/dev/null || echo '{}'); fi
     echo "$obj" | jq -r --arg k "$kind" --arg ns "$ns" --arg n "$name" \
       '[$k, $ns, $n, (.metadata.uid // "MISSING"), (.metadata.resourceVersion // "-"), (.metadata.generation // "-"), ([.metadata.managedFields[]?.manager] | unique | join(","))] | @tsv'
   done
$K -n "$NS" get mi "$NAME" -o json --show-managed-fields | jq -r '["ModuleInstance", .metadata.namespace, .metadata.name, .metadata.uid, .metadata.resourceVersion, .metadata.generation, ([.metadata.managedFields[]?.manager]|unique|join(","))] | @tsv'
