#!/usr/bin/env bash
# Runs every version-set case against a pristine copy of the fixtures.
# work/ is scratch and is recreated each run; fixtures/ is never modified.
set -uo pipefail
cd "$(dirname "$0")"

rm -rf work && mkdir -p work && cp fixtures/*.cue work/

hdr() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# case <title> <file> <version> [--naive]
case_run() {
  local title="$1" file="$2" version="$3"; shift 3
  hdr "$title"
  echo "  \$ opm catalog version set $version   ($file)"
  cp "work/$file" "work/.$file.before"
  go run . "work/$file" "$version" "$@"
  local rc=$?
  if [ $rc -eq 0 ]; then
    echo "  --- diff ---"
    diff -u "work/.$file.before" "work/$file" | tail -n +3 | sed 's/^/  /'
  fi
  rm -f "work/.$file.before"
}

case_run "OPEN → filled. The field OPM must write is the one it cannot read a value from." \
  catalog_open.cue 1.2.0

case_run "CONCRETE → replaced, with a longer value. Alignment is recomputed, not churned." \
  catalog_concrete.cue 1.10.0-rc.1

case_run "IDEMPOTENT. Setting the version it already has writes nothing at all." \
  catalog_concrete.cue 1.10.0-rc.1

case_run "CONJUNCTION, surgical. The type assertion the author wrote survives." \
  catalog_conjunction.cue 1.3.0

cp fixtures/catalog_conjunction.cue work/catalog_conjunction.cue
case_run "CONJUNCTION, naive (replace the whole value). The assertion is silently deleted." \
  catalog_conjunction.cue 1.3.0 --naive

case_run "ROLE-MARKED, and deliberately NOT named \"Version\". Found by role alone." \
  catalog_role.cue 2.0.0

case_run "UNMARKED. The field exists and has the right name; OPM does not own it." \
  catalog_unmarked.cue 1.3.0

case_run "MODULE. Nothing to write — a module carries no version in source (0010 D2)." \
  module_identity.cue 1.3.0

hdr "Every rewritten file still parses and vets"
for f in work/catalog_*.cue; do
  printf '  %-34s ' "$f"
  if out=$(cue vet -c "$f" 2>&1); then echo "ok"; else echo "FAILED: $out"; fi
done
