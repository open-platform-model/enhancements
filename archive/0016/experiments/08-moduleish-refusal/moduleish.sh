#!/usr/bin/env bash
# Experiment 08: does opm module init's directory-occupancy test (moduleish,
# cli/internal/cmd/module/init.go at cli commit 2370bd6) recognize a generated
# instance package? The three checks are copied verbatim into shell.
moduleish() {
  local dir=$1
  [ -d "$dir/cue.mod" ] && { echo "yes (cue.mod/)"; return; }
  [ -f "$dir/identity/identity.cue" ] && { echo "yes (identity package)"; return; }
  if compgen -G "$dir/*.cue" >/dev/null; then echo "yes (root .cue file)"; return; fi
  echo "no"
}
T=$(mktemp -d)
mkdir -p "$T/empty"
mkdir -p "$T/module/cue.mod" "$T/module/identity"; : > "$T/module/identity/identity.cue"; : > "$T/module/module.cue"
mkdir -p "$T/instance/cue.mod"; : > "$T/instance/cue.mod/module.cue"; : > "$T/instance/instance.cue"; : > "$T/instance/values.cue"
mkdir -p "$T/half"; : > "$T/half/values.cue"
mkdir -p "$T/cuemod-only/cue.mod"
for d in empty module instance half cuemod-only; do printf "%-12s %s\n" "$d" "$(moduleish "$T/$d")"; done
rm -rf "$T"
