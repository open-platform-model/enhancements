#!/usr/bin/env bash
# 0019 experiment 02 - does the PLATFORM or the consumer MODULE decide which
# catalog build a single render build resolves?
#
# The platform module is held at 2.0.0-alpha.3 in every case. The consumer
# module's pin is varied against it, under three modes for the kernel-generated
# render module:
#
#   pinned     render cue.mod lists the catalog at the platform's version
#   unpinned   render cue.mod does not list the catalog at all
#   replaced   pinned, plus a local-module.cue directory replacement onto the
#              platform's extracted catalog build
#
# Nothing in this directory is mutated: every case is assembled in a scratch
# copy under ${OUT:-./_out}.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT:-$HERE/_out}"
CACHE="${CUE_CACHE_DIR:-$HOME/.cache/cue}"

export CUE_REGISTRY="${CUE_REGISTRY:-opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works}"

PLATFORM_PIN="v2.0.0-alpha.3"   # what the platform's own cue.mod DECLARES; constant.
                                # Authoritative only for the main module; as a dependency
                                # it is a minimum the module graph can raise.
CORE_PIN="v2.0.0-alpha.4"

CONSUMER_PINS=(v2.0.0-alpha.3 v2.0.0-alpha.4 v2.0.0-alpha.2)
MODES=(pinned unpinned replaced)

extract_dir() { echo "$CACHE/mod/extract/$1@$2"; }

prime() {
  echo "== priming module cache =="
  local t; t="$(mktemp -d)"
  ( cd "$t" && cue mod init "example.com/prime@v0" >/dev/null 2>&1
    for v in "${CONSUMER_PINS[@]}" "$PLATFORM_PIN"; do
      cue mod get "opmodel.dev/catalogs/opm@${v#v}" >/dev/null 2>&1
    done )
  rm -rf "$t"
  for v in "${CONSUMER_PINS[@]}" "$PLATFORM_PIN"; do
    [ -d "$(extract_dir opmodel.dev/catalogs/opm "$v")" ] || echo "   WARN: no cache entry for catalogs/opm@$v"
  done
}

run_case() { # $1 = consumer pin, $2 = mode
  local cpin="$1" mode="$2"
  local dir="$OUT/${cpin#v}-$mode"
  rm -rf "$dir"; mkdir -p "$dir"
  cp -r "$HERE/render" "$HERE/consumer" "$HERE/platform" "$dir/"
  chmod -R u+w "$dir"
  rm -f "$dir/render/cue.mod/local-module.cue"

  # Vary ONLY the consumer's catalog pin.
  ( cd "$dir/consumer" && cue mod edit --require="opmodel.dev/catalogs/opm@${cpin}" ) || return

  # Shape the render module per mode.
  if [ "$mode" = unpinned ]; then
    ( cd "$dir/render" && cue mod edit --drop-require="opmodel.dev/catalogs/opm@v2" )
  fi

  # local-module.cue is the COMPLETE main-module dependency view, not a patch:
  # cue/load/config.go:581 makes it take precedence over module.cue's deps
  # wholesale. Hand-writing only the replaced entries silently drops the rest,
  # so it is always generated with `cue mod edit --replace`.
  local repl=(
    --replace="experiments.opmodel.dev/0019/authority/consumer@v0=../consumer"
    --replace="experiments.opmodel.dev/0019/authority/platform@v0=../platform"
  )
  if [ "$mode" = replaced ]; then
    repl+=( --replace="opmodel.dev/catalogs/opm@v2=$(extract_dir opmodel.dev/catalogs/opm "$PLATFORM_PIN")" )
  fi
  ( cd "$dir/render" && cue mod edit "${repl[@]}" ) || return

  local resolved fqn full_status consumer_view
  resolved="$(cd "$dir/render" && cue eval -e catalogVersionResolved --out text ./probe 2>&1 | tail -1)"
  fqn="$(cd "$dir/render" && cue eval -e transformerFQNSample --out text ./probe 2>&1 | tail -1)"
  consumer_view="$(cd "$dir/render" && cue eval -e catalogVersionSeenByConsumer --out text ./full 2>&1 | tail -1)"
  if ( cd "$dir/render" && cue vet -c ./full ) >"$dir/full.err" 2>&1; then full_status=ok; else full_status=FAILED; fi

  local authority=no
  [ "$resolved" = "${PLATFORM_PIN#v}" ] && authority=YES

  printf '%-18s %-10s %-16s %-9s %-16s %-10s %s\n' \
    "${cpin#v}" "$mode" "$resolved" "$authority" "$consumer_view" "$full_status" \
    "$(echo "$fqn" | sed 's|.*/||')"
}

prime
echo
echo "platform module DECLARES catalogs/opm@${PLATFORM_PIN#v} in every case"
echo "(a declaration, not a guarantee: as a dependency it is a minimum the"
echo " graph can raise. RESOLVED is what the build actually selected.)"
echo
printf '%-18s %-10s %-16s %-9s %-16s %-10s %s\n' \
  CONSUMER-PIN MODE RESOLVED AUTHORITY CONSUMER-SEES FULL-VET TRANSFORMER-BYTES
printf '%.0s-' {1..118}; echo
for cpin in "${CONSUMER_PINS[@]}"; do
  for mode in "${MODES[@]}"; do
    run_case "$cpin" "$mode"
  done
done
echo
echo "Scratch trees and full-build errors under $OUT/"
