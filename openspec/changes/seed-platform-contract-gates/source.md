# Source note: seed-platform-contract-gates

This is a seed. It records behaviour the CLI and the operator ship today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `platform-contract-gates`. Full seed (16 requirements; T4.3c took out 2 more, see "Left out"). Written 2026-10-11 from `cli` at `09b0b812` and `opm-operator` at `cb97ffb0`.

The requirement text is rewritten at intent level: no Go symbol, flag, file path or Go-side field name. Three kinds of name stay, because a consumer reads them: the published `Platform` resource with its `Ready` and `ContractsFulfilled` conditions and their reasons (the same practice as the seed `platform-module-generation`; ruling of 2026-10-11 07:45: a requirement may name a published Kubernetes kind), the exit codes by their meaning (validation, permission denied) and the words of the report (over-subscribed, comparable, vacuous).

## Sources

All read at the commits named. `cli spec` is `openspec/specs/platform-check/spec.md`; `operator spec` is `openspec/specs/platform-inventory-gate/spec.md`. Code paths are in the repo named in the heading of each block.

### From `cli` (`09b0b812`)

| Requirement here | Source requirement | Code read |
| --- | --- | --- |
| The check reports a platform's contract inventory | cli spec "opm platform check reports a platform's contract inventory" (line 7), first paragraph and scenarios | `internal/platform/check.go:113-193` (the report), `internal/cmd/platform/check.go:95-150` (what runs, what is contacted) |
| Verdicts read vacuous only when nothing is defined | same requirement, the vacuous sentence and its three scenarios | `internal/platform/check.go:117-126`, `check.go:128-133` |
| An unfulfilled contract is reported, not failed | cli spec "An unfulfilled contract is reported and does not fail the command" (line 41) | `internal/platform/check.go:141-150`; exit decided at `internal/cmd/platform/check.go:141` |
| An over-subscribed contract fails the check | cli spec "An over-subscribed contract fails the command" (line 55) | `internal/platform/check.go:162-172`; `internal/cmd/platform/check.go:141-148` |
| An undiscriminated platform fails the check | cli spec "An undiscriminated platform fails the command" (line 79) | `internal/platform/check.go:174-187`; `internal/cmd/platform/check.go:141-148` |
| One failure names every count | cli spec "An undiscriminated platform fails the command", scenario "Both refusals are reported together" | `internal/cmd/platform/check.go:135-148` (one error, `Printed: true`; the colliding count went with the collision rules) |
| The report states which platform it describes | cli spec "The checked platform is resolved like every other command's" (line 98), provenance and the two scenarios that survive (see Disagreements) | `internal/platform/resolve.go:104-123`, `resolve.go:223-231`; `internal/cmd/platform/check.go:207-216` |
| An unbuildable platform fails with a diagnostic | cli spec "A platform that cannot build fails with its build diagnostic" (line 117), first sentence | `internal/cmd/platform/check.go:124-128`, `check.go:184-201`; `internal/config/platform.go:63-82` |
| A refused registry credential exits as permission denied | same requirement, the credential sentences and two scenarios | `internal/cmd/platform/check.go:184-201`; `internal/config/platform.go:89-101`, `platform.go:120-121` (host named only when every declared dependency routes to one) |
| An unreadable inventory fails naming its cause | same requirement, the inventory sentences and their scenarios | `internal/cmd/platform/check.go:130-133`, `check.go:218-236`; `internal/platform/repin.go:13-16` |
| The gates read core's counts and recount nothing | cli spec "An over-subscribed contract fails the command" (the last sentences) and operator spec "An over-subscribed platform is refused at generation" (second paragraph) | `internal/platform/check.go:39-49` (CLI); `internal/controller/platform_inventory.go:38-44` (operator) |

### From `opm-operator` (`cb97ffb0`)

| Requirement here | Source requirement | Code read |
| --- | --- | --- |
| An over-subscribed platform is refused at generation | operator spec "An over-subscribed platform is refused at generation" (line 7) | `internal/controller/platform_inventory.go:74-100`, `:123-149`; `internal/status/conditions.go:140` |
| An undiscriminated platform is refused at generation | operator spec "An undiscriminated platform is refused at generation" (line 35) | `internal/controller/platform_inventory.go:90-95`, `:155-172`; `internal/status/conditions.go:150` |
| One refusal reports every finding | operator specs "An undiscriminated platform..." (last two sentences), "A platform whose enabled entries share..." (precedence paragraph) and "An over-subscribed platform..." (last paragraph) | `internal/controller/platform_inventory.go:67-73`, `:74-100` |
| A refusal recovers when its cause is removed | operator spec "The gate is re-evaluated from current state" (line 68), the recovery half | `internal/controller/platform_controller.go:273-282`, `:286-304` |
| Unfulfilled contracts are reported, never refused | operator spec "Unfulfilled contracts are reported, never refused" (line 82) | `internal/controller/platform_inventory.go:174-206`; `platform_controller.go:211-216`, `:301-304`; `internal/status/conditions.go:157-171` |

## Left out

- "An unreadable inventory is a build failure" (operator spec, line 106): `seed-platform-module-generation` holds it as the scenario "An unreadable inventory fails the build" in "The generated module is validated by building it". The CLI half stays here.
- The reconciler's failure path (operator spec "A refusal preserves the effective package and its status", line 54): the observed generation, the warning event on transition only, the retry class and interval are held by `seed-platform-reconciliation` ("A failure records the observed generation", "Failure events fire on transition only", "Transient failures retry faster than other failures"). What stays with the last good package, its status identity and registry, and its renders (including `PlatformNotReady` while nothing is held) is held by `seed-platform-module-generation` ("Platform status names the package and its registry"; scenario "A failed or refused build keeps the last good package") and row 26. Ruling of 2026-10-11 09:35: this seed keeps the gate reasons and drops its copy. A refused module directory that may stay on disk is a mechanism.
- What wakes the reconciler (operator spec "The gate is re-evaluated from current state", the watches sentence): a regeneration trigger, held by `seed-platform-module-generation` ("Regeneration follows every input and coalesces bursts") and row 6 of T4.1b.
- How the inventory is derived (the count per registry entry, the collision fold, comparability, the three booleans): row 15 `platform-contract-inventory`, from `core`. Requirements here say what the check and the gate do with the findings; the one on counting says only that nothing is recomputed. The rule that a provider is a registry entry with its major, that every transformer of an enabled entry counts, and that a contract counts whether or not an enabled catalog defines it is held by `seed-contract-fulfilment` and `seed-platform-contract-inventory`; 0026:D9 changes it there only (review T4.R14, should-fix 2).
- What the render does on the same findings (it refuses an over-subscribed contract at build time): `seed-single-build-render`, by the ruling of 2026-10-11 07:45. The render's collision refusal was taken out of that seed on 2026-10-11 (14:45), for the reason given in the next item. No requirement here states the render's rule; the sentence in the CLI spec that the render "enforces" the count is not carried over.
- Platform source precedence (argument, flag, cluster Platform, no default) and the provenance line of the cluster source: `platform-resolution` in `cli`. Its precedence was settled by 0021 over 0006 and the owner ruled that no 0006 seed is written (`DECISIONS.md` 2026-10-11 05:50, 06:40 (3)). Only the parts the check itself guarantees stay: the first line names the platform, an argument is the platform checked, a non-module directory is refused.
- The unfulfilled-contract rule that the unmet demand is refused by the render: only the rationale clause stays in "An unfulfilled contract is reported, not failed".
- Behaviour a live entry owns: 0026 OQ11 asks what `opm platform check` and Platform readiness report when several majors of one catalog are admitted (open); 0020 OQ5 asks whether a tombstone diagnostic lands in `opm platform check` (open). Neither changes a shipped sentence here today. Both would MODIFY "The check reports a platform's contract inventory".
- The collision rules (DECISIONS.md 2026-10-11 15:10): the check's requirement "A colliding contract key fails the check" with its colliding section and exit, the operator's requirement "Colliding contract keys are refused at generation" with the reason ContractCollisions, and the clauses that referred to them (the colliding count in the single failure message, the collision-first order of a refusal, the recovery from a collision, the vacuous-verdict case of colliding keys). No archived entry shipped them: they are an interim net recommended by live 0026 OQ17 and shipped by repo changes (core#80, library#147, cli#244, opm-operator#156 and #158, answered 2026-09-30). The inventory still reports collisions as core derives them (`seed-platform-contract-inventory`).
- The skew policy, the singleton rule and the CRD shape: `platform-module-generation`.

## Disagreements between spec and code

The code wins in each.

1. Platform choice. The CLI spec says the check resolves the platform "using the CLI's existing precedence" and scenario "The report states its provenance" speaks of "the configured default". The code has no default: a directory argument, then the platform flag, then the cluster's Platform resource, and with none the check refuses (`internal/cmd/platform/check.go:101-122`, `resolve.go:249-251`, `NoFallback: true`). The cli `platform-resolution` spec (line 207) agrees with the code. The seed keeps the argument and drops the "configured default" scenario.
2. Cluster contact. The CLI spec says the command "SHALL NOT apply, render, or contact a cluster". The code contacts a cluster to read the Platform resource when neither a directory nor the platform flag names the platform (`internal/cmd/platform/check.go:101-110`). The requirement says it applies and renders nothing and no longer says it never contacts a cluster.
3. The core release of the re-pin hint. The CLI spec scenario names core `2.0.0-alpha.11`, `2.0.0-alpha.12` and a fixed `cue mod get` line. The code names the release the kernel was verified against, whatever it is (`internal/platform/repin.go:13-16`), and only when the platform came from a directory the user named (`internal/cmd/platform/check.go:226`). The seed says so and names no release.
4. Discrimination without a row. The operator spec says the gate refuses when the inventory "reports a pair". The code refuses whenever the inventory reads not discriminated, even when it lists no row (`internal/controller/platform_inventory.go:90-95`), so a platform could be refused with an empty pair list. The seed says nothing about the empty case, and states nothing that contradicts the code.

No `sampled:` line: the owner samples later.

## Consolidation (T4.3c, 2026-10-11)

One rule lives in one seed (DECISIONS.md 2026-10-11 10:00). What this seed gave up, and where each rule now lives:

- "An unreadable inventory fails naming its cause": the re-pin hint for a directory the user named is `cli-kernel-render`'s (DECISIONS.md 11:45); the missing field and the first core release are the refusal `platform-artifact` states. This seed keeps the check's validation exit code and "no partial report". The hint scenario now lives in `cli-kernel-render`.
- "The report states which platform it describes": a directory that is not a platform module is refused as `platform-resolution` states; this seed keeps the not-found exit of the check.
- Counting rules and the reconciler's failure path were removed earlier (`fbb6c7b`); the provider map and the reports stay in `platform-contract-inventory`.
