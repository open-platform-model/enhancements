#!/usr/bin/env bash
# Derived delivery state per enhancement, computed from each entry's own
# append-only delivery log (NNNN/delivery.yaml; see schema.cue #Delivery).
#
# There is no stored implementation flag. Whether a design has been
# implemented is a fact about the changes that landed, so it is COMPUTED
# from the log rather than asserted: `implemented` requires every live DN
# in 03-decisions.md to be carried by a logged change or excused in
# `no_work`. A forgotten log entry under-reports (the entry stays
# in-progress) and can never produce a false `implemented`.
#
# Emits TSV, one row per entry:
#   id  state  log_entries  covered/declared_decisions  uncovered  unclaimed_oqs
#
# States:
#   not-started  no delivery.yaml, or an empty log
#   in-progress  the log is non-empty but decision coverage is incomplete
#   implemented  every live DN covered by a log entry or excused in no_work
#   rejected / superseded  terminal, passed through; delivery never owed
set -euo pipefail
cd "$(dirname "$0")/.."

ONLY="${1:-}"

# Decisions an entry declares, tombstones excluded. A tombstoned number
# (`### D18: (merged into D3, …)`) is retired rather than unimplemented, so
# it is not owed a change.
declared_decisions() {
  local dec="$1/03-decisions.md"
  [ -f "$dec" ] || return 0
  grep -hoE '^#{2,4} D[0-9]+: [^(]' "$dec" 2>/dev/null | grep -oE 'D[0-9]+' | sort -u || true
}

# Open Questions the entry deferred to implementation. A log entry claims
# one via `resolves`; an unclaimed one is a design decision nobody has
# picked up yet.
deferred_oqs() {
  local q="$1/07-questions.md"
  [ -f "$q" ] || return 0
  grep -hoE '^-[[:space:]]+\*\*OQ[0-9]+:' "$q" 2>/dev/null | grep -oE 'OQ[0-9]+' \
    | while read -r oq; do
        if awk -v want="$oq" '
              $0 ~ ("\\*\\*" want ":") {inblock=1}
              inblock && /Status:/ {print; exit}
            ' "$q" 2>/dev/null | grep -q 'deferred-to-implementation'; then
          echo "$oq"
        fi
      done | sort -u || true
}

for cfg in [0-9][0-9][0-9][0-9]/config.yaml archive/[0-9][0-9][0-9][0-9]/config.yaml; do
  [ -f "$cfg" ] || continue
  dir=$(dirname "$cfg")
  id=$(yq -r '.id' "$cfg")
  [ "$id" = "0000" ] && continue
  [ -n "$ONLY" ] && [ "$ONLY" != "$id" ] && continue

  # Neither terminal state is owed delivery. A rejected idea was never
  # accepted; a superseded one handed its intent to its successor, and
  # reporting it as `not-started` forever would read as work outstanding.
  status=$(yq -r '.status' "$cfg")
  case "$status" in
    rejected|superseded)
      printf '%s\t%s\t-\t-\t-\t-\n' "$id" "$status"
      continue
      ;;
  esac

  dfile="$dir/delivery.yaml"
  log_n=0
  covered=""
  no_work=""
  claimed=""
  if [ -f "$dfile" ]; then
    log_n=$(yq -r '.log | length' "$dfile" 2>/dev/null || echo 0)
    # Materialise before any grep -q (pipefail/SIGPIPE trap).
    covered=$(yq -r '.log[] | (.decisions // [])[]' "$dfile" 2>/dev/null | sort -u || true)
    no_work=$(yq -r '(.no_work // {}) | keys | .[]' "$dfile" 2>/dev/null | sort -u || true)
    claimed=$(yq -r '.log[] | (.resolves // [])[]' "$dfile" 2>/dev/null | sort -u || true)
  fi

  declared=$(declared_decisions "$dir")
  declared_n=0; [ -n "$declared" ] && declared_n=$(printf '%s\n' "$declared" | grep -c .)

  # Coverage: declared live DNs minus those carried by a logged change or
  # excused in no_work.
  excused_or_covered=$(printf '%s\n%s\n' "$covered" "$no_work" | grep -E '^D[0-9]+$' | sort -u || true)
  if [ -n "$declared" ]; then
    uncovered=$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$excused_or_covered") | grep -c . || true)
    covered_n=$((declared_n - uncovered))
  else
    uncovered=0
    covered_n=0
  fi

  # Deferred OQs no log entry claims.
  deferred=$(deferred_oqs "$dir")
  if [ -n "$deferred" ]; then
    if [ -n "$claimed" ]; then
      unclaimed=$(comm -23 <(printf '%s\n' "$deferred") <(printf '%s\n' "$claimed") | grep -c . || true)
    else
      unclaimed=$(printf '%s\n' "$deferred" | grep -c . || true)
    fi
  else
    unclaimed=0
  fi

  # `implemented` needs decisions to exist and all of them accounted for:
  # an entry with no decisions yet cannot be implemented, only worked on.
  if [ "$declared_n" -gt 0 ] && [ "${uncovered:-0}" -eq 0 ] && { [ "$log_n" -gt 0 ] || [ -n "$no_work" ]; }; then
    state=implemented
  elif [ "$log_n" -gt 0 ]; then
    state=in-progress
  else
    state=not-started
  fi

  if [ ! -f "$dfile" ]; then
    printf '%s\t%s\t-\t%s/%s\t%s\t%s\n' "$id" "$state" "$covered_n" "$declared_n" "${uncovered:-0}" "${unclaimed:-0}"
  else
    printf '%s\t%s\t%s\t%s/%s\t%s\t%s\n' "$id" "$state" "$log_n" "$covered_n" "$declared_n" "${uncovered:-0}" "${unclaimed:-0}"
  fi
done
