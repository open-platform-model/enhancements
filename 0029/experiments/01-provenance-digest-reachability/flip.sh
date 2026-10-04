#!/usr/bin/env bash
# Flip a CLI-owned ModuleInstance to owner: operator, two ways.
#   flip.sh ssa  NAME   -- emulates the removed handoff's flip (cli 7ae153f7^
#                          handoff.go: inventory.ApplySpec with Owner=operator,
#                          SourceLocal=false): a server-side apply as field
#                          manager opm-cli, force, restating spec.module,
#                          spec.values and the CR labels, NO annotations (so
#                          SSA drops a source: local annotation opm-cli owned).
#   flip.sh edit NAME   -- what `kubectl edit` does: a merge patch of
#                          spec.owner only, from another field manager; the
#                          provenance annotation stays.
set -euo pipefail
mode=$1 name=$2 ns=${NS:-default} ctx=${CTX:-kind-opm-handoff-src}
k() { kubectl --context "$ctx" "$@"; }
case $mode in
ssa)
  cr=$(k -n "$ns" get moduleinstance "$name" -o json)
  doc=$(jq '{apiVersion, kind,
    metadata: {name: .metadata.name, namespace: .metadata.namespace,
               labels: {"app.kubernetes.io/managed-by": "opm-cli",
                        "module-instance.opmodel.dev/name": .metadata.name,
                        "module-instance.opmodel.dev/namespace": .metadata.namespace}},
    spec: ({module: .spec.module, owner: "operator"} + (if .spec.values then {values: .spec.values} else {} end))}' <<<"$cr")
  echo "$doc" | k apply --server-side --field-manager=opm-cli --force-conflicts -f -
  ;;
edit)
  k -n "$ns" patch moduleinstance "$name" --type=merge -p '{"spec":{"owner":"operator"}}' --field-manager=kubectl-edit
  ;;
*) echo "mode: ssa|edit" >&2; exit 2 ;;
esac
