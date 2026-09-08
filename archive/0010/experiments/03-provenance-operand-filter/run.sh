#!/usr/bin/env bash
# Runs the experiment. No registry, no network, no state outside this directory.
set -uo pipefail
cd "$(dirname "$0")"

hr() { printf '\n\033[1m%s\033[0m\n' "$*"; }

hr "fixtures vet clean on their own (neither side knows about the other)"
(cd mod && cue vet -c ./demand_11_uses ./demand_11_plain ./demand_10_plain ./demand_10_hourly ./demand_13_default ./demand_11p_uses ./demand_11_desc)
echo "exit: $?"
# No -c on the supply side: a transformer's required body is a SCHEMA, so its
# `schedule!` is deliberately unset. Concreteness is the component's job.
(cd prov && cue vet -c=false ./supply_10 ./supply_11 ./supply_12 ./supply_13 ./supply_10p)
echo "exit: $?"

hr "case 8's build differs from catalog_v1_1 in the description and nothing else"
# Comments and the package clause stripped: what is left is the declaration.
strip() { sed -e 's|//.*||' -e 's/[[:space:]]*$//' -e '/^$/d' -e '/^package /d' "$1"; }
diff <(strip mod/catalog_v1_1_desc/backup.cue) <(strip mod/catalog_v1_1/backup.cue)

hr "go run .   — four comparison scopes x eight skew cases"
go run .
echo "exit: $?"
