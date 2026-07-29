# Problem Statement — OPM Module Publishing Workflow

> **Stub.** This entry is superseded; its narrative documents were collapsed on 2026-07-29 rather than left describing a design that later decisions retired. The full prior text is in git history.

## What this document covered

Four coordinates an OPM author sets independently — `metadata.modulePath`, `metadata.name`, `metadata.version`, and the `cue.mod/module.cue` `module:` path plus the release tag — with nothing binding them, so they drift. Two dimensions of one gap:

- **Addressing.** Code holding a `*module.Module` cannot reconstruct the reference needed to import it: the registry path lives in `cue.mod/module.cue`, which the schema cannot see, and no single transform recovers it. `zot-registry-ttl` publishes at `…/zot_registry_ttl`; `web-app` publishes at `…/web-app` with package `web_app`.
- **Version.** Nothing checks that `metadata.version` equals the tag of the artifact carrying it, and the failure is silent: the CLI deploys the artifact it fetched but records a different version, so after a handoff the operator reconciles a *different artifact* indefinitely with `Ready: True` and every gate green.

`#Catalog` carried the same gap in a different shape — no `name` field, so addressing is degenerate, but the version half is acute because `version!` defaulted to `0.0.0-dev` and `#Catalog` stamps its version onto every transformer FQN, so the failure surfaces as an unattributed `no matching transformer`.

Two measurements gave the entry its urgency, and both are reproduced in the successors:

- **The version invariant was already false across the published fleet** (2026-07-25, workspace registry): jellyfin `v2.0.1` and `v2.0.2` both declare `2.0.0`, seerr `v1.0.2` declares `1.0.0`. Only the `.0` of each minor line is honest. The `modules` repo's checksum-driven `publish:smart` never reads or writes `metadata.version`, so drift is the *output* of the flow and accumulates with every publish.
- **A derivable rule is not an enforced one.** This entry's own `schemas/target.cue` always specified `depVersion: "v" + version`, yet the shipped `CanonicalModuleRef` returned the bare version — so every `ModuleInstance` the CLI had written was unresolvable by the operator, undetected until `opm instance handoff` first had to re-read what the CLI wrote (fixed 2026-07-20).

## Where it went

The problem statement and both measurements are **restated inline** in the successors, dated, rather than cross-referenced — neither requires reading this entry:

- **[0010 — Module and Catalog Identity](../0010/)** — what an artifact's identity is and how it reaches the artifact's own bytes.
- **[0011 — Module and Catalog Publishing](../0011/)** — the commands that write it and the registry it goes to.

## What still lives here

`experiments/` and `research/` are untouched and remain valid evidence — they are the reason this entry was superseded rather than deleted.
