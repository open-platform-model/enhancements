#!/usr/bin/env bash
# Demonstrates that no single cue.Value.Subsume call implements enhancement 0010
# D27, that a three-rule field-wise walk does, and that the walk is level-aware
# per D34. Self-contained: no registry, no network.
set -u
cd "$(dirname "$0")"
exec go run .
