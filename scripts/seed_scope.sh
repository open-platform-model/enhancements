#!/usr/bin/env bash
# Seed README's `### Out of scope` from `task new`'s required NOT answer.
#
# The out-of-scope boundary is asked for at scaffold time on purpose: an
# entry with no stated boundary is the one that later reads as three
# entries, and by the time that is obvious the prose has already grown.
set -euo pipefail
readme="${1:?usage: seed_scope.sh <README.md> <not-text>}"
not="${2:?}"
awk -v not="$not" '
  { print }
  /^### Out of scope$/ && !done { print ""; print "- " not; done = 1; skip = 1; next }
' "$readme" > "$readme.tmp"
mv "$readme.tmp" "$readme"
