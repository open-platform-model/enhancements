#!/usr/bin/env bash
# Demonstrates: schema vet, Markdown generation from CUE, freshness check, and
# the two schema invariants refusing bad policy files.
set -u
cd "$(dirname "$0")"
echo "== 1. vet the policy package"; cue vet ./ && echo ok
echo "== 2. render POLICY-module.md from CUE"; cue eval ./ -e render.module --out text > POLICY-module.md && wc -l POLICY-module.md
echo "== 3. freshness check (regenerate and diff)"; diff <(cue eval ./ -e render.module --out text) POLICY-module.md && echo fresh
echo "== 4. negative: must without reason (expect error)"; cue vet -c ./fail/must_without_reason 2>&1 | head -3
echo "== 5. negative: gate without enforcer (expect error)"; cue vet -c ./fail/gate_without_enforcer 2>&1 | head -3
echo "== 6. negative: strength word disagrees with field (expect error)"; cue vet -c ./fail/strength_mismatch 2>&1 | head -3
