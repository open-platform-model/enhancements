#!/usr/bin/env bash
# 07-open-tail: unify every input case with every block-shape variant and
# print the verdict with the first line of each error. cue v0.17.1.
#   closed  - #ModuleFileCustom as first drafted (closed, four required fields)
#   oldopen - an older core whose block shape is only `...`
#   open    - the drafted shape plus `listing?: #Listing` and `...`
set -u
cd "$(dirname "$0")/schema"
for v in closed oldopen open; do
  for c in cases/*.json; do
    out=$(cue vet -c -d '#ModuleFileCustom' "./$v/" "$c" 2>&1 | grep -v '^ ')
    printf '%-8s %-17s %s\n' "$v" "$(basename "$c" .json)" "${out:-PASS}" | tr '\n' ' '
    echo
  done
done
