#!/usr/bin/env bash
# race.sh <opm-binary> - case 4: a CLI apply lands between the handoff's
# verification read and its flip.
#  1. snapshot the CR (what the gate chain verified): generation + spec
#  2. a concurrent `opm instance apply` changes spec.values (generation bumps)
#  3a. GUARDED flip: re-read, compare generation, refuse when it moved
#  3b. UNGUARDED flip (old code minus ensureUnchangedSinceVerification): SSA
#      the snapshot with owner: operator -> silently reverts step 2
set -uo pipefail
OPM=$1; E=$(cd "$(dirname "$0")" && pwd); K="kubectl --context kind-opm-handoff-id"; NS=c4; MI=multi
snap=$($K -n $NS get moduleinstance $MI -o json)
g0=$(echo "$snap" | jq .metadata.generation); echo "1. verified snapshot: generation=$g0 message=$(echo "$snap" | jq -c .spec.values.message)"
"$OPM" instance apply "$E/instance/c4/instance.cue" -n $NS -f "$E/values/c4-race.cue" --config "$E/opm-config.cue" 2>&1 | tail -1
cur=$($K -n $NS get moduleinstance $MI -o json); g1=$(echo "$cur" | jq .metadata.generation)
echo "2. concurrent CLI apply: generation=$g1 message=$(echo "$cur" | jq -c .spec.values.message) configmap=$($K -n $NS get cm multi-extra-extra -o jsonpath='{.data.message}')"
if [ "$g1" != "$g0" ]; then echo "3a. GUARD: generation moved $g0 -> $g1; a guarded handoff refuses here and leaves owner=cli"; fi
echo "3b. UNGUARDED flip from the stale snapshot:"
echo "$snap" | jq '{apiVersion, kind, metadata:{name:.metadata.name, namespace:.metadata.namespace, labels:.metadata.labels},
  spec:{module:.spec.module, values:.spec.values, owner:"operator", serviceAccountName:"applier", prune:true}}' |
  $K apply --server-side --field-manager=opm-cli --force-conflicts -f - -o jsonpath='   generation={.metadata.generation}{"\n"}'
timeout 90 bash -c "until [ \"\$($K -n $NS get moduleinstance $MI -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}')\" = True ]; do sleep 2; done"
echo "   after operator reconcile: spec message=$($K -n $NS get moduleinstance $MI -o jsonpath='{.spec.values.message}') configmap=$($K -n $NS get cm multi-extra-extra -o jsonpath='{.data.message}') revision=$($K -n $NS get moduleinstance $MI -o jsonpath='{.status.inventory.revision}')"
