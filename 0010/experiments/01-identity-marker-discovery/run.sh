#!/usr/bin/env bash
# Runs the experiment. No registry, no network, no state outside this directory.
set -uo pipefail
cd "$(dirname "$0")"

hr() { printf '\n\033[1m%s\033[0m\n' "$*"; }

hr "cue vet ./cat        (default — catches it here: metadata.version is a regular field)"
cue vet ./cat
echo "exit: $?"

hr "cue vet ./mod        (default — MISSES it: the module's incompleteness is inside definitions)"
cue vet ./mod
echo "exit: $?   ← 0, on a tree whose demanded primitives all carry an open version"

hr "cue vet -c ./...     (concrete — names the field, the file and the line)"
cue vet -c ./...
echo "exit: $?"

hr "go run .             (the marker-driven reader)"
go run .
