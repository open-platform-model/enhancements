#!/usr/bin/env bash
# Retarget relative cross-entry links after an entry moves into archive/.
#
# From a live entry a link is `](../NNNN/` when NNNN is live and
# `](../archive/NNNN/` when it is archived; from an archived entry it is
# `](../../NNNN/` and `](../NNNN/` respectively. The repo-root browse files
# (INDEX.md, GRAPH.md) sit one level further up from an archived entry. Every
# top-level *.md in every entry is normalised to the correct form, whatever
# form it has now, so the script is idempotent.
#
# One implementation for the three archive paths (`task close`, `task reject`,
# `task supersede`): a terminal entry is always archived, and each move would
# otherwise leave its own README pointing at ../INDEX.md.
#
# A retargeted link inside a live entry moves that entry's gate hash, so the
# script names each live entry that has a walked verdict.
#
# Usage (from the repo root):
#   relink.sh     prints what it changed; silent when nothing moved
set -euo pipefail
YELLOW='\033[0;33m'; RESET='\033[0m'

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
: > "$WORK/live.sed"; : > "$WORK/arch.sed"
for d in [0-9][0-9][0-9][0-9]/ archive/[0-9][0-9][0-9][0-9]/; do
  [ -d "$d" ] || continue
  x=$(basename "$d")
  case "$d" in
    archive/*)
      printf 's#\\]\\((\\.\\./)+(archive/)?%s/#](../archive/%s/#g\n' "$x" "$x" >> "$WORK/live.sed"
      printf 's#\\]\\((\\.\\./)+(archive/)?%s/#](../%s/#g\n'         "$x" "$x" >> "$WORK/arch.sed" ;;
    *)
      printf 's#\\]\\((\\.\\./)+(archive/)?%s/#](../%s/#g\n'         "$x" "$x" >> "$WORK/live.sed"
      printf 's#\\]\\((\\.\\./)+(archive/)?%s/#](../../%s/#g\n'      "$x" "$x" >> "$WORK/arch.sed" ;;
  esac
done
printf 's#\\]\\((\\.\\./)+(INDEX|GRAPH)\\.md#](../\\2.md#g\n'    >> "$WORK/live.sed"
printf 's#\\]\\((\\.\\./)+(INDEX|GRAPH)\\.md#](../../\\2.md#g\n' >> "$WORK/arch.sed"

changed=()
for f in [0-9][0-9][0-9][0-9]/*.md archive/[0-9][0-9][0-9][0-9]/*.md; do
  [ -f "$f" ] || continue
  case "$f" in archive/*) script="$WORK/arch.sed" ;; *) script="$WORK/live.sed" ;; esac
  sed -E -f "$script" "$f" > "$WORK/out.md"
  if ! cmp -s "$f" "$WORK/out.md"; then cp "$WORK/out.md" "$f"; changed+=("$f"); fi
done

[ "${#changed[@]}" -gt 0 ] || exit 0
echo "  relative links retargeted in ${#changed[@]} file(s):"
printf '    %s\n' "${changed[@]}"
for f in "${changed[@]}"; do
  case "$f" in
    archive/*) ;;
    *) e=${f%%/*}
       if [ -f ".gates/$e.yaml" ]; then
         printf "  ${YELLOW}note${RESET} %s has a walked gate verdict; the link edit moved its hash, re-walk before promote\n" "$e"
       fi ;;
  esac
done | sort -u
