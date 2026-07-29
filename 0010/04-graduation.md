# Graduation Criteria — Module and Catalog Identity

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The design is ready to be sliced when:

- Every Open Question is resolved. Check with `task questions:open ID=0010`; walk any remaining rows with the `enhancement-open-questions` skill. **D24 re-opened the blocking set.** Three questions now gate promotion because each changes a shipped shape or a shipped guarantee: **OQ11** (what pins the transformer build — without an answer the entry ships a reproducibility regression against D13), **OQ12** (how provenance is excluded, which decides whether `core`'s primitive shape changes), and **OQ15** (the subscription default, which decides whether one contract bucket can hold several builds of one transformer and render each). **OQ14** should be answered before the catalogs are edited, since it decides what every primitive declares on day one. **OQ13** may ship unresolved if the entry states plainly that the promise is publish-side only. **OQ4** is a runbook question and **OQ8 is deferred by agreement**.
- Every decision (D1..DN) carries the four-field shape with a specific `Source:`.
- `schemas/target.cue` and `schemas/examples.cue` compile (`cue vet ./...` from `schemas/`), and every commented MUST-FAIL case has been confirmed to fail with the error recorded beside it.
- `#definitionName`'s replacement is decided. `core/src/module.cue:27` computes `(#KebabToPascal & {in: name}).out`, which under D8's snake_case `name` produces `Media_server`; either a snake-aware projection lands or the field goes.
- The migration inventory is complete: every published module and catalog path, every live `ModuleInstance`, and the non-module artifacts sharing the namespace (the `opmodel.dev/library/testdata/modules/web-app` fixture, the legacy `…/v1alpha1` paths). The inventory is what makes the manual migration credible, so it is a gate rather than a convenience.
- The relationship to enhancement 0011 is written down as a **preference, not a gate** — landing both in one window halves the relabelling work, but the intermediate state is valid in either order, so neither blocks the other.
- `core/SPEC.md`'s affected sections are identified by line, and the `core-schema-edit` protocol has been read.
- Cross-References in `README.md` names every file path the implementation will touch, and each one exists today.

## accepted → implemented

The design is shipped when:

- `core` carries the new `#Module` / `#Catalog` / primitive shapes, `core/SPEC.md` is co-updated per the `core-schema-edit` protocol, and the major-version event is published.
- `library` enforces the D11 address check at module acquire, at catalog materialize, and at platform subscription, each with a typed error naming both values; the kernel stamps the D9 resolved-coordinate label on the render path.
- **The cross-catalog gate.** A contract defined in one catalog with no transformer of its own, fulfilled by a transformer in a second catalog compiled against a *different* build of the first, renders on a platform subscribed to both. This is what D24 exists to deliver and it is the thing to demonstrate; a fixture pair reproducing `experiments/02`'s cases 1-3 end-to-end through the kernel is the cheapest form of it.
- **The compatibility promise is enforced at both ends.** A catalog build that removes a field inside an `apiVersion` is refused at publish (0011 D9); a module using a field the platform's provider predates fails the render naming that field. Both measured in `experiments/02` at the CUE level — the gate is that they hold through the kernel.
- **An unresolved demand fails (D28).** A component declaring a resource no transformer supplies fails the render, on a platform where every *other* component matches — the case that renders successfully today.
- The D15 prerelease opt-in ships in the **same `core` release** as D13, and is exercised against a prerelease-only catalog — which is what both workspace catalogs are today. A release that lands D13/D14 without D15 cannot materialize `catalogs/opm` at all.
- The D13 diagnostic is implemented on the match path and both of its outcomes are exercised end to end: a demand for a build the subscription does not cover (the message names the demanded version and the versions materialized), and a demand for a primitive no build supplies (the message says so). Neither reads `no matching transformer`.
- `library/opm/compile/module.go` still resolves a module's primitive definitions through the module's own dependency graph, verified by a test that would fail if the module and the platform shared one resolution. Under D13 this test is protecting reproducibility rather than a diagnostic: a shared resolution makes a module demand the platform's build, which the platform *supplies*, so the failure is a silent wrong render rather than a bad error message.
- One render is confirmed **inert across a catalog release**: materialize a platform, render a module, publish a new catalog build into the subscribed major, re-materialize, re-render, and assert the output is byte-identical. This is D13's central claim and nothing else tests it.
- `cli` reads `modulePath` directly, writes the resolved coordinate into `spec.module.{path,version}`, and its address-composition helpers are deleted rather than left unused.
- Every catalog repo has a committed `identity/identity.cue` in the D5 shape, and the `version_override.cue` stamping generator and its publish task are removed — not disabled.
- Every module in `modules/` has a committed `identity.cue`, no authored version, and a snake_case name; hyphenated modules are renamed.
- Fixtures under `library/testdata/` and `cli/tests/e2e/testdata/` are regenerated to the new shape and the old ones deleted, not aliased.
- The live-instance migration has run against the real cluster, and its **positive check** has passed: for at least one migrated instance, a resource removed from the module is confirmed deleted from the cluster. An absence of errors does not satisfy this gate — a skipped prune reports success.
- Rendered output from `cli` and from `opm-operator` for one instance is byte-identical, including the D9 label.
- `config.yaml.implementation.status = complete` with `date`; `history` names the landing milestones; `README.md` carries the implementation-status quote block and a filled `## Deviations from Design`.
