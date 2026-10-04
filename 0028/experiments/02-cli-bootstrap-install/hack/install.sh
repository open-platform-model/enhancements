#!/usr/bin/env bash
# Emulates the proposed module-based `opm operator install`:
#   1. render the instance (no cluster Platform needed),
#   2. SSA only the CRD subset with field manager opm-cli, wait Established,
#   3. opm instance apply the CLI-owned ModuleInstance of the module, --wait.
# Usage: hack/install.sh [instance-dir]   (default: instance/)
set -euo pipefail
source "$(dirname "$0")/env.sh"
INST="${1:-$EXP/instance}"
start=$(date +%s.%N)
"$OPM" instance build "$INST/instance.cue" --context "$CTX" > "$EXP/out/render.yaml"
yq 'select(.kind == "CustomResourceDefinition")' "$EXP/out/render.yaml" > "$EXP/out/crds.yaml"
$K apply --server-side --field-manager=opm-cli -f "$EXP/out/crds.yaml"
$K wait --for=condition=Established --timeout=60s -f "$EXP/out/crds.yaml"
t_crds=$(date +%s.%N)
"$OPM" instance apply "$INST/instance.cue" --context "$CTX" --wait --timeout 5m
end=$(date +%s.%N)
printf 'TIMING render+crds=%.1fs instance-apply=%.1fs total=%.1fs\n' \
  "$(echo "$t_crds - $start" | bc)" "$(echo "$end - $t_crds" | bc)" "$(echo "$end - $start" | bc)"
