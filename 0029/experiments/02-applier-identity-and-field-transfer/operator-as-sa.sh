#!/usr/bin/env bash
# Run the opm-operator (beta.5, built from opm-operator f568db6) OUTSIDE the
# cluster, authenticated with a token of the in-cluster controller
# ServiceAccount, so every API call carries the stock install's identity
# (system:serviceaccount:opm-operator-system:opm-operator-controller-manager).
#
# Why: on this host (2026-10-04) docker containers have no egress, so the
# in-cluster operator cannot reach GHCR for core/catalogs and crash-loops in
# verifyCoreSchema. The host can. Identity, RBAC and impersonation are
# unchanged; only the process location differs.
#
# Usage: operator-as-sa.sh <manager-binary> <workdir> [extra operator args...]
set -euo pipefail
BIN=$1; WORK=$2; shift 2
CTX=kind-opm-handoff-id
NS=opm-operator-system
SA=opm-operator-controller-manager
mkdir -p "$WORK"
server=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CTX\")].cluster.server}")
kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CTX\")].cluster.certificate-authority-data}" | base64 -d > "$WORK/ca.crt"
token=$(kubectl --context $CTX -n $NS create token $SA --duration=12h)
KC="$WORK/kubeconfig"
kubectl config --kubeconfig "$KC" set-cluster c --server="$server" --certificate-authority="$WORK/ca.crt" >/dev/null
kubectl config --kubeconfig "$KC" set-credentials sa --token="$token" >/dev/null
kubectl config --kubeconfig "$KC" set-context sa --cluster=c --user=sa >/dev/null
kubectl config --kubeconfig "$KC" use-context sa >/dev/null
kubectl --kubeconfig "$KC" auth whoami -o jsonpath='{.status.userInfo.username}{"\n"}'
exec env KUBECONFIG="$KC" "$BIN" \
  --metrics-bind-address=0 --health-probe-bind-address=0 --leader-elect=false \
  --cue-cache-dir="$WORK/cue-cache" --platform-dir="$WORK/platform" \
  --registry='testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works' \
  "$@"
