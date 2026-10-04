#!/usr/bin/env bash
# Today's install (embedded install.yaml, operator v1.0.0-beta.5, Platform
# seeded) on a fresh cluster. Environment fix: as soon as the Deployment
# exists, its args gain the mirror --registry (field manager exp-env-fix),
# because the stock operator cannot reach ghcr.io from this host's kind pods.
set -euo pipefail
source "$(dirname "$0")/env.sh"
REG='testing.opmodel.dev=opm-registry:5000+insecure,opmodel.dev=172.18.0.1:5055/open-platform-model+insecure,172.18.0.1:5056+insecure'
start=$(date +%s.%N)
"$OPM" operator install --context "$CTX" > "$EXP/out/old-install.log" 2>&1 &
pid=$!
until $K -n opm-operator-system get deploy opm-operator-controller-manager >/dev/null 2>&1; do sleep 0.5; done
$K -n opm-operator-system patch deploy opm-operator-controller-manager --field-manager=exp-env-fix --type=json \
  -p "[{\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--registry=$REG\"}]"
wait $pid; rc=$?
end=$(date +%s.%N)
printf 'TIMING old-install rc=%d total=%.1fs\n' "$rc" "$(echo "$end - $start" | bc)"
