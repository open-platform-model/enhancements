#!/usr/bin/env bash
# Reverse index: enhancement -> delivery state, derived from plans/.
#
# There is no `implementation` field on an entry and no `implemented`
# status. Whether a design has been delivered is a fact about the plan that
# delivers it, so it is COMPUTED here rather than asserted in the entry.
# A stored flag is a human assertion that goes stale; this cannot.
#
# The relation stays one-way: plans cite enhancements, never the reverse.
# This script reads both sides because it is tooling, not an entry.
#
# Emits TSV, one row per entry:
#   id  state  plans  slices_done/slices_total  uncovered_decisions  unclaimed_oqs
#
# States:
#   unplanned  no plan's `implements` names this id
#   planned    a plan exists, no slice has started
#   in-flight  at least one slice in-progress or done, not all done
#   delivered  every non-cancelled slice done AND every DN covered
#
# `delivered` is deliberately stronger than the flag it replaced: a design
# is not delivered while a decision it made has no slice carrying it.
set -euo pipefail
cd "$(dirname "$0")/.."

ONLY="${1:-}"

# Decisions an entry declares, tombstones excluded. A tombstoned number
# (`### D18: (merged into D3, …)`) is retired rather than unimplemented, so
# it is not owed a slice — same exclusion plans:uncovered applies.
declared_decisions() {
  local dec="$1/03-decisions.md"
  [ -f "$dec" ] || return 0
  grep -hoE '^#{2,4} D[0-9]+: [^(]' "$dec" 2>/dev/null | grep -oE 'D[0-9]+' | sort -u || true
}

# Open Questions the entry deferred to implementation. The plan side claims
# them via a slice's `resolves`; an unclaimed one is a design decision
# nobody has picked up.
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
  # reporting it as `unplanned` forever would read as work outstanding.
  status=$(yq -r '.status' "$cfg")
  case "$status" in
    rejected|superseded)
      printf '%s\t%s\t-\t-\t-\t-\n' "$id" "$status"
      continue
      ;;
  esac

  plans=""
  total=0
  done_n=0
  started=0
  covered=""
  unsliced=""

  for plan in plans/*/plan.yaml; do
    [ -f "$plan" ] || continue
    yq -e ".implements[] | select(. == \"$id\")" "$plan" >/dev/null 2>&1 || continue
    plans="${plans:+$plans,}$(basename "$(dirname "$plan")")"

    while IFS=$'\t' read -r sstatus sdec; do
      [ -z "$sstatus" ] && continue
      case "$sstatus" in
        cancelled) continue ;;
        done)      total=$((total + 1)); done_n=$((done_n + 1)); started=1 ;;
        in-progress) total=$((total + 1)); started=1 ;;
        *)         total=$((total + 1)) ;;
      esac
    done < <(yq -r '.slices[] | [.status, ((.decisions // []) | join(" "))] | @tsv' "$plan" 2>/dev/null)
  done

  # Coverage is computed across EVERY plan, not only the ones implementing
  # this entry. A decision of entry A is legitimately carried by a slice in
  # a plan that implements entry B — measured: 0010's D17 and D40 are both
  # carried by slices in the artifact-publishing plan, which implements
  # 0011. Restricting coverage to the entry's own plans reports those two
  # as orphans forever.
  #
  # Only DONE slices count. A planned slice naming a decision is a promise,
  # not delivery.
  for plan in plans/*/plan.yaml; do
    [ -f "$plan" ] || continue
    covered="$covered $(yq -r '.slices[] | select(.status == "done") | (.decisions // [])[]' "$plan" 2>/dev/null | tr '\n' ' ')"
    # Decisions a plan states need no slice, each with a reason. Reviewed
    # like any other line in the plan; not a suppression list.
    unsliced="$unsliced $(yq -r '(.unsliced // {}) | keys | .[]' "$plan" 2>/dev/null | tr '\n' ' ')"
  done

  if [ -z "$plans" ]; then
    printf '%s\tunplanned\t-\t0/0\t-\t-\n' "$id"
    continue
  fi

  # Coverage: declared DNs minus those carried by a done slice or excused.
  cited=$(printf '%s %s' "$covered" "$unsliced" | tr ' ' '\n' \
          | sed -n "s/^$id://p" | grep -E '^D[0-9]+$' | sort -u || true)
  declared=$(declared_decisions "$dir")
  if [ -n "$declared" ]; then
    uncovered=$(comm -23 <(printf '%s\n' "$declared") <(printf '%s\n' "$cited") | grep -c . || true)
  else
    uncovered=0
  fi

  # Deferred OQs no slice claims.
  claimed=$(for plan in plans/*/plan.yaml; do
              [ -f "$plan" ] || continue
              yq -r '.slices[] | (.resolves // [])[]' "$plan" 2>/dev/null
            done | sed -n "s/^$id://p" | sort -u || true)
  deferred=$(deferred_oqs "$dir")
  if [ -n "$deferred" ]; then
    unclaimed=$(comm -23 <(printf '%s\n' "$deferred") <(printf '%s\n' "$claimed") | grep -c . || true)
  else
    unclaimed=0
  fi

  if [ "$total" -gt 0 ] && [ "$done_n" -eq "$total" ] && [ "${uncovered:-0}" -eq 0 ]; then
    state=delivered
  elif [ "$started" -eq 1 ]; then
    state=in-flight
  else
    state=planned
  fi

  printf '%s\t%s\t%s\t%s/%s\t%s\t%s\n' \
    "$id" "$state" "$plans" "$done_n" "$total" "${uncovered:-0}" "${unclaimed:-0}"
done
