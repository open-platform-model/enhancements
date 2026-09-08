#!/usr/bin/env bash
# Cross-entry relation edges between enhancements, checked from both ends.
#
# Two edge kinds, one rule each. Both are decision-backed: an edge exists
# iff a decision relates to a decision.
#
#   depends_on  MMMM is listed iff a live `### DN:` block in 03-decisions.md
#               carries a tokens-only `**Depends:** MMMM:DN` line. This
#               decision RESTS ON that one.
#   amends      MMMM is listed iff a live `### DN:` block carries a qualified
#               `MMMM:DN` token on its `**Amends:**` or `**Supersedes:**`
#               line (schema.cue #QualifiedDNStr). This decision CHANGES that
#               one: Amends narrows it and it survives, Supersedes kills it.
#               Unqualified tokens on those lines stay local relations.
#
# Neither half is meaningful alone: the config.yaml field is the index the
# graph reads, the line is the evidence a reader can check. The amended
# entry is never written to. "Amended by" is derived by scanning the
# amenders' logs (`inbound` below, surfaced by `task show`), because a stored
# back-link goes stale the day the amender is rejected and cannot say whether
# the change has landed. So this script holds the one implementation of both
# rules and `task vet` / `task vet:one` / `task show` all call it.
#
# Usage:
#   depends.sh check NNNN     one violation per line, empty when clean, exit 0
#   depends.sh cycles         ids on a depends_on cycle (tsort), empty when acyclic
#   depends.sh amends-cycles  ids on an amends cycle, empty when acyclic
#   depends.sh outbound NNNN  NNNN's own cross-entry Amends/Supersedes tokens:
#                             <DN> TAB <amends|supersedes> TAB <MMMM:DN>
#   depends.sh inbound NNNN   derived "amended by": every live foreign token
#                             naming NNNN, live and archived amenders alike:
#                             <amender> TAB <its DN> TAB <amends|supersedes> TAB <DN of NNNN>
#
# Rules `check` enforces on a live entry:
#   (a) every depends_on / amends id exists (live or archived) and is not
#       the entry
#   (b) every depends_on id is carried by a **Depends:** line in a LIVE
#       decision, every amends id by a qualified token on a LIVE decision's
#       **Amends:** / **Supersedes:** line (a tombstone owes no relation)
#   (c) every **Depends:** token MMMM:DN: the line is well-formed, MMMM is
#       in depends_on, MMMM is not the entry, DN is a heading in MMMM's
#       decision log, and that heading is not a tombstone
#   (d) every qualified **Amends:** / **Supersedes:** token MMMM:DN: MMMM is
#       in amends, MMMM is not the entry (a local relation is the bare DN),
#       DN is a live heading in MMMM's log, and MMMM is neither superseded
#       (amend the successor) nor rejected (nothing live to amend)
#   (e) no decision both rests on and supersedes the same foreign decision:
#       **Depends:** and **Supersedes:** naming one MMMM:DN contradict.
#       Amends alongside Depends is fine; a decision may narrow what it
#       rests on.
# Self-dependency is rule (a) on purpose: `tsort` accepts `A A` silently.
set -euo pipefail
cd "$(dirname "$0")/.."

# Token grammars; must agree with schema.cue #QualifiedDNStr.
DEP_LINE='^\*\*Depends:\*\* [0-9]{4}:D[0-9]+(, [0-9]{4}:D[0-9]+)*$'
QTOK='[0-9]{4}:D[0-9]+'

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

# NNNN → its config.yaml (live first, then archived), or nothing.
config_of() {
  local f="$1/config.yaml"
  [ -f "$f" ] || f="archive/$1/config.yaml"
  [ -f "$f" ] && printf '%s\n' "$f" || true
}

# Every relation line, scoped to its enclosing decision heading:
#   DN <TAB> 1|0 (live|tombstone) <TAB> Field <TAB> line
# Field is Depends, Amends or Supersedes. A tombstone heading opens a block
# like any other, so a stray field under it is attributed to the tombstone
# and rules (c)/(d) reject it.
relation_lines() {
  awk '
    /^#{2,4} D[0-9]+: / { cur=$0; sub(/^#+ /,"",cur); sub(/:.*/,"",cur)
                          live = ($0 ~ /^#{2,4} D[0-9]+: [^(]/) ? 1 : 0; next }
    /^\*\*(Depends|Amends|Supersedes):\*\*/ {
      if (cur != "") { f=$0; sub(/^\*\*/,"",f); sub(/:.*/,"",f)
                       printf "%s\t%d\t%s\t%s\n", cur, live, f, $0 } }
  ' "$1"
}

# Qualified tokens on one line, one per output line (possibly none).
qtokens() {
  { grep -oE "\b$QTOK\b" <<< "$1" || true; }
}

# Does MMMM:DN resolve to a live heading in MMMM's log? Prints the violation.
#   $1 citing DN, $2 field label, $3 token, $4 MMMM, $5 DN
resolve_target() {
  local mdec
  mdec=$(decisions_of "$4")
  if [ -z "$mdec" ]; then
    printf '%s %s %s but %s has no 03-decisions.md (live or archived)\n' "$1" "$2" "$3" "$4"
  elif ! grep -qE "^#{2,4} $5:" "$mdec"; then
    printf '%s %s %s but %s/03-decisions.md has no such heading\n' "$1" "$2" "$3" "$4"
  elif grep -qE "^#{2,4} $5: \(" "$mdec"; then
    printf '%s %s %s but %s is a tombstone in %s; name the decision it merged into\n' "$1" "$2" "$3" "$5" "$4"
  fi
}

check_one() {
  local id="$1"
  local cfg="$id/config.yaml" dec="$id/03-decisions.md"
  [ -f "$cfg" ] || { printf 'no live entry %s\n' "$id"; return 0; }

  local ids dep_declared am_declared
  ids=$(existing_ids)
  dep_declared=$(yq -r '.depends_on[]?' "$cfg" | { grep -E '.' || true; } | sort -u)
  am_declared=$(yq -r '.amends[]?' "$cfg" | { grep -E '.' || true; } | sort -u)

  # (a)
  local field declared ref
  for field in depends_on amends; do
    if [ "$field" = depends_on ]; then declared="$dep_declared"; else declared="$am_declared"; fi
    for ref in $declared; do
      if [ "$ref" = "$id" ]; then
        printf "%s lists the entry itself ('%s')\n" "$field" "$ref"
        continue
      fi
      printf '%s\n' "$ids" | grep -qx "$ref" \
        || printf "%s contains unknown ref '%s' (no NNNN/ nor archive/NNNN/ dir; legacy:NNN is not a target)\n" "$field" "$ref"
    done
  done

  # (c), (d), and the per-decision sets rule (e) needs.
  local dep_cited="" am_cited="" dn live fld line toks tok mid mdn mcfg mst
  local -A dep_by_dn=() sup_by_dn=()
  if [ -f "$dec" ]; then
    while IFS=$'\t' read -r dn live fld line; do
      [ -n "$dn" ] || continue
      case "$fld" in
        Depends)
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
            dep_cited="$dep_cited $mid"
            dep_by_dn[$dn]="${dep_by_dn[$dn]:-} $tok"
            if [ "$mid" = "$id" ]; then
              printf '%s **Depends:** %s names this entry; a local dependency is prose, not a field\n' "$dn" "$tok"
              continue
            fi
            printf '%s\n' "$dep_declared" | grep -qx "$mid" \
              || printf '%s **Depends:** %s but config.yaml.depends_on does not list %s\n' "$dn" "$tok" "$mid"
            resolve_target "$dn" '**Depends:**' "$tok" "$mid" "$mdn"
          done
          ;;
        Amends|Supersedes)
          toks=$(qtokens "$line")
          [ -n "$toks" ] || continue
          if [ "$live" = 0 ]; then
            printf '%s is a tombstone but its **%s:** line names another entry (%s); a retired number owes no relation\n' "$dn" "$fld" "$(printf '%s\n' "$toks" | paste -sd, -)"
            continue
          fi
          for tok in $toks; do
            mid=${tok%%:*}; mdn=${tok#*:}
            am_cited="$am_cited $mid"
            if [ "$fld" = Supersedes ]; then sup_by_dn[$dn]="${sup_by_dn[$dn]:-} $tok"; fi
            if [ "$mid" = "$id" ]; then
              printf '%s **%s:** %s names this entry; a local relation is the bare token (%s)\n' "$dn" "$fld" "$tok" "$mdn"
              continue
            fi
            printf '%s\n' "$am_declared" | grep -qx "$mid" \
              || printf '%s **%s:** %s but config.yaml.amends does not list %s\n' "$dn" "$fld" "$tok" "$mid"
            mcfg=$(config_of "$mid")
            if [ -n "$mcfg" ]; then
              mst=$(yq -r '.status' "$mcfg")
              case "$mst" in
                superseded)
                  printf "%s **%s:** %s but %s is superseded (by %s); amend the successor's decision instead\n" \
                    "$dn" "$fld" "$tok" "$mid" "$(yq -r '.superseded_by // "?"' "$mcfg")" ;;
                rejected)
                  printf '%s **%s:** %s but %s is rejected; a killed idea has no live decision to amend (revive it, or decide afresh)\n' \
                    "$dn" "$fld" "$tok" "$mid" ;;
              esac
            fi
            resolve_target "$dn" "**$fld:**" "$tok" "$mid" "$mdn"
          done
          ;;
      esac
    done <<< "$(relation_lines "$dec")"
  fi

  # (e)
  for dn in "${!sup_by_dn[@]}"; do
    for tok in ${sup_by_dn[$dn]}; do
      if printf '%s\n' "${dep_by_dn[$dn]:-}" | grep -qwF -- "$tok"; then
        printf '%s both rests on and supersedes %s (**Depends:** and **Supersedes:** contradict; a decision cannot rest on what it kills, and Amends is the field for narrowing)\n' "$dn" "$tok"
      fi
    done
  done

  # (b)
  dep_cited=$(printf '%s\n' $dep_cited | { grep -E '.' || true; } | sort -u)
  comm -23 <(printf '%s\n' "$dep_declared" | { grep -E '.' || true; }) <(printf '%s\n' "$dep_cited") \
    | while read -r ref; do
        [ -n "$ref" ] || continue
        printf "depends_on lists '%s' but no live decision carries a **Depends:** %s:DN line (an edge exists iff a decision depends on a decision)\n" "$ref" "$ref"
      done
  am_cited=$(printf '%s\n' $am_cited | { grep -E '.' || true; } | sort -u)
  comm -23 <(printf '%s\n' "$am_declared" | { grep -E '.' || true; }) <(printf '%s\n' "$am_cited") \
    | while read -r ref; do
        [ -n "$ref" ] || continue
        printf "amends lists '%s' but no live decision carries a qualified %s:DN token on an **Amends:** or **Supersedes:** line (an edge exists iff a decision changes a decision)\n" "$ref" "$ref"
      done
}

# ids sitting on a cycle of the given config.yaml list field.
cycles() {
  local field="$1" edges cfg id
  edges=$(for cfg in [0-9][0-9][0-9][0-9]/config.yaml archive/[0-9][0-9][0-9][0-9]/config.yaml; do
            [ -f "$cfg" ] || continue
            id=$(yq -r '.id' "$cfg")
            [ "$id" = "0000" ] && continue
            yq -r ".${field}[]?" "$cfg" | { grep -E '.' || true; } | sed "s/^/$id /"
          done)
  [ -n "$edges" ] || return 0
  printf '%s\n' "$edges" | { tsort 2>&1 >/dev/null || true; } \
    | { grep -oE '^tsort: [0-9]{4}$' || true; } | sed 's/^tsort: //' | sort -u
}

# NNNN's own cross-entry Amends/Supersedes tokens, from live decisions.
outbound() {
  local id="$1" dec dn live fld line tok
  dec=$(decisions_of "$id")
  [ -n "$dec" ] || return 0
  relation_lines "$dec" | while IFS=$'\t' read -r dn live fld line; do
    [ "$live" = 1 ] || continue
    case "$fld" in Amends|Supersedes) ;; *) continue ;; esac
    qtokens "$line" | while read -r tok; do
      [ -n "$tok" ] || continue
      if [ "${tok%%:*}" = "$id" ]; then continue; fi
      printf '%s\t%s\t%s\n' "$dn" "${fld,,}" "$tok"
    done
  done
}

# Derived reverse of `outbound`: every live foreign token naming NNNN,
# across live and archived amenders. Sorted by NNNN's decision, then amender.
inbound() {
  local target="$1" d id dec dn live fld line tok
  for d in [0-9][0-9][0-9][0-9]/ archive/[0-9][0-9][0-9][0-9]/; do
    [ -d "$d" ] || continue
    id=$(basename "$d")
    [ "$id" = 0000 ] && continue
    [ "$id" = "$target" ] && continue
    dec="$d/03-decisions.md"
    [ -f "$dec" ] || continue
    relation_lines "$dec" | while IFS=$'\t' read -r dn live fld line; do
      [ "$live" = 1 ] || continue
      case "$fld" in Amends|Supersedes) ;; *) continue ;; esac
      { grep -oE "\b${target}:D[0-9]+\b" <<< "$line" || true; } | while read -r tok; do
        [ -n "$tok" ] || continue
        printf '%s\t%s\t%s\t%s\n' "$id" "$dn" "${fld,,}" "${tok#*:}"
      done
    done
  done | sort -t "$(printf '\t')" -k4,4V -k1,1
}

case "${1:-}" in
  check)         [ -n "${2:-}" ] || { echo "usage: $0 check NNNN" >&2; exit 2; }; check_one "$2" ;;
  cycles)        cycles depends_on ;;
  amends-cycles) cycles amends ;;
  outbound)      [ -n "${2:-}" ] || { echo "usage: $0 outbound NNNN" >&2; exit 2; }; outbound "$2" ;;
  inbound)       [ -n "${2:-}" ] || { echo "usage: $0 inbound NNNN" >&2; exit 2; }; inbound "$2" ;;
  *) echo "usage: $0 check NNNN | cycles | amends-cycles | outbound NNNN | inbound NNNN" >&2; exit 2 ;;
esac
