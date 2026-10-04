#!/usr/bin/env bash
# capture.sh <phase-dir-name>: snapshot every OPM CR, events, rendered-object metadata and
# ownerReference chains from the throwaway opm-portal-probe cluster only.
set -euo pipefail
# KUBECONFIG_FILE: a kubeconfig for the throwaway cluster only; OUT_ROOT: where snapshots go.
KC=${KUBECONFIG_FILE:?set KUBECONFIG_FILE}
CTX=kind-opm-portal-probe
k() { kubectl --kubeconfig "$KC" --context "$CTX" "$@"; }
[ "$(k config current-context)" = "$CTX" ] || { echo "wrong context" >&2; exit 1; }
OUT=${OUT_ROOT:-./out}/$1
mkdir -p "$OUT"
date -u +%FT%TZ > "$OUT/captured-at.txt"

for r in moduleinstances modulepackages platforms transformerregistrations; do
  k get "$r.opmodel.dev" -A -o yaml > "$OUT/cr-$r.yaml"
done
k get crd -o name | grep opmodel.dev > "$OUT/crds.txt"

# events: new API (all namespaces, full objects) and the core v1 view
k get events.events.k8s.io -A -o yaml > "$OUT/events-v1-all.yaml"
k get events -A -o json > "$OUT/events-core-all.json"
k get events -A --sort-by=.lastTimestamp -o wide > "$OUT/events-core-all.txt"
# server-side regarding.* field selector check (events.k8s.io/v1)
k get events.events.k8s.io -A --field-selector regarding.kind=ModuleInstance -o yaml > "$OUT/events-v1-regarding-mi.yaml" 2> "$OUT/events-v1-regarding-mi.err" || true
k get events.events.k8s.io -n default --field-selector regarding.kind=ModuleInstance,regarding.name=podinfo -o yaml > "$OUT/events-v1-regarding-podinfo.yaml" 2> "$OUT/events-v1-regarding-podinfo.err" || true

# rendered objects: labels/annotations of everything carrying OPM labels
k get "$(k api-resources --verbs=list -o name | grep -v -x -e secrets -e events -e events.events.k8s.io | paste -sd, -)" -A -o json \
  > "$OUT/all-objects.json" 2> "$OUT/all-objects.err" || true

# workload ownership chains
for ns in default cert-manager; do
  k get deploy,statefulset,replicaset,pod -n "$ns" -o json > "$OUT/workloads-$ns.json"
done
k get pods -A -o wide > "$OUT/pods.txt"
echo done "$OUT"
