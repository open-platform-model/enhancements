# Design Decisions: Manifest Passthrough: Side-Channel Raw and Kustomize Manifests

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made; numbers are permanent, never reused or renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass. The merged decision keeps the lower number; the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Passthrough lives at the apply layer, not in core or the kernel

**Kind:** contract

**Decision:** Manifest passthrough is implemented in the CLI and operator apply paths. `opmodel.dev/core@v0` and the library kernel are not modified. Side manifests never become `#Component`s, `#Resource`s, or transformer output.

**Alternatives considered:**

- *Model side manifests as a core schema primitive (a new component kind or a `rawObjects` field on `#Module`).* Rejected: drags a Kubernetes-and-Kustomize-specific concept into the platform-neutral core, violating SPEC §4.1 ("the core schema must not assume a particular target"), and forces a `@v0`→`@v1`-class discussion for a feature that needs no schema expressiveness.
- *Render Kustomize inside the library kernel as part of compile.* Rejected: the kernel is pure by constitution: no I/O, no shell, no exec (`library/CONSTITUTION.md` Principle I). Kustomize fundamentally reads a filesystem and can execute code; it cannot live there.

**Rationale:** Both consumers already converge on one artifact (`[]Unstructured`) and one managed apply path. Passthrough output is just more `Unstructured` objects folded into that set. Placing the feature at the apply layer yields zero schema churn and preserves kernel purity, the load-bearing constraint of the whole library.

**Source:** Design review 2026-06-23 (architecture exploration of core/library/cli/opm-operator).

---

### D2: Kustomize is rendered by an embedded library, not by shelling out

**Kind:** policy

**Decision:** Kustomize rendering uses the embedded `sigs.k8s.io/kustomize/api/krusty` Go API. The CLI and operator do not exec an external `kustomize` binary.

**Alternatives considered:**

- *Shell out to a `kustomize` CLI on PATH.* Rejected: non-deterministic across environments (version skew), adds a runtime dependency to the operator image, and reintroduces process/exec surface the operator otherwise avoids.

**Rationale:** Embedding pins the Kustomize version in the Go build, keeps rendering deterministic and reproducible between CLI and operator, and avoids a container/PATH dependency. It also lets us harden options (disable exec plugins) programmatically rather than trusting an external binary's defaults.

**Source:** Design review 2026-06-23.

---

### D3: Side manifests reuse the existing ownership, inventory, and prune machinery

**Kind:** contract

**Decision:** Passed-through objects are folded into the resource list *before* labeling, inventory recording, staging, SSA, and prune. They are stamped with the same OPM ownership labels (including `module-instance.opmodel.dev/uuid`), recorded in `status.inventory`, and pruned on removal exactly like rendered output: one ownership model, one inventory, one prune. A provenance marker records that an object came from the side-channel.

**Alternatives considered:**

- *Track side manifests in a separate inventory / second ownership scheme.* Rejected: produces two disjoint ownership models on one cluster: exactly the orphan-and-drift problem (`01-problem.md`) the feature exists to solve.
- *Apply side manifests but don't prune them (apply-only).* Rejected: leaks resources on release deletion; fails the platform-operator user story.

**Rationale:** The operator's inventory (`opm-operator/internal/apply/prune.go`, `api/v1alpha1/common_types.go`) is already the authoritative prune source. Reusing it means side manifests get drift detection and garbage collection for free, and the integration cost is "stamp + record," not "new subsystem."

**Source:** Design review 2026-06-23.

---

### D4: Available in both the CLI and the operator with identical semantics

**Kind:** contract

**Decision:** Passthrough is wired into both `opm instance build`/`apply` and the operator reconcile, sharing one renderer so a release behaves identically whether driven from a laptop or a controller.

**Alternatives considered:**

- *Operator-only.* Rejected: the CLI is a first-class apply path (`cli/internal/cmd/release/apply.go`); divergent behavior between `opm instance apply` and the operator would surprise users and break local-then-promote workflows.

**Rationale:** Single source of truth for passthrough semantics; consistent UX across drivers.

**Source:** Design review 2026-06-23.

---

### D5: Passthrough is declared via a release-spec side-channel, not woven into the component model

**Kind:** contract

**Decision:** Extra manifests are declared on the release surface as an explicit, labeled side-channel: an `extraManifests` field on the operator's `ModuleInstance`/`ModulePackage` CRD specs and an equivalent CLI input. They are not expressed through `#Component`/`#Trait`/transformer constructs.

**Alternatives considered:**

- *Attach raw manifests to a component (e.g. a `component.extraManifests`).* Rejected: couples the side-channel to the typed component model and to core schema; conflicts with D1's apply-layer placement.

**Rationale:** Matches the user's framing exactly: "extra manifests on the side." Keeps the typed happy path and the untyped escape hatch visibly separate, so "you're off the typed path here" is explicit, not accidental.

**Source:** Design review 2026-06-23; user request 2026-06-23.

Open Questions live in [`07-questions.md`](07-questions.md), the entry's question register.
