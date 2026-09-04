#!/usr/bin/env bash
# Dependency edges between enhancements: the depends_on rule, checked from
# both ends.
#
# An edge exists iff a decision depends on a decision. config.yaml lists
# MMMM in `depends_on` iff a live `### DN:` block in 03-decisions.md carries
# a tokens-only `**Depends:** MMMM:DN` line (schema.cue #QualifiedDNStr).
# Neither half is meaningful alone: the field is the index the graph reads,
# the line is the evidence a reader can check. So this script holds the one
# implementation of the rule and `task vet` / `task vet:one` both call it.
#
# Usage:
#   depends.sh check NNNN   one violation per line, empty when clean, exit 0
#   depends.sh cycles       ids that sit on a dependency cycle, empty when
#                           the graph is acyclic (tsort does the work)
#
# Rules `check` enforces on a live entry:
#   (a) every depends_on id exists (live or archived) and is not the entry
#   (b) every depends_on id is carried by a **Depends:** line in a LIVE
#       decision (a tombstone owes no dependency)
#   (c) every **Depends:** token MMMM:DN: the line is well-formed, MMMM is in
#       depends_on, MMMM is not the entry, DN is a heading in MMMM's decision
#       log, and that heading is not a tombstone
# Self-dependency is rule (a) on purpose: `tsort` accepts `A A` silently.
set -euo pipefail
cd "$(dirname "$0")/.."

# Token grammar; must agree with schema.cue #QualifiedDNStr.
DEP_LINE='^\*\*Depends:\*\* [0-9]{4}:D[0-9]+(, [0-9]{4}:D[0-9]+)*$'

existing_ids() {
  for d in [0-9][0-9][0-9][0-9]/ archive/[0-9][0-9][0-9][0-9]/; do
    [ -d "$d" ] || continue
    basename "$d"
  done | sort -u
}

# NNNN → its 03-decisions.md (live first, then archived), or nothing.
decisions_of() {
  local f="$1/03-decisions.md"
  [ -f "$f" ] || f="archive/$1/03-decisions.md"
  [ -f "$f" ] && printf '%s\n' "$f" || true
}

# Every **Depends:** line, scoped to its enclosing decision heading:
#   DN <TAB> 1|0 (live|tombstone) <TAB> line
# A tombstone heading opens a block like any other, so a stray field under
# it is attributed to the tombstone and rule (c) rejects it.
depends_lines() {
  awk '
    /^#{2,4} D[0-9]+: / { cur=$0; sub(/^#+ /,"",cur); sub(/:.*/,"",cur)
                          live = ($0 ~ /^#{2,4} D[0-9]+: [^(]/) ? 1 : 0; next }
    /^\*\*Depends:\*\*/ { if (cur != "") printf "%s\t%d\t%s\n", cur, live, $0 }
  ' "$1"
}

check_one() {
  local id="$1"
  local cfg="$id/config.yaml" dec="$id/03-decisions.md"
  [ -f "$cfg" ] || { printf 'no live entry %s\n' "$id"; return 0; }

  local ids declared
  ids=$(existing_ids)
  declared=$(yq -r '.depends_on[]?' "$cfg" | { grep -E '.' || true; } | sort -u)

  # (a)
  local ref
  for ref in $declared; do
    if [ "$ref" = "$id" ]; then
      printf "depends_on lists the entry itself ('%s')\n" "$ref"
      continue
    fi
    printf '%s\n' "$ids" | grep -qx "$ref" \
      || printf "depends_on contains unknown ref '%s' (no NNNN/ nor archive/NNNN/ dir; legacy:NNN is not a dependency target)\n" "$ref"
  done

  # (c)
  local cited="" dn live line toks tok mid mdn mdec
  if [ -f "$dec" ]; then
    while IFS=$'\t' read -r dn live line; do
      [ -n "$dn" ] || continue
      if [ "$live" = 0 ]; then
        printf '%s is a tombstone but carries a **Depends:** line; a retired number owes no dependency (move it to the surviving decision or delete it)\n' "$dn"
        continue
      fi
      if ! printf '%s\n' "$line" | grep -qE "$DEP_LINE"; then
        printf '%s has a malformed **Depends:** line (tokens only: **Depends:** MMMM:DN, MMMM:DN; no prose): %s\n' "$dn" "$line"
        continue
      fi
      toks=${line#\*\*Depends:\*\* }
      for tok in ${toks//,/ }; do
        mid=${tok%%:*}; mdn=${tok#*:}
        cited="$cited $mid"
        if [ "$mid" = "$id" ]; then
          printf '%s **Depends:** %s names this entry; a local dependency is prose, not a field\n' "$dn" "$tok"
          continue
        fi
        printf '%s\n' "$declared" | grep -qx "$mid" \
          || printf '%s **Depends:** %s but config.yaml.depends_on does not list %s\n' "$dn" "$tok" "$mid"
        mdec=$(decisions_of "$mid")
        if [ -z "$mdec" ]; then
          printf '%s **Depends:** %s but %s has no 03-decisions.md (live or archived)\n' "$dn" "$tok" "$mid"
        elif ! grep -qE "^#{2,4} $mdn:" "$mdec"; then
          printf '%s **Depends:** %s but %s/03-decisions.md has no such heading\n' "$dn" "$tok" "$mid"
        elif grep -qE "^#{2,4} $mdn: \(" "$mdec"; then
          printf '%s **Depends:** %s but %s is a tombstone in %s; depend on the decision it merged into\n' "$dn" "$tok" "$mdn" "$mid"
        fi
      done
    done <<< "$(depends_lines "$dec")"
  fi

  # (b)
  cited=$(printf '%s\n' $cited | { grep -E '.' || true; } | sort -u)
  comm -23 <(printf '%s\n' "$declared" | { grep -E '.' || true; }) <(printf '%s\n' "$cited") \
    | while read -r ref; do
        [ -n "$ref" ] || continue
        printf "depends_on lists '%s' but no live decision carries a **Depends:** %s:DN line (an edge exists iff a decision depends on a decision)\n" "$ref" "$ref"
      done
}

cycles() {
  local edges cfg id
  edges=$(for cfg in [0-9][0-9][0-9][0-9]/config.yaml archive/[0-9][0-9][0-9][0-9]/config.yaml; do
            [ -f "$cfg" ] || continue
            id=$(yq -r '.id' "$cfg")
            [ "$id" = "0000" ] && continue
            yq -r '.depends_on[]?' "$cfg" | { grep -E '.' || true; } | sed "s/^/$id /"
          done)
  [ -n "$edges" ] || return 0
  printf '%s\n' "$edges" | { tsort 2>&1 >/dev/null || true; } \
    | { grep -oE '^tsort: [0-9]{4}$' || true; } | sed 's/^tsort: //' | sort -u
}

case "${1:-}" in
  check)  [ -n "${2:-}" ] || { echo "usage: $0 check NNNN" >&2; exit 2; }; check_one "$2" ;;
  cycles) cycles ;;
  *) echo "usage: $0 check NNNN | cycles" >&2; exit 2 ;;
esac
