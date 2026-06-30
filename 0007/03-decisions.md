# Design Decisions — Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. The log is **append-only** — never remove or renumber existing entries. If a decision is reversed, add a new decision that supersedes it (e.g. "D8 supersedes D3") and leave the original in place.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Passthrough lives at the apply layer, not in core or the kernel

**Decision:** Manifest passthrough is implemented in the CLI and operator apply paths. `opmodel.dev/core@v0` and the library kernel are not modified. Side manifests never become `#Component`s, `#Resource`s, or transformer output.

**Alternatives considered:**

- *Model side manifests as a core schema primitive (a new component kind or a `rawObjects` field on `#Module`).* Rejected: drags a Kubernetes-and-Kustomize-specific concept into the platform-neutral core, violating SPEC §4.1 ("the core schema must not assume a particular target"), and forces a `@v0`→`@v1`-class discussion for a feature that needs no schema expressiveness.
- *Render Kustomize inside the library kernel as part of compile.* Rejected: the kernel is pure by constitution — no I/O, no shell, no exec (`library/CONSTITUTION.md` Principle I). Kustomize fundamentally reads a filesystem and can execute code; it cannot live there.

**Rationale:** Both consumers already converge on one artifact (`[]Unstructured`) and one managed apply path. Passthrough output is just more `Unstructured` objects folded into that set. Placing the feature at the apply layer yields zero schema churn and preserves kernel purity — the load-bearing constraint of the whole library.

**Source:** Design review 2026-06-23 (architecture exploration of core/library/cli/opm-operator).

---

### D2: Kustomize is rendered by an embedded library, not by shelling out

**Decision:** Kustomize rendering uses the embedded `sigs.k8s.io/kustomize/api/krusty` Go API. The CLI and operator do not exec an external `kustomize` binary.

**Alternatives considered:**

- *Shell out to a `kustomize` CLI on PATH.* Rejected: non-deterministic across environments (version skew), adds a runtime dependency to the operator image, and reintroduces process/exec surface the operator otherwise avoids.

**Rationale:** Embedding pins the Kustomize version in the Go build, keeps rendering deterministic and reproducible between CLI and operator, and avoids a container/PATH dependency. It also lets us harden options (disable exec plugins) programmatically rather than trusting an external binary's defaults.

**Source:** Design review 2026-06-23.

---

### D3: Side manifests reuse the existing ownership, inventory, and prune machinery

**Decision:** Passed-through objects are folded into the resource list *before* labeling, inventory recording, staging, SSA, and prune. They are stamped with the same OPM ownership labels (including `module-instance.opmodel.dev/uuid`), recorded in `status.inventory`, and pruned on removal exactly like rendered output — one ownership model, one inventory, one prune. A provenance marker records that an object came from the side-channel.

**Alternatives considered:**

- *Track side manifests in a separate inventory / second ownership scheme.* Rejected: produces two disjoint ownership models on one cluster — exactly the orphan-and-drift problem (`01-problem.md`) the feature exists to solve.
- *Apply side manifests but don't prune them (apply-only).* Rejected: leaks resources on release deletion; fails the platform-operator user story.

**Rationale:** The operator's inventory (`opm-operator/internal/apply/prune.go`, `api/v1alpha1/common_types.go`) is already the authoritative prune source. Reusing it means side manifests get drift detection and garbage collection for free, and the integration cost is "stamp + record," not "new subsystem."

**Source:** Design review 2026-06-23.

---

### D4: Available in both the CLI and the operator with identical semantics

**Decision:** Passthrough is wired into both `opm instance build`/`apply` and the operator reconcile, sharing one renderer so a release behaves identically whether driven from a laptop or a controller.

**Alternatives considered:**

- *Operator-only.* Rejected: the CLI is a first-class apply path (`cli/internal/cmd/release/apply.go`); divergent behavior between `opm instance apply` and the operator would surprise users and break local-then-promote workflows.

**Rationale:** Single source of truth for passthrough semantics; consistent UX across drivers.

**Source:** Design review 2026-06-23.

---

### D5: Passthrough is declared via a release-spec side-channel, not woven into the component model

**Decision:** Extra manifests are declared on the release surface — an `extraManifests` field on the operator's `ModuleInstance`/`ModulePackage` CRD specs and an equivalent CLI input — as an explicit, labeled side-channel. They are not expressed through `#Component`/`#Trait`/transformer constructs.

**Alternatives considered:**

- *Attach raw manifests to a component (e.g. a `component.extraManifests`).* Rejected: couples the side-channel to the typed component model and to core schema; conflicts with D1's apply-layer placement.

**Rationale:** Matches the user's framing exactly — "extra manifests on the side." Keeps the typed happy path and the untyped escape hatch visibly separate, so "you're off the typed path here" is explicit, not accidental.

**Source:** Design review 2026-06-23; user request 2026-06-23.

---

## Open Questions

- **OQ1: Full `kustomize build` vs raw-only for the first cut.** Status: open. The design models both `raw` and `kustomize` sources. Raw-only (a directory/glob of plain YAML, no overlay semantics) is roughly a third of the work and already covers much of the "extra manifests on the side" need; full Kustomize adds the embedded `krusty` dependency, the hardening surface (OQ6), and overlay-path semantics. Resolve by deciding the v1 scope. Would resolve to a `DN` narrowing `#ExtraManifestSource` or confirming both.
- **OQ2: Relationship to enhancement 0005's `#Objects` hatch.** Status: open. 0005 redesigns the *in-pipeline, CUE-authored* untyped object hatch (typed K8s mirror + retained `#Objects`). This enhancement is the *apply-layer, file-based* side-channel. Are they complementary (CUE-native for "I author in OPM"; passthrough for "I already have manifests/kustomize"), or does one subsume the other? Resolve with 0005's author to avoid two accidental doors with overlapping intent. Would resolve to a `DN` plus a `related` cross-ref note.
- **OQ3: Path root for `ModuleInstance` (CUE-native acquisition) sources.** Status: open. `ModulePackage` consumes a Flux artifact the operator already extracts to disk (`internal/source/fetch.go`), so side-manifest paths resolve within that tree. `ModuleInstance` uses CUE-native OCI module acquisition (`internal/moduleacquire/`), which has no equivalent on-disk "release working tree." Where do its `extraManifests` paths resolve from — packaged into the module artifact, a separate referenced source, or `ModuleInstance`-not-supported in v1? Would resolve to a `DN`.
- **OQ4: Templating side manifests against release values.** Status: open (leaning deferred). Should OPM interpolate release config/values into raw/kustomize inputs, or is passthrough strictly verbatim (Kustomize does its own overlaying)? Current design says verbatim (Non-Goal). Confirm deferral or open as a follow-up enhancement.
- **OQ5: Home repo for the shared passthrough renderer.** Status: open. `library/` is ruled out by purity (D1). Options: a small standalone Go module vendored by both `cli` and `opm-operator`; live in one repo and import from the other; or deliberate duplication. Would resolve to a `DN` naming the package location.
- **OQ6: Security/determinism posture for Kustomize in the operator.** Status: open. Kustomize supports exec plugins, `helmCharts` inflation, and generators that read arbitrary files — a footgun inside a controller reconcile loop. Proposal: disable exec plugins by default and likely disable Helm inflation; decide whether any are opt-in via a trusted-mode flag. Would resolve to a `DN` fixing the default `krusty.Options`.
- **OQ7: Collision semantics between a side manifest and a rendered object.** Status: open. If a passed-through object shares GVK+namespace+name with a rendered object, what happens — error, side-manifest-wins (override/patch), or rendered-wins? SSA field ownership makes silent last-writer-wins possible; an explicit rule is safer. Would resolve to a `DN`.
