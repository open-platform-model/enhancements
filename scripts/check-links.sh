#!/usr/bin/env bash
# Relative-link check for the files opmodel.dev publishes.
#
# The published set is each entry's README.md and its seven split documents
# (NNNN/0[1-7]-*.md), live and archived, plus INDEX.md and GRAPH.md. The
# template (0000/) and the subfolders (experiments/, research/, schemas/,
# contracts/) are not published, so they are not checked.
#
# Every Markdown link outside a fenced code block and outside an inline code
# span is resolved against the directory of the file that holds it: inline
# links and images `[text](target)` and reference definitions
# `[label]: target`. A target with a URL scheme (https:, mailto:, ...) or a
# bare `#anchor` is skipped; a `#fragment` or `?query` is dropped before the
# lookup. An absolute `/path` is reported too: it resolves against a host
# root, which differs between GitHub and the site.
#
# Usage: check-links.sh [FILE...]   (default: the published set)
# Prints one `file:line: target` per broken link and exits 1 if any.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  files=()
  for f in INDEX.md GRAPH.md \
           [0-9][0-9][0-9][0-9]/README.md [0-9][0-9][0-9][0-9]/0[1-7]-*.md \
           archive/[0-9][0-9][0-9][0-9]/README.md archive/[0-9][0-9][0-9][0-9]/0[1-7]-*.md; do
    [ -f "$f" ] || continue
    case "$f" in 0000/*) continue ;; esac
    files+=("$f")
  done
fi

# Emit `line<TAB>target` for every link in one file.
extract() {
  awk '
    # Fenced code blocks: ``` or ~~~, possibly indented (inside a list).
    /^[[:space:]]*(```|~~~)/ { in_code = !in_code; next }
    in_code { next }
    {
      line = $0
      # Inline code spans never hold a link.
      gsub(/`[^`]*`/, "", line)
      # Reference definition: [label]: target
      if (match(line, /^[[:space:]]*\[[^]]+\]:[[:space:]]+[^[:space:]]+/)) {
        def = substr(line, RSTART, RLENGTH)
        sub(/^[[:space:]]*\[[^]]+\]:[[:space:]]+/, "", def)
        print NR "\t" def
        next
      }
      # Inline links and images: ](target) or ](target "title")
      while (match(line, /\]\([^)]*\)/)) {
        t = substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
        sub(/^[[:space:]]+/, "", t)
        if (t ~ /^</) { sub(/^</, "", t); sub(/>.*$/, "", t) }
        else          { sub(/[[:space:]].*$/, "", t) }
        if (t != "") print NR "\t" t
      }
    }
  ' "$1"
}

broken=0
for f in "${files[@]}"; do
  dir=$(dirname "$f")
  while IFS=$'\t' read -r ln target; do
    case "$target" in
      \#*) continue ;;                                  # same-page anchor
      [a-zA-Z]*:*)
        # A scheme (https:, mailto:) is external; a colon after a slash is a path.
        scheme=${target%%:*}
        case "$scheme" in */*) ;; *) continue ;; esac
        ;;
    esac
    path=${target%%#*}
    path=${path%%\?*}
    path=${path//%20/ }
    [ -n "$path" ] || continue
    if [ "${path#/}" != "$path" ]; then
      printf '%s:%s: %s (absolute path; use a relative link)\n' "$f" "$ln" "$target"
      broken=1
      continue
    fi
    if [ ! -e "$dir/$path" ]; then
      printf '%s:%s: %s\n' "$f" "$ln" "$target"
      broken=1
    fi
  done < <(extract "$f")
done

if [ "$broken" -ne 0 ]; then
  echo "broken relative links found (checked ${#files[@]} files)" >&2
  exit 1
fi
printf 'ok   %d published files, no broken relative links\n' "${#files[@]}"
