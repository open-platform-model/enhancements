#!/usr/bin/env bash
# Runs the experiment. No registry, no network, no state outside this directory.
set -uo pipefail
cd "$(dirname "$0")"

hr() { printf '\n\033[1m%s\033[0m\n' "$*"; }

hr "fixtures vet clean on their own (neither side knows about the other)"
(cd mod && cue vet -c ./demand_11_uses ./demand_11_plain ./demand_10_plain ./demand_10_hourly ./demand_13_default ./demand_11p_uses)
echo "exit: $?"
# No -c on the supply side: a transformer's required body is a SCHEMA, so its
# `schedule!` is deliberately unset. Concreteness is the component's job.
(cd prov && cue vet -c=false ./supply_10 ./supply_11 ./supply_12 ./supply_13 ./supply_10p)
echo "exit: $?"

hr "the same MAJOR-keyed FQN on both sides, with the build readable inside the value"
(cd prov && cue eval ./supply_10 -e 'transformer.requiredResources')

hr "go run .   — the always-unify rung, three scopes x seven skew cases"
go run .
echo "exit: $?"
