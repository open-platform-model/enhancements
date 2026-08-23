#!/usr/bin/env bash
# Content hash binding a gate walk to the entry it walked.
#
# `task promote` refuses when this differs from the hash recorded in
# .gates/NNNN.yaml. That is what makes the admission rubric a gate rather
# than a ritual: walk the rubric, then edit the entry, and the verdict is
# automatically void.
#
# WHAT IS COVERED: the six narrative documents, any compilable CUE
# (schemas/, contracts/), and the design-bearing config fields.
#
# WHAT IS NOT: `updated` and `history`. Bookkeeping edits happen constantly
# and forcing a re-walk for each one would train everyone to re-run the walk
# without reading it, which is worse than not having the gate.
set -euo pipefail
cd "$(dirname "$0")/.."

ID="${1:?usage: entry_hash.sh NNNN}"
DIR="$ID"
[ -d "$DIR" ] || DIR="archive/$ID"
[ -d "$DIR" ] || { echo "no such entry: $ID" >&2; exit 1; }

{
  # Narrative documents and compilable CUE, in a stable order.
  find "$DIR" -type f \( -name '*.md' -o -name '*.cue' \) \
       -not -path '*/cue.mod/*' \
    | LC_ALL=C sort \
    | while read -r f; do
        printf '%s\n' "$f"
        cat "$f"
      done

  # Design-bearing metadata only.
  yq -r '[.summary, .area, (.affects | join(",")), (.semver // ""), (.core_schema | tostring)] | @tsv' \
     "$DIR/config.yaml"
} | sha256sum | cut -d' ' -f1
