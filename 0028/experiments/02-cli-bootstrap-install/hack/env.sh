# Sourced by every hack/ script. Override OPM / CTX from the environment.
S=${SCRATCH:?set SCRATCH to a scratch directory}
: "${OPM:=$S/exp-0028-02-opm}"
: "${CTX:=kind-opm-dogfood}"
export OPM_REGISTRY='testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
export CUE_REGISTRY="$OPM_REGISTRY"
EXP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K="kubectl --context $CTX"
export LC_ALL=C
