#!/usr/bin/env bash
# Prove the new-layout config schema (schema.cue #EntryConfig) with fixtures.
#
#   valid/*.yaml    must pass `cue vet -d '#EntryConfig'`
#   invalid/*.yaml  must fail, and the error must contain the text after
#                   "# expect:" on the first line of the file
#
# Run from anywhere: bash tests/schema/run.sh
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root" || exit 2
command -v cue >/dev/null 2>&1 || { echo "cue is required" >&2; exit 2; }

fail=0
pass=0
for f in tests/schema/valid/*.yaml; do
	if out=$(cue vet -d '#EntryConfig' schema.cue "$f" 2>&1); then
		pass=$((pass + 1))
	else
		printf 'FAIL valid fixture refused: %s\n%s\n' "$f" "$out"
		fail=$((fail + 1))
	fi
done
for f in tests/schema/invalid/*.yaml; do
	expect=$(sed -n '1s/^# expect: *//p' "$f")
	if [ -z "$expect" ]; then
		printf 'FAIL invalid fixture has no "# expect:" line: %s\n' "$f"
		fail=$((fail + 1))
		continue
	fi
	if out=$(cue vet -d '#EntryConfig' schema.cue "$f" 2>&1); then
		printf 'FAIL invalid fixture accepted: %s\n' "$f"
		fail=$((fail + 1))
	elif ! grep -qF -- "$expect" <<<"$out"; then
		printf 'FAIL wrong error for %s\n  expected to contain: %s\n  got: %s\n' "$f" "$expect" "$out"
		fail=$((fail + 1))
	else
		pass=$((pass + 1))
	fi
done
printf 'tests/schema: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
