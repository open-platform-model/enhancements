#!/usr/bin/env bash
# Runs the publish planner against every variant. Nothing is pushed; nothing
# outside this directory is read or written.
set -uo pipefail
cd "$(dirname "$0")"

hdr() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

run() {
  local title="$1"; shift
  hdr "$title"
  echo "  \$ opm publish $*"
  go run . "$@"
}

run "CLEAN CATALOG. Coordinates derived from the artifact; the tag is its own Version." \
  --kind=catalog variants/ok-catalog

run "UNFILLED. The gate CUE does not supply (D4)." \
  --kind=catalog variants/unfilled-catalog

run "UNFILLED + --version. The flag fills an open field (D3)." \
  --kind=catalog --version=1.2.0 variants/unfilled-catalog

run "--version AGAINST A CONCRETE FIELD, disagreeing. Publish asserts; it does not overwrite." \
  --kind=catalog --version=9.9.9 variants/ok-catalog

run "--version AGAINST A CONCRETE FIELD, agreeing." \
  --kind=catalog --version=1.2.0 variants/ok-catalog

run "CUE.MOD SKEW. The artifact's identity and its module: line disagree." \
  --kind=catalog variants/skew-catalog

run "CATALOG WITH A LOCAL OVERRIDE. No flag exists that makes this publishable (D6)." \
  --kind=catalog variants/override-catalog

run "…and passing the flag anyway changes nothing." \
  --kind=catalog --allow-local-override variants/override-catalog

run "MODULE WITH A LOCAL OVERRIDE. Refused, with an escape hatch offered." \
  --kind=module --version=2.1.0 variants/override-module

run "…and the escape hatch works, because a module's divergence is scoped to one artifact." \
  --kind=module --version=2.1.0 --allow-local-override variants/override-module

run "MODULE WITHOUT --version. A module declares no version in source (0010 D2)." \
  --kind=module variants/ok-module

run "MODULE, TAG MAJOR SKEW. v9.1.0 against a @v2 path." \
  --kind=module --version=9.1.0 variants/ok-module

run "MODULE, CLEAN." \
  --kind=module --version=2.1.0 variants/ok-module

hdr "What CUE itself does with the unfilled tree — the measurements the gates exist for"
cd variants/unfilled-catalog
for cmd in "cue vet ./..." "cue vet -c ./..." "cue mod publish v1.2.0 --dry-run"; do
  out=$($cmd 2>&1); rc=$?
  printf '  $ %s\n' "$cmd"
  printf '%s\n' "$out" | head -3 | sed 's/^/      /'
  printf '      exit %d\n\n' "$rc"
done
