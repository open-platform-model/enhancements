#!/usr/bin/env bash
cd "$(dirname "$0")"
for d in plain-old plain-new init-old init-new; do
  echo "== $d"; cue vet ./matrix/$d 2>&1 | head -6; echo "exit=${PIPESTATUS[0]}"
done
echo "== initValues readable through the new schema?"; cue eval ./matrix/init-new -e certManager.initValues.controller 2>&1
