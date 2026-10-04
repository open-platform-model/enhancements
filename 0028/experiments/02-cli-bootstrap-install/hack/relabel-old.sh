#!/usr/bin/env bash
# Migration probe helper: emulate an "adopt" step by relabelling every object
# of today's install.yaml as managed-by opm-cli (field manager exp-migrate).
set -euo pipefail
source "$(dirname "$0")/env.sh"
$K label --overwrite --field-manager=exp-migrate \
  ns/opm-operator-system \
  crd/moduleinstances.opmodel.dev crd/modulepackages.opmodel.dev crd/platforms.opmodel.dev crd/transformerregistrations.opmodel.dev \
  clusterrole/opm-operator-manager-role clusterrole/opm-operator-metrics-auth-role clusterrole/opm-operator-metrics-reader \
  clusterrole/opm-operator-moduleinstance-admin-role clusterrole/opm-operator-moduleinstance-editor-role \
  clusterrole/opm-operator-moduleinstance-viewer-role clusterrole/opm-operator-transformerregistration-admin-role \
  clusterrolebinding/opm-operator-manager-rolebinding clusterrolebinding/opm-operator-metrics-auth-rolebinding app.kubernetes.io/managed-by=opm-cli
$K -n opm-operator-system label --overwrite --field-manager=exp-migrate \
  sa/opm-operator-controller-manager role/opm-operator-leader-election-role \
  rolebinding/opm-operator-leader-election-rolebinding \
  svc/opm-operator-controller-manager-metrics-service deploy/opm-operator-controller-manager app.kubernetes.io/managed-by=opm-cli
