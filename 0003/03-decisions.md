# Design Decisions — OPM Module Publishing Workflow

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, …) and recorded as they are made. **Numbers are permanent** — never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes. The *text* under a number states what is true now: a reversal is recorded as its own `DN` while the design is in motion, then woven into the decision it changes at the next compaction pass — the merged decision keeps the lower number, and the vacated number keeps a one-line tombstone. See the `enhancement-compaction` skill.

Each decision uses the same four-field shape: Decision, Alternatives considered, Rationale, Source.

---

## Decisions

### D1: Canonical module registry reference is derived from metadata via `nameSnakeCase`

**Decision:** A module's canonical CUE registry reference is a pure function of its `#Module.metadata`: registry path = `metadata.modulePath + "/" + metadata.nameSnakeCase`, major qualifier = `vMAJOR(metadata.version)`, dep version = `v<version>`, and the module's CUE package name = `metadata.nameSnakeCase`. This mapping is the single normative rule; both the cli publish check and the library import helper mirror it.

**Alternatives considered:**

- Derive the path leaf from `metadata.name` directly (kebab). Rejected: `name` is not a valid CUE identifier when it contains hyphens, so it cannot serve as a package name, and real modules publish under the snake form (zot at `…/zot_registry_ttl`).
- Apply an ad-hoc transform (snake-case) only at the consumption site (library render). Rejected: it is a guess that cannot be guaranteed correct (the registry path lives in `cue.mod`, which the consumer cannot constrain), and it leaves authoring unconstrained so drift persists.

**Rationale:** `nameSnakeCase` is derived from `name` and is identifier-safe, so it can be both the package name and the path leaf without drift. Making the reference a pure function of metadata is what lets a loaded `*module.Module` be re-imported and lets the render path converge the synth and authored paths.

**Source:** User decision 2026-06-17 (combine `nameSnakeCase` with a future publish workflow in library + cli).

### D2: `nameSnakeCase` is added to `core`'s `#Module.metadata` as a derived field

**Decision:** `core` exposes `metadata.nameSnakeCase` on `#Module` — the snake_case projection of `name` (`#KebabToSnake`), validated by `#SnakeNameType`. Derived from `name`; authors never set it.

**Alternatives considered:**

- Compute the snake form in each consumer (library, cli) independently. Rejected: re-implementing `strings.Replace(name, "-", "_")` in N places invites divergence and gives no single authoritative projection.
- Add a free-standing `registryLeaf` identity field authors set by hand. Rejected: another author-set field is exactly the drift source this enhancement removes; a *derived* projection cannot disagree with `name`.

**Rationale:** A schema-level derived projection gives every consumer one deterministic, always-present identifier to build the canonical reference on, and keeps it in lockstep with `name`.

**Source:** User decision 2026-06-17; landed in `core/src/{types,module}.cue` + `core/SPEC.md` the same day.

### D3: `metadata.version` MUST equal the version of the artifact carrying it

**Decision:** A module's declared `metadata.version` and the release tag it is published under are the same value. `schemas/target.cue` states this as `#PublishedModuleRef`, which unifies the derived `depVersion` (`"v" + metadata.version`) with the artifact coordinates in hand, so a disagreement is a unification conflict rather than an accepted condition. The invariant is checked in both directions: a publisher unifies the tag it is about to write, a consumer unifies the reference it fetched by.

**Alternatives considered:**

- Leave `metadata.version` as author intent and treat the tag as the only truth. Rejected: `metadata.version` is not decorative — it feeds `fqn` → `module.uuid` → `instance.uuid` → the identity label on every rendered resource, it becomes `ModuleInstance.spec.module.version` (what the *operator* later resolves), and `synth/render.go:62` derives the synthesized import's major line from it. If it may lie, all three are unsound.
- Remove `metadata.version` from the module body and take the version only from the tag, as Go and CUE do. Rejected: FQN and UUID are computed *inside CUE at evaluation time*, and CUE cannot observe the tag it was published under. The version has to be in the file, which is precisely why the file and the tag agreeing is a structural obligation of this design rather than a convention.
- Check only at publish. Rejected — see D6.

**Rationale:** Without this, a stale stamp produces a silent version regression: the CLI deploys the artifact it fetched but records a different version in the CR, and after a handoff the operator reconciles that other version indefinitely with every gate reporting green. Making the two the same value is what lets any consumer trust `metadata` as a statement about the artifact in hand.

**Source:** User decision 2026-07-20, following the `spec.module.version` prefix incident recorded in `01-problem.md`.

### D4: Publish **derives** the coordinates from metadata; it does not **stamp** them into the artifact

**Decision:** `opm module publish` reads `metadata` and uses it to determine the registry path and release tag. It does not rewrite `metadata.version` inside the artifact it pushes. The module file is authoritative; publish reads it.

**Alternatives considered:**

- Stamp the version into the artifact at publish (inject `metadata.version` from a flag or the tag). Rejected: the published bytes would then differ from the source tree, which breaks reproducibility (the artifact cannot be rebuilt from source) and breaks the local-directory-vs-registry byte identity that enhancement 0006's render-parity check (D30) proves and that the handoff digest gate rests on.
- Take the tag from a side file (`versions.yml`, today's mechanism). Rejected: that is the third source of truth this enhancement exists to remove.

**Rationale:** Deriving keeps exactly one authored version in exactly one place, and keeps artifact bytes equal to source bytes. It is also the conventional shape — `package.json`, `Cargo.toml` — for ecosystems that carry a version inside the package, which OPM must because of D3's rationale.

**Source:** User decision 2026-07-20 ("We should not use stamp but derive").

### D5: A bare import binds; no `:packageName` qualifier is required

**Decision:** Under D1 the registry path leaf equals `nameSnakeCase` equals the CUE package name, so `import "path@vN"` resolves without qualification. The library helper emits the bare `importPath`. `importQualified` is retained in `schemas/target.cue` for diagnostics and for reporting a non-conforming module's actual coordinates.

**Alternatives considered:**

- Always emit the qualified `path@vN:pkgName` form. Rejected as unnecessary once the convention holds, and it obscures the very drift the convention removes.

**Rationale:** Verified empirically rather than assumed: enhancement 0006's C2 slice established that "a module's declared `cue.mod` path AND root package name must both follow `nameSnakeCase` for kernel synthesis to resolve the self-import," and the `podinfo` fixture (package `podinfo`, path `…/podinfo@v0`) renders through the kernel unqualified.

**Source:** Resolves OQ2. Evidence from enhancement 0006 slice C2 (2026-07-18) and the C3 handoff e2e (2026-07-20).

### D6: The invariant is enforced at **acquire**, in `library`; publish-side derivation is necessary but not sufficient

**Decision:** The registry acquisition path in `library` verifies a fetched module's metadata against the coordinates it was fetched by, and refuses on mismatch. `opm module publish`'s derivation (D4) is retained as the producing-side half, but the guarantee consumers rely on lives at acquire.

**Alternatives considered:**

- Enforce only at publish (the original shape of `02-design.md` step 3). Rejected: `cue mod publish` exists, will keep working, and every module published to date bypassed OPM tooling entirely. Enforcement a publisher can route around gives a consumer nothing to rely on.
- Best-effort consumption with the recorded fetched reference as a fallback. Rejected: it makes a wrong-artifact condition survivable and therefore invisible, which is the failure mode D3 exists to eliminate.

**Rationale:** Acquire is the one point every actor passes through and no publisher controls. Placing the check on `kernel.AcquireModuleFromRegistry` means the CLI and the operator inherit identical behaviour from a single implementation — the same property that made the `spec.module.version` bug invisible when each side was only tested against its own idea of the contract.

**Source:** User decision 2026-07-20 (agreement on the three-piece ordering: verify-on-acquire first, publish-derives second, `#Catalog` third). Resolves OQ5.

### D7: `opm catalog publish` ships here, alongside `opm module publish`

**Decision:** Catalog publishing is in scope for this enhancement. `opm catalog publish` derives a catalog's registry coordinates and release tag from its `#Catalog.metadata` exactly as `opm module publish` does for `#Module`, and D3's version-agreement invariant plus D6's acquire-side verification extend to `#Catalog`. The `version!: #VersionType | *"0.0.0-dev"` default in `core/src/catalog.cue` is the catalog-side instance of the same silent-drift exposure and is closed by the same mechanism.

**Alternatives considered:**

- Specify the invariant here and implement it in enhancement 0001's catalog repackage (OQ7's original framing). Rejected: it splits one code path across two entries and leaves the implementing entry free to diverge from the specifying one — the exact "derivable by convention, drifts from its implementations" failure `01-problem.md` documents.
- Leave catalog publishing wholly to 0001. Rejected: 0001 is `implemented`. Reopening a graduated entry to add a CLI command inverts the lifecycle, and the derivation, the version check, and the local-override gate (D8) are the same code with a different artifact type.

**Rationale:** `#Module` and `#Catalog` publish through one pipeline that differs only in which artifact it decodes and which metadata block it reads. Building them together yields one implementation with two entry points rather than two near-duplicates that drift. The catalog half is also the more urgent of the two in one respect: catalog FQNs embed the catalog version and transformer matching keys off it, so a placeholder version surfaces as "no matching transformer" — a diagnostic that names neither the catalog nor the version at fault.

**Source:** User decision 2026-07-25. Resolves OQ7.

### D8: Publish never honours `cue.mod/local-module.cue`, and refuses while replacements exist unless explicitly allowed

**Decision:** `opm module publish` and `opm catalog publish` always resolve dependencies as published. `replaceWith` entries in `cue.mod/local-module.cue` are **ignored** — never honoured, never baked into the artifact. When the artifact being published carries any replacement, publish reports each one together with the registry version that will be resolved in its place, and refuses to proceed unless an explicit allow flag is passed.

**Alternatives considered:**

- Publish silently, as raw `cue mod publish` does today. Rejected: CUE strips `local-module.cue` at publish, so the author validated against a local checkout while the artifact resolves against something else. The divergence is invisible at precisely the moment it becomes permanent.
- Warn and proceed. Rejected: a warning in a CI log is not a gate. The whole premise of D6 is that a check a publisher can walk past gives a consumer nothing.
- Honour the replacements. Rejected as unimplementable: a local directory path is not resolvable by any consumer, and a fork replacement would make the published dep set differ from the declared one.

**Rationale:** This is D4 (derive, never stamp) applied to the dependency graph rather than to the version. The published bytes must resolve to what a consumer will resolve, and the one moment where an author can be told that their tested resolution and their published resolution differ is the publish itself. Ignoring rather than honouring keeps the artifact honest; refusing rather than warning keeps the author informed.

**Source:** User decision 2026-07-25.

### D9: The central registry is the source of published modules, and module paths are owner-scoped beneath it

**Decision:** OPM operates a central registry that **hosts** published modules, rather than an index that points at modules hosted elsewhere. A module's `metadata.modulePath` is owner-scoped under the central domain — `opmodel.dev/m/<owner>` — so a module's canonical registry path under D1 becomes `opmodel.dev/m/<owner>/<nameSnakeCase>`. The reserved `m` segment separates module space from catalog space (`opmodel.dev/catalogs/<name>`, already in use) and from schema space (`opmodel.dev/core`). Owner-scoping is what makes a published name unique, so no registry-side ownership table is required for uniqueness. The registry implementation itself, and discovery over it, belong to a follow-on entry.

**Alternatives considered:**

- **Central registry as index only** — authors publish under their own domains, Go-style, and the central registry merely records what exists. Rejected: CUE resolves a module path to a host through the prefix→host mapping in `CUE_REGISTRY`, with no per-domain autodiscovery. A module published at `example.com/modules/foo` is therefore unresolvable for every consumer who has not first edited their own registry configuration. "Publish anywhere" and "resolves for everyone with no setup" are not simultaneously available under that resolution model, and the second is the property this project is optimising for.
- **Flat namespace under the central domain** (`opmodel.dev/modules/<name>`, today's shape). Rejected: a flat global namespace has no owner. The first publisher of a common name holds it permanently, and nothing distinguishes a vendor's module from a third party's fork of it.
- **Owner-scoped with a longer segment** (`opmodel.dev/modules/<owner>/<name>`). Not chosen, but the difference is cosmetic — `m` is shorter and more cryptic, a segment is reserved either way. Recorded so the cost of reversing this specific spelling is known to be small, unlike the cost of reversing owner-scoping itself.

**Rationale:** Hosting rather than indexing is what makes the consumer experience zero-setup, because the CLI ships the central mapping as its default `CUE_REGISTRY` value and every canonical path resolves against it out of the box. Owner-scoping then supplies uniqueness structurally: `<owner>` is the disambiguator, so two people may both publish `postgres` without a land grab and without the registry needing to arbitrate. The reserved segments matter beyond aesthetics — they make the namespace *partitionable*, which is what lets tooling tell a module from a catalog from a schema by path alone. That question is asked constantly (which deps of this module are catalogs? which repositories in the registry are modules?) and answering it by path is cheaper and more reliable than fetching and decoding each artifact to find out.

**Source:** User decision 2026-07-25.

### D10: A catalog carrying `cue.mod/local-module.cue` cannot be published at all

**Decision:** For `opm catalog publish`, the presence of a `cue.mod/local-module.cue` file in the module being published is an **unconditional refusal**. There is no allow flag, no `--force`, and no override. D8's explicit-allow escape hatch survives for `opm module publish` only; this decision narrows D8's catalog half and supersedes it there. The check is on the file's presence, not on whether its `replaceWith` entries are currently resolvable — a catalog source tree that is set up for local development is not a publishable tree.

**Alternatives considered:**

- **Uniform treatment with modules** — keep D8's allow flag on both commands. Rejected: the blast radius is asymmetric in kind, not just in degree. D8's flag lets a publisher knowingly accept a divergence scoped to one artifact and its direct consumers. A catalog's divergence propagates through `#Catalog`'s pattern constraint into the FQN of every transformer it ships, and therefore into the matcher key space of every module rendered against it — a scope no single publisher is in a position to assess at the moment they would be pressing the flag.
- **Warn and proceed.** Rejected for D8's reason, with more force here: the resulting failure is `no matching transformer`, which names neither the catalog, nor the version, nor the replacement that caused it.
- **Refuse only when a replacement is unresolvable, or only for catalog-typed dependencies.** Rejected: it makes publishability depend on the state of a developer's working tree, so the same commit publishes or refuses depending on what happens to be checked out next to it. Presence is the only condition that is stable across machines.

**Rationale:** Experiment 01 measured that a catalog resolved from a local checkout and the same catalog resolved from the registry produce different primitive FQNs, and experiment 04 measured that a replacement chain silently drops its inner hop — so a catalog developed against local replacements has been validated against a key space that no consumer will ever see, and neither CUE nor `cue vet` reports this on either tree. An escape hatch is defensible where the person holding it can scope the damage. For catalogs they cannot, so the hatch is removed rather than documented.

**Source:** User decision 2026-07-25.

### D11: Acquire-side verification ships without grandfathering; non-conforming published artifacts stop loading

**Decision:** When D6's acquire-side check lands, it applies to every artifact regardless of when it was published. Artifacts whose in-artifact `metadata.version` disagrees with the tag carrying them — `jellyfin` `v2.0.1` / `v2.0.2`, `seerr` `v1.0.2`, and whatever else the inventory turns up — become unloadable on that day. They are fixed by republishing under conforming versions, not by an exemption list, a compatibility window, or an adopt-in-place path.

**Alternatives considered:**

- **Grandfather by publish date or by allowlist.** Rejected: an exemption list is a second source of truth about which artifacts are permitted to lie, and exemption lists outlive the migrations that create them.
- **Warn for a transition window, error afterwards.** Rejected on D6's own premise — a warning is not a gate — and because the only thing that would make the window real is an end date that nobody is accountable for.
- **Adopt in place: record the fetched tag on `*module.Module` and treat `metadata.version` as advisory.** Rejected. This is OQ3's "record" option promoted from a safety net to a workaround: it makes the wrong-artifact condition survivable, and therefore permanently invisible, which is precisely what OQ5 rejected when D6 resolved it.

**Rationale:** The affected set is small, privately held, and enumerable today; the remedy is a republish. The cost of the alternative is that the invariant is conditional forever, which makes it not an invariant. The set also only grows — every publish under the current `publish:smart` flow adds another non-conforming artifact — so this is the cheapest it will ever be. The breakage is loud and lands on the maintainer of the fleet rather than on a consumer, which is the correct direction for it to point.

**Source:** User decision 2026-07-25, on evidence recorded in `01-problem.md ### Evidence: the version invariant is already false across the published fleet`.

### D12: `version set` is the only writer of `metadata.version`; publish takes no version input

**Decision:** Version *authoring* and version *publishing* are separate commands.

`opm module version set <semver>` is the only thing in OPM tooling that writes `metadata.version`. It edits the declaration in place, in the module's own committed source, so the tree it leaves behind is the tree that gets published. It is **idempotent** — setting the version it already has is a no-op. On a major change it also updates the coupled `@vN` suffix in `cue.mod/module.cue`, because `#CanonicalModuleRef` derives `major` from the version and the two declarations must not drift apart.

`opm module publish` accepts **no version input of any kind** — no `--version`, no override, no assertion flag. It derives the release tag from `metadata.version` as read from the source tree it is publishing, and that is its only source for it.

The same split applies to catalogs (`opm catalog version set`), per D7's one-pipeline-two-artifact-types rule. D12 fixes the *command shape*; where a catalog's version is authored remains OQ13's question.

**Alternatives considered:**

- **`--version` as a tag-only override** (OQ6 option (c)). Rejected by measurement, not by argument: it is what `modules/Taskfile.yml`'s `publish:smart` does, and `01-problem.md` records the fleet it produced.
- **`--version` that writes `metadata.version` and then publishes, in one command** (OQ6 option (b), fused). Rejected: the commit belongs *between* deciding a version and pushing an artifact, and fusing the two removes the seam it goes in. An artifact whose `metadata.version` exists in no commit cannot be traced back to the source that produced it — and `metadata.version` is the artifact's identity, so it must never name a state absent from git.
- **`--version` as an assertion** (OQ6 option (a)) — accepted only when it matches, never writes. Rejected as unnecessary rather than as wrong: an idempotent `version set` already subsumes it. CI calls `version set` unconditionally; a matching version is a silent no-op, a differing one produces a reviewable diff at the commit step. Keeping the flag would also overload one spelling with two incompatible meanings — given `publish --version 1.2.3` against a source saying `1.2.0`, neither "bump it" nor "refuse" is inferable from the invocation, and either choice surprises half the callers.
- **Temp-copy stamping** — publish copies the tree, edits `metadata.version` in the copy, pushes the copy, leaves source untouched. Rejected on two counts. Artifact bytes stop equalling source bytes, which is D4 directly. And the committed source keeps a version the published artifact does not carry, so a module rendered from a local checkout computes a different `fqn` → `module.uuid` → `instance.uuid` than the same module rendered from the registry — putting a **different identity label on every rendered resource**, which the operator's prune guard and the CLI inventory both match on. That is experiment 01's measured catalog divergence transposed to modules: same mechanism (an identity computed in CUE from a value two trees disagree about), different symptom (`no matching transformer` there, a mismatched instance UUID here). It is reachable through the sanctioned `local-module.cue` dev workflow, and it breaks the local-vs-registry byte identity that 0006's handoff digest gate rests on.

**Rationale:** The strongest form of D4 is not a validated flag but an absent one. A publish command that takes no version input has **no surface through which a wrong version can be expressed** — not discouraged, not checked, not representable. Every alternative above is an attempt to make a lie detectable; removing the parameter makes it unsayable, which is a stronger guarantee than any validation and needs no test to defend it.

Splitting the commands also puts the commit seam where it belongs. `version set` → review the diff → commit → `publish` is the correct sequence for a release, and it is the sequence the tooling should make natural rather than one a caller has to reconstruct around a convenience flag. The cost is one extra line of shell in the single scenario where the commit genuinely does not matter — an ephemeral CI checkout publishing a `0.0.0-dev.<sha>` build, where the tree is discarded either way.

**Source:** User decision 2026-07-26, closing OQ6. Corroborated after the fact by `research/prior-art-version-agreement.md` (2026-07-26): the authoring/publishing split is convergent prior art rather than a novel design — npm ships it as `npm version` (writes `package.json`, commits, tags) plus `npm publish` (reads it), and `cargo publish` likewise takes no version argument, leaving `Cargo.toml` authoritative.

### D13: `#Module.metadata.version` is removed entirely; module identity carries no version

**Decision:** `#Module.metadata.version` is deleted from `core`. A module's source declares `modulePath` and `name` and nothing about its version. The full version exists **only** as the coordinate an artifact was published at and resolved by — the OCI tag — with the major carried in the CUE module path (`opmodel.dev/modules/jellyfin@v2`) where CUE already puts it. `metadata.fqn` is redesigned so it does not interpolate a version; its replacement shape, and the consequences for `module.uuid` / `instance.uuid`, are deliberately deferred to OQ15.

This follows CUE's own model rather than layering on top of it. `cue.mod/module.cue` declares `module: "example.com/foo@v0"` — major only — and `cue mod publish <version>` supplies the rest. Go made the same call. OPM's `metadata.version` was an addition that duplicated a coordinate both systems deliberately keep out of source, and every failure this enhancement documents traces back to that duplication.

**What this supersedes.** For `#Module` only — the catalog side is untouched pending OQ13:

- **D3 (version agreement) becomes vacuous.** With one version in the system there is no second value to agree with it.
- **D6's version half becomes vacuous**; its *path* half survives — an artifact must still live where `metadata.modulePath` says it does.
- **D11 is retired.** The non-conforming artifacts it was going to break (jellyfin `v2.0.1`/`v2.0.2`, seerr `v1.0.2`) are non-conforming only against a field that no longer exists.
- **D12 is reversed for modules.** `opm module version set` has nothing to write, and `opm module publish` must take the version as an argument again — from a tag, a release process, or a flag — because it is the only place a version can come from. D12's guarantee is not lost, it is obtained more cheaply: the reason no lie can be expressed is no longer an absent parameter but an absent second value. D12 stands unchanged for catalogs while OQ13 is open.

D4 (derive, never stamp), D8 and D10 (local-override gates), and D9 (owner-scoped central registry) are unaffected.

**Alternatives considered:**

- **Keep the field and enforce agreement (D3 + D6 + D12, the design as it stood).** Rejected as policing a problem rather than removing it. It requires a publish-side derivation, an acquire-side check, a `version set` command, a migration of the existing fleet, and a permanent invariant that every future tool must respect — all to keep two values equal that need not both exist.
- **(C) Keep `version` as a declared-but-never-authored field, injected at acquire from the resolved tag.** Genuinely viable and was the recommendation before this decision: it preserves the metadata-shaped surface and makes agreement true by construction. Rejected because it keeps `fqn`, `uuid`, and the shape gate depending on a field whose value exists only after a registry fetch — so a module read from disk has no identity, and the field survives as a vestige that authors will eventually write to anyway. If `fqn` must be redesigned regardless, the field earns nothing.
- **(B) A hidden `_version` written at publish.** Rejected on two independent grounds. Writing it at publish is stamping bytes into the artifact that do not exist in source — D4, and the mechanism experiment 01 measured producing local-vs-published divergence. And `core/SPEC.md:304` records that a field which is not a *declared, permitted* member of the closed `#Module` breaks re-unification into `#ModuleInstance.#module` with "field not allowed" — a bug that was invisible to `cue vet` because a standalone module is only closed once.

**Rationale:** The version-agreement problem exists because OPM put a full version inside module identity. Go and CUE both keep it out, and neither has this class of bug. Removing the field deletes the problem rather than defending against it: no drift to detect, no fleet to migrate for version reasons, no invariant for future tooling to uphold.

It also removes a latent failure that fixing the drift would have *activated*. Because `fqn` interpolates `version`, a genuinely-moving version changes `module.uuid` → `instance.uuid` → the `module-instance.opmodel.dev/uuid` label on every rendered resource. `opm-operator/internal/reconcile/moduleinstance.go:308` repopulates `Status.InstanceUUID` from each new render, and `internal/apply/prune.go:107` **skips** any delete whose live label disagrees with that owner UUID. So under D3, every upgrade would silently orphan whatever the new version removed. The drift has been masking this the whole time — `metadata.version` never moved, so the uuid never moved.

**Source:** User decision 2026-07-26. Blast radius documented in `05-risks.md ## Blast Radius — removing `metadata.version` (D13)`; prior-art context in `research/prior-art-version-agreement.md`.

### D14: The resolved-coordinate labels are written by code, not by the schema

**Decision:** `module.opmodel.dev/version` — and any future label naming a *resolved coordinate* rather than a property of the module definition — is stamped by the consumers that performed the resolution: `library`'s render path, the `cli`, and `opm-operator`. `core/src/module.cue:36` stops declaring it when D13 deletes the field it interpolates. The label's value is the version of the artifact that was actually fetched, so it says what it always appeared to say and, for the first time, says it truthfully.

All three writers MUST produce the identical label for the same acquisition. The CLI-rendered and operator-rendered output of one instance are compared byte-for-byte by enhancement 0006's render-parity work and its handoff digest gate, so a label that differs by writer would break that comparison rather than merely being untidy.

**Alternatives considered:**

- **Drop the label entirely.** Rejected: selecting deployed resources by module version is a real operational need, and D13 removing a field is not a reason to remove a capability.
- **Keep the label by keeping a version field in `#Module`.** Rejected — that is variant (C), already rejected by D13.
- **Inject the resolved version into the module value before rendering, so CUE can stamp the label as it does today.** Rejected on `core/SPEC.md:304`'s recorded bug: a field that is not a declared permitted member of the closed `#Module` fails re-unification into `#ModuleInstance.#module` with "field not allowed". It would also put a fetch-derived value back inside module identity, which is the thing D13 removed.

**Rationale:** The label describes an *acquisition*, not a definition — which artifact was resolved, not what the module is. Core's schema states what a module *is*; the code that fetched it is the only actor that knows which one it got. Placing the write where the knowledge is removes the last consumer of `metadata.version` without losing the output, and it means the label is sourced from the same value that goes into `spec.module.version` rather than being independently re-derived.

**Source:** User decision 2026-07-26.

### D15: The resolved-coordinate label is stamped by the kernel, not by each frontend

**Decision:** D14's label write lands **once, in `library`'s kernel**, on the render path both frontends already go through. The `cli` and `opm-operator` inherit it rather than each implementing it. This narrows D14, which said the label is written by "library, cli, and operator" — three writers was the requirement (the label must exist wherever rendering happens), not the design.

**Alternatives considered:**

- **Each frontend stamps its own.** Rejected: it makes byte-identical output a coordination agreement between two codebases that release independently, and the only thing detecting a divergence would be the handoff digest gate failing after the fact, naming a digest rather than a label.
- **Stamp it in the apply path rather than the render path.** Rejected: the label must be present in rendered output for the CLI's dry-run, diff, and digest to see it, all of which run before anything is applied.

**Rationale:** This is D6's argument on a different surface. Placing the write on the path both actors traverse means they cannot disagree, rather than requiring that they agree — and D14's parity constraint stops being a rule someone must remember and becomes a property of there being one implementation. The kernel is also the only layer that holds both halves at once: the resolved coordinate (from `AcquireModuleFromRegistry`'s own parameters) and the rendered resources it is stamping.

**Source:** User decision 2026-07-26.

### D16: `metadata.modulePath` becomes the full CUE module path, and `fqn` is that path

**Decision:** `#Module.metadata.modulePath` carries the module's **complete CUE module path including the major suffix** — `opmodel.dev/modules/jellyfin@v2` — rather than the bare prefix `opmodel.dev/modules`. `metadata.fqn` is then that same string, and `uuid: SHA1(OPMNamespace, fqn)` is unchanged in formula while gaining a version-free, major-bearing input. `instance.uuid` is unchanged. This resolves OQ15 by taking candidate (d).

Consequences that follow directly:

- **The major is back in identity, and only the major.** Two majors of a module are distinct identities, exactly as CUE and Go treat them; patch and minor upgrades keep one identity, so the `module-instance.opmodel.dev/uuid` label is stable across ordinary upgrades and the prune guard keeps working.
- **`#ModulePathType` gains the optional `@vN` suffix** (`core/src/types.cue:20`), and `#ModuleFQNType` (`:semver` tail) is either retired or redefined as `#ModulePathType`.
- **D1's registry-address derivation mostly dissolves.** The declared path already *is* the registry address, so `modulePath + "/" + nameSnakeCase` recombination disappears — `cli/pkg/module/module.go:74` and the library helper stop composing an address and start reading one.
- **D1's constraint becomes checkable inside one field.** "The path leaf equals `nameSnakeCase`" is now a statement about `modulePath` alone rather than a relationship between two independently-authored fields, so the drift D1 exists to prevent becomes locally expressible.
- **`name` / `nameSnakeCase` become display and package-name projections.** They still exist; they are no longer address inputs.
- **The authored path still duplicates `cue.mod/module.cue`'s `module:` line**, so it needs the publish-time and acquire-time check D6's path half already specifies — but the check is now over one complete, comparable string rather than a fragment reassembled from parts.

Scope: `#Module` only. `#Catalog` keeps its `modulePath` + `version` shape pending OQ13.

**Alternatives considered:**

- **(i) An authored `major` field alongside the bare `modulePath`.** Workable and the smallest change, but it adds a *second* identity fragment to keep in step with `cue.mod` while leaving D1's recombination intact — paying for the major without simplifying anything else.
- **(ii) Self-derive the major with `@extern(embed)` + `regexp` over the module's own `cue.mod/module.cue`.** Verified to work and to survive publishing (the module file ships inside the artifact zip). Rejected because `@embed` resolves relative to the *embedding file's* module, so `core` cannot do it on a consumer's behalf — every module would carry attribute-and-regex boilerplate it did not ask for — and because it is untested through `library`'s overlay load path, where registry loads stage a synthetic module root.
- **(a) `modulePath/name` with no version component at all.** Rejected: it makes two incompatible majors one identity, which is precisely the collision Go's path suffixes exist to prevent.

**Rationale:** This is the only candidate that makes something *else* simpler rather than only paying for the major. It removes an authored duplication (path prefix + name recombined into an address) instead of adding one, and it aligns `metadata.modulePath` with the string CUE itself uses to name the module — so the value an author writes is the value the registry, the import statement, and `cue.mod` all already agree on. D13 removed the full version from identity; D16 puts back exactly the component CUE and Go consider identity-bearing, and nothing more.

**Source:** User decision 2026-07-26, resolving OQ15 on evidence measured the same day (recorded under OQ15).

### D17: `#Catalog` follows D13 + D16 — `metadata.version` removed, major carried in the path, transformer FQNs become major-keyed

**Superseded in part by D19** — the version-deletion half is reversed; `#Catalog` keeps a full SemVer. D17's `modulePath`-carries-the-major change and its major-keyed FQNs stand.

**Decision:** `#Catalog` is treated exactly as `#Module`. `#Catalog.metadata.version` is deleted — taking the `*"0.0.0-dev"` default with it — `metadata.modulePath` carries the catalog's full CUE module path including the major (`opmodel.dev/catalogs/opm@v1`), and `metadata.fqn` is that path.

The consequence that makes this bigger than the module case is `#Catalog`'s pattern constraint (`core/src/catalog.cue:70-76`), which stamps `metadata.version: M.version` onto every `#transformers` entry. With no catalog version to stamp, transformers inherit the catalog's **major** instead, and a transformer FQN becomes `opmodel.dev/catalogs/opm/transformers/foo@v1` rather than `…/foo@1.0.0-alpha.2`. The stamped `modulePath` must also be composed from the catalog path with the major *stripped and re-appended* rather than concatenated, since `@v1` now sits mid-string.

**What this resolves and retires:**

- **OQ13 is answered by deletion.** "Where does a catalog's version come from under D4?" — nowhere; it does not exist. The `identity/version_override.cue` stamping generator, the transient-file-in-the-artifact practice, and the `0.0.0-dev` placeholder are all deleted rather than reformed.
- **Experiments 01 and 02 become historical.** Exp 01 measured that a stamped catalog's local and published FQNs diverge; with no version in the FQN there is nothing to diverge. Exp 02 compared six ways to declare a catalog version; none is now declared. Their findings stand as the evidence that produced this decision and should not be re-run.
- **Experiment 03 survives and is strengthened.** The `identity/` subpackage exists to break an import cycle between the catalog root and its transformer subpackage, and it still supplies `ModulePath` to subpackages after `Version` is gone. Exp 03 always argued this was about topology rather than stamping; D17 removes the stamping and the subpackage remains necessary, which is exactly what it predicted.
- **`#MajorVersionType` finally earns its comment.** `core/src/types.cue:22-24` declares it as "major version prefix used in primitive FQNs" and **nothing currently uses it** — a declaration written for a design that was never wired up. This is that design.

**The operational win, and it is the largest in this entry:** catalog-version skew stops being a routine failure. Today every catalog release changes the version embedded in every transformer FQN, so a module built against `catalog@1.0.0-alpha.2` and a platform subscribed to `catalog@1.1.0` share no matcher keys and the symptom is `no matching transformer`, naming neither the catalog nor the version. Under D17 only a **major** bump changes the key space. Patch and minor catalog releases become non-events for matching, which is how CUE and Go already treat compatible versions.

**Alternatives considered:**

- **Keep `#Catalog.metadata.version` and fix it by other means** (a committed concrete version, per experiment 02 variant B). Rejected: it was the right answer to the question as posed, but the question was whether the catalog's version should be *declared well* rather than whether it should exist. Every argument D13 makes for `#Module` applies unchanged, and keeping one artifact type version-bearing while the other is not would leave two conventions where D7 exists to have one.
- **Remove the catalog version but let each transformer declare its own.** Rejected: it breaks 0001 D18's lockstep, turns one catalog-level fact into N author-maintained ones, and reintroduces per-primitive drift inside a single published artifact.
- **Drop versions from primitive FQNs entirely** (path-only matcher keys). Not chosen here, but noted as the logical endpoint — see OQ16. It would remove the last version component from the matcher, at the cost of making two incompatible majors of a primitive indistinguishable, which is the collision D16 rejected for modules.

**Rationale:** D7 established that catalogs publish through the same pipeline as modules with a different artifact type. Treating them the same here is the same principle applied one layer down — and the catalog case is where the version-in-identity design was doing the most damage, because a catalog's version propagates into the FQN of everything it ships rather than naming one artifact.

**Source:** User decision 2026-07-26, resolving OQ13.

### D18: Primitive FQNs are major-keyed; the exact catalog version is a kernel-held coordinate

**Decision:** `#FQNType` becomes major-keyed (`path/name@vN`) for every primitive — resources, traits, blueprints, and transformers alike — so a primitive's FQN is stable across the whole compatible series of the catalog that ships it. The **exact** resolved catalog version stops being part of any identity string and becomes a coordinate the kernel holds, taken from the tag `materialize` resolved, and used for diagnostics, provenance, and reporting.

This makes the pattern the platform team actually wants a supported one: a catalog publishes `v1.0.0`, `v1.1.0`, `v1.2.0` adding APIs; a platform subscribes to the `v1` series; modules written against *different minors* of that catalog all install on it and match correctly, because every FQN on both sides reads `@v1`.

**Feasibility is already met.** `library/opm/materialize/materialize.go:93` constructs `catalogBuild{Subscription, Version, Value}` where `Version` is the bare SemVer of the tag it resolved (`index.go:22`). The kernel already knows exactly which catalog build it pulled; today that knowledge is used only in error messages. D18 keeps it there rather than burning it into every FQN.

**This reverses enhancement 0001 D5**, recorded plainly because it was a deliberate prior decision. `core/src/types.cue:41-44` states its rationale: FQNs were *lifted* from major-only to SemVer so that "two builds of the same primitive at adjacent versions must occupy distinct keys so divergent definitions surface as structured errors at match time rather than silently colliding on a MAJOR bucket." D18 accepts that goal and rejects the mechanism: version inequality is a *proxy* for definitional divergence, and a poor one, because it charges every consumer on every release for a check that only pays out when a publisher misbehaves. The goal is better served by comparing definitions — same key, structurally different definition → error — which tests the actual condition. Whether that check is built is a separate question; D18 does not depend on it.

**Alternatives considered:**

- **(A) Walk back D17 and keep `#Catalog.metadata.version`.** Rejected: it restores the routine cross-minor skew, the `0.0.0-dev` placeholder, and experiment 01's measured local-vs-published divergence, and it reopens OQ13.
- **(C) A semver-range-aware matcher** — teach matching that a `@1.5.0` supply satisfies a `@1.4.0` demand. Rejected as the most expensive option available: it turns an O(1) keyed lookup into constraint solving, re-implements the semver resolution CUE already performs for module dependencies, and still leaves every FQN string churning on each release.
- **(D) Normalize to major at match time**, leaving semver FQNs in the schema. Rejected despite being the smallest core change: it creates two notions of FQN — the string the schema declares and the key the matcher uses — which is the same declared-versus-effective split this entry exists to remove.
- **(E) Demand primitives by path with no version at all.** Rejected: it gives up the ability to express a major incompatibility, which is the one version distinction that carries real meaning.

**Rationale:** This is D13's identity-versus-coordinate split applied one level down, and it makes catalogs symmetric with modules rather than special: the exact version stops being part of what a primitive *is* and becomes part of what the kernel *resolved*. The residual failure — a module demanding a primitive that the materialized catalog is too old to contain — is partial and specific rather than total, is reported by `MissingFQN` with `Alternatives` that are finally informative, and is kept rare by materializing the newest build in the subscribed range rather than pinning a minor.

**Source:** User decision 2026-07-26, resolving OQ16.

### D19: `#Catalog` keeps `metadata.version` — FQNs are the match key, the full version is the compatibility signal

**Superseded in part by D21** — read D21 before acting on the field's location. D19's substance stands (the catalog carries a full SemVer as the compatibility signal, distinct from the major-keyed FQN); only its implication that the field sits on the catalog root is reversed.

**Decision:** D17 removed `#Catalog.metadata.version`. **That part of D17 is reversed.** `#Catalog` keeps a full SemVer `metadata.version`, declared concretely in committed source, and keeps stamping it onto every primitive it ships. What does **not** come back is the version in the FQN: D18 stands unchanged, and every primitive FQN remains major-keyed (`path/name@vN`).

The two carry different jobs:

- **FQN (`@vN`) is the match key.** Major-keyed, so a module built against catalog `1.0.0` and a platform that materialized `1.2.0` match — the cross-minor pattern D18 exists to support.
- **`metadata.version` (full SemVer) is the compatibility signal.** Because the catalog stamps it onto its primitives, a module *inherits a record of which catalog build it was authored against*. Comparing that against the version the platform actually resolved detects "this platform's catalog is older than this module requires" and errors clearly, instead of failing later with a missing FQN that names nothing useful.

This closes the residual failure D18 left open. It is expressed in `schemas/target.cue` as `#CatalogCompat`, whose `satisfied` field is constrained to `true` so an out-of-date platform catalog is a unification failure rather than a value someone must remember to check. Verified: a module requiring `1.2.0` against a platform resolving `1.0.0` yields `satisfied: conflicting values false and true`, and differing majors yield `major: conflicting values 2 and 1`. The passing cross-minor and exact-match cases vet clean.

**`#Catalog` and `#Module` are therefore NOT symmetric, and the asymmetry is principled.** A catalog is a *vocabulary provider*: its consumers must be able to state a minimum version, because a module can genuinely require a primitive that only exists from some catalog build onward. A module is a leaf artifact that nothing depends on, so there is no consumer needing to express a floor against it — which is why D13 stands for `#Module` and does not extend here.

**Consequences for the record:**

- **OQ13 is live again and re-answered.** "Where does a catalog's version come from?" — a concrete SemVer committed in source, which is exactly what experiment 02 variant B concluded before D17 briefly made the question moot.
- **Experiments 01 and 02 are NOT historical after all.** The banner added to `experiments/README.md` when D17 landed is withdrawn there. Exp 02's finding — strict-committed is the only declaration satisfying all three required properties — is directly load-bearing again. Exp 01's finding still holds and still matters, though its severity drops: a stamped catalog's local-versus-published divergence no longer corrupts the *match key* (that is major-keyed now), but it does corrupt the *compatibility signal*, so the version must be committed rather than stamped.
- **The `0.0.0-dev` placeholder problem returns**, and D20 addresses its shape.

**Source:** User decision 2026-07-26. Reverses D17's version-deletion for `#Catalog` while preserving D17's `modulePath`-carries-the-major change and D18's major-keyed FQNs.

### D20: Ad-hoc and local-render versions are `vMAJOR.0.0-dev`, not `v0.0.0-dev`

**Superseded by D24** — the dev version is the latest published tag in the major, patch-bumped with `-dev` appended, so it sorts *above* every release instead of below. Read D24 for the live rule; what follows is why the placeholder had to carry the real major at all, which D24 preserves.

**Decision:** Wherever OPM must supply a version for something that has not been published — a local checkout render, an ad-hoc build, the `module.opmodel.dev/version` label the kernel stamps when there is no resolved tag (D14/D15) — the placeholder carries the **real major**: `2.0.0-dev` for a v2 artifact, never `0.0.0-dev`.

**Rationale:** The major is the identity-bearing component. It is in the module path, it is in every FQN under D18, and under D16 it is in `metadata.modulePath` and therefore in `fqn` and every UUID derived from it. A `0.0.0-dev` placeholder gets the *identity-bearing* part wrong, so a locally-rendered artifact diverges from its published self on identity — the exact failure experiment 01 measured. `vMAJOR.0.0-dev` gets the identity-bearing part right and leaves only minor, patch, and prerelease — none of which participate in identity — as placeholder values.

This also answers the question D14/D15 left open: rendering a local checkout stamps `vMAJOR.0.0-dev` rather than omitting the label or inventing an unrelated value.

**Source:** User decision 2026-07-26.

### D21: `#Catalog.metadata` declares no version — Reading B

**Decision:** `#Catalog.metadata` has no `version` field. The catalog's full SemVer lives only in its generated `identity` package, and each primitive reads `id.Version` directly for its own `metadata.version` — which is where the compatibility signal (D19) actually needs to be, since that is what a module inherits. `#Catalog`'s pattern constraint therefore stamps `modulePath` onto `#transformers` entries but **not** `version`.

This supersedes D19's implication that the field sits on the catalog root. D19's substance — the catalog carries a full SemVer as the compatibility signal, distinct from the major-keyed FQN — stands unchanged.

**Alternatives considered:**

- **Reading A: keep `version!` on `#Catalog.metadata`**, valued from identity, with the pattern constraint stamping it onto transformers. Rejected: the stamping exists only to propagate a value the primitives can already read themselves from the same identity package, so it is machinery without a job. Keeping it would also leave two places a catalog's version appears in the schema.

**Rationale:** The catalog root does not need to state its own version because nothing asks a catalog for its version directly — the question consumers actually ask is "what version of this primitive am I holding", and that is answered on the primitive. Removing the field deletes the stamping constraint rather than re-plumbing it.

**Source:** User decision 2026-07-26. Implemented in `experiments/05-decided-shapes-module-catalog/core/core.cue`.

### D22: A module's built-against catalog version is read from its own `cue.mod` deps

**Decision:** The compatibility floor's "what was this module built against" value is **not a new field and is not generated**. It is read from the module's own `cue.mod/module.cue` `deps` block, which already records the exact catalog version the module resolved at build time and already ships inside the published artifact. `opm module publish` guarantees the value is captured by ensuring that file is intact and current; the kernel reads it back at materialize and compares against the version the platform resolved.

**Evidence (2026-07-26):** `modules/jellyfin/cue.mod/module.cue` carries `deps: "opmodel.dev/catalogs/opm@v1": {v: "v1.0.0-alpha.1"}`, and `cue.mod/module.cue` was confirmed present inside the published artifact zip for `opmodel.dev/modules/jellyfin@v2` tag `v2.0.2`. The registry loader already stages that file — `LoadModulePackageWithSource` documents that the module's own `cue.mod/module.cue` drives transitive resolution — so the data is in hand at the acquire point with no new plumbing.

**Alternatives considered:**

- **Generate a record at publish** into the identity package or a new `#Module` field. Rejected as redundant: it would create a second statement of a fact `cue.mod` already holds authoritatively, which is precisely the duplication this enhancement exists to remove. It would also be *less* trustworthy, since a generated copy can drift from the deps that actually resolved.
- **Recompute at render from the catalog being materialized.** Rejected — and this is the failure experiment 05 exhibits: recomputing makes the value track the platform's catalog rather than the module's, so the floor check compares a value against itself and can never fail.

**Rationale:** The module's dependency block is already the authoritative record of what it was built against; it is versioned with the module, frozen at publish, and shipped in the artifact. The requirement is not to *record* the value but to *stop discarding* it.

**Source:** User decision 2026-07-26 ("a publish command ensures this is recorded"), refined by the finding that `cue.mod` deps already record it.

### D23: `modulePath` is generated, not authored — OQ18 resolves to (c)

**Decision:** Neither `#Module.metadata.modulePath` nor `#Catalog.metadata.modulePath` is hand-written in source. Both are produced by OPM tooling from the artifact's own `cue.mod/module.cue` `module:` line — by `publish` when publishing, and by the local build/vet path when working against a checkout. D16's authored-path half is superseded; D16's substance — that `modulePath` carries the full CUE module path including the major, and that `fqn` is that path — stands.

Accepted consequence: the committed tree is **not independently evaluable by plain `cue vet`**, because the generated identity is absent until an `opm` command produces it. OPM-mediated commands always work; bare `cue` tooling on a fresh clone does not. This is the cost of removing the duplication, and it is chosen deliberately rather than discovered.

**Alternatives considered:**

- **(a) Authored, as D16 recorded.** Rejected: it leaves the module path stated twice, in `cue.mod/module.cue` and in `metadata`, with a check to keep them equal — a duplication kept alive purely so a checkout vets standalone.
- **(b) Derived in CUE via `@embed`.** Ruled out by user decision 2026-07-26, independently of its measured feasibility.

**Rationale:** The `module:` line in `cue.mod/module.cue` is the one place CUE itself names the module. Generating identity from it makes that line the single source and removes the author's ability to disagree with it.

**Source:** User decision 2026-07-26, resolving OQ18. The *mechanism* — whether generation targets an `identity/` subpackage or a file in the artifact's own package — is not fixed by this decision; see OQ19.

### D24: The dev-build version is the latest published in the major, patch-bumped, suffixed `-dev`

**Decision:** When OPM must supply a version for an artifact that has not been published — a local checkout, an ad-hoc build — it queries the registry for the highest tag in the artifact's major, increments the **patch**, and appends `-dev`. Latest published `1.2.3` → dev version `1.2.4-dev`.

This supersedes D20's `vMAJOR.0.0-dev` spelling. D20's *reasoning* stands unchanged — the major is identity-bearing and must be real in any placeholder — and D24 keeps that property while fixing the ordering D20 got wrong.

**Rationale:** A dev build is by construction *ahead of* every published release, and the version must sort that way. `vMAJOR.0.0-dev` sorts below everything, so a dev catalog failed D19's floor for any module built against a real release — breaking the dev loop precisely when someone is developing the catalog (OQ17). Bumping the patch places the dev version above every published release in the major and below the next real one. Verified in `experiments/05-decided-shapes-module-catalog/`: a module built against `1.2.3` meeting a platform on `1.2.4-dev` satisfies the floor, where under `1.0.0-dev` it would not.

**Still to specify:** the query needs the registry, so a local build acquires a network dependency. An offline path must exist — a cached last-known tag, or a documented degraded mode — and it must not fall back to a value that sorts low, which would reintroduce exactly the failure this decision removes.

**Source:** User decision 2026-07-26, resolving OQ17.

### D25: Identity is generated into the artifact's own package; catalogs additionally keep `identity/`

**Superseded in part by D27** — the identity file is committed and visible rather than gitignored. D25's generation *targets* stand; only its "both are gitignored" clause is reversed.

**Decision:** Generation targets differ by artifact type, and the asymmetry follows from package topology rather than preference.

- **`#Module`** — one generated file in the module's **own package** (`gen_identity.cue`), setting `metadata: modulePath` directly. No subpackage, no import, nothing for the author to write. Modules are single-package, so there is no cycle to break.
- **`#Catalog`** — **two** generated files. `identity/identity.cue` supplies `ModulePath` and `Version` to the `resources/` and `transformers/` leaves, which read it at their own definition sites to compute their own FQNs — the root cannot supply this, because that is the import cycle experiment 03 measured. Plus a root `gen_identity.cue` binding `metadata: modulePath`, so a catalog author writes no more about identity than a module author does.

Both are gitignored. This resolves OQ19 as option (i) for modules and option (ii) for catalogs.

**Rationale:** The binding cannot live in `core` — `#Module` and `#Catalog` are defined in `opmodel.dev/core`, which cannot import a consumer's package, and CUE has no construct for importing relative to whoever is unifying you. Generating into the consumer's own package achieves the same author-writes-nothing outcome without requiring one. The catalog's second file is not redundancy: the leaves need the constant *before* the root exists, which is exactly the cycle `identity/` was introduced to break.

**Why not simply author `metadata: modulePath: id.ModulePath` and generate only `identity/`?** Because referencing your own subpackage requires naming your own module path. Measured 2026-07-26 (cue v0.17.1): `import id "identity"` fails with *builtin package "identity" undefined*; `import id "./identity"` fails with *relative import paths not allowed*; only the fully-qualified `import id "opmodel.dev/m/acme/media_server/identity@v2"` resolves. So that route does not remove the hand-written module path — it **relocates** it from `metadata.modulePath` into an `import` statement, where it is no easier to keep correct and no longer checkable against `cue.mod`. It is strictly worse under D9, whose owner-scoped migration moves every module's path and would then have to rewrite every import line as well. Generating into the artifact's own package needs no import at all, which is the entire reason it works.

**Consequence for catalogs, which cannot avoid this:** a catalog's `resources/` and `transformers/` leaves must import `identity` by fully-qualified path, so every catalog leaf file hard-codes the catalog's module path. Any path change — including D9's migration — rewrites every one of those import lines. Modules escape this; catalogs do not, because the import cycle forces a shared package.

**Source:** User decision 2026-07-26, expressed directly as edits to `experiments/05-decided-shapes-module-catalog/{mod/module.cue,cat/catalog.cue}`.

### D26: `metadata.name` is snake_case; `nameSnakeCase` and the kebab projection are removed

**Decision:** `#Module.metadata.name` is authored in **snake_case** (`#SnakeNameType`) rather than kebab-case. The path leaf equals `name` directly, with no projection between them. The rest of the module path is whatever CUE accepts and OPM does not narrow it.

Consequently **`nameSnakeCase` and `#KebabToSnake` are removed from `core`.** They exist solely to project kebab onto snake; with `name` already snake there is no projection left, and D1's "one identity, one canonical projection" collapses to "one identity". This deletes surface *this enhancement itself added* — `nameSnakeCase` landed in `core` on 2026-06-17 as D2 — which is recorded plainly rather than quietly dropped.

**Alternatives considered:**

- **Narrow `#ModulePathType` to snake_case throughout.** Rejected on evidence: CUE accepts hyphens in path segments (verified — `github.com/open-platform-model/my-thing@v1` evaluates and `cue mod tidy`s clean), path segments are not CUE identifiers, and narrowing would make OPM unable to express its own GitHub org. Only the *leaf* needs to be a CUE identifier, because only the leaf is also the package name.
- **Keep kebab `name` plus the derived `nameSnakeCase`.** Rejected: it keeps two spellings of one identity alive so that one of them can be prettier, which is the class of drift this entry exists to remove.

**Migration:** every module whose name contains a hyphen is renamed — `web-app` → `web_app`, `zot-registry-ttl` → `zot_registry_ttl`. `name` feeds the `module.opmodel.dev/name` label, so this is user-visible; underscores are legal in Kubernetes label values.

**Open:** whether `#Catalog` gains a `name` field to receive the same rule. It has none today — its identity is `modulePath` alone — so applying the rule there means *adding* a field, presumably equal to the path leaf. Not decided here; see OQ20.

**Source:** User decision 2026-07-26.

### D27: `identity.cue` is committed and visible; OPM tooling writes into it

**Decision:** An artifact's identity file is **committed to git and visible to developers**, holding concrete values. OPM tooling *writes into it* — the way `npm version` writes `package.json` — rather than generating it behind the developer's back. The developer sees the file, sees the diff, and commits it. Fields OPM owns carry an inert marker attribute:

```cue
ModulePath: "opmodel.dev/m/acme/media_server@v2" @opm(identity, owner=publish)
```

This supersedes D25's *gitignored generation* while leaving D25's structural placement intact: modules keep their identity in a file in the module's own root package (no subpackage, no import — measured, CUE has no relative intra-module imports), catalogs keep `identity/identity.cue` as the shared constant their leaves import. What changes is that both are now committed rather than ignored, and both are tool-written rather than tool-generated.

**Rationale — and the reason is transparency, not mechanics.** Every mechanism that hides identity was rejected for the same reason: a developer reading a module cannot tell where its identity comes from, cannot open the file that supplies it, and has to trust that tooling is doing something correct and invisible. A committed file is documentable, diffable, reviewable in a PR, and greppable. OPM does no magic behind the scenes; it edits a file you can read.

The technical constraint that rules out the alternatives is separate and was measured in `experiments/06-identity-supply-mechanisms/`: identity must be present in the artifact's **own bytes**, because CUE's dependency resolution is what carries it to consumers and OPM does not mediate that. `@tag()` injection does not reach an imported package at all — a catalog imported by a module keeps its placeholder no matter what the top-level build injects, silently. A committed value resolves correctly through the import with no tooling in the loop.

**What this retires.** D23 accepted, as a deliberate cost, that "the committed tree is not independently evaluable by plain `cue vet`". Under D27 that cost is **gone**: identity is committed and concrete, so a fresh clone vets with plain `cue` and no OPM tooling. That was the largest objection to the generation route and D27 removes it rather than accepting it.

**Alternatives considered:**

- **Gitignored generation into the artifact's own package (D25 as recorded).** Rejected on the transparency goal: the value lives in a file the developer never wrote and cannot see in git.
- **`@tag()` as the value source.** Rejected on measurement — see above, and `experiments/06-identity-supply-mechanisms/` finding 1.
- **Committed marker plus a gitignored generated value** (experiment 06 variant C). Technically sound, and its fresh-clone failure is legible (`incomplete value string`) rather than cryptic. Rejected because the value is still hidden; the marker makes the *field* visible without making the *value* visible.

**Source:** User decision 2026-07-26, on `experiments/06-identity-supply-mechanisms/` (Concluded).

---

## Open Questions

Collapsed at supersession (2026-07-29). Each question's full framing, candidate list, and measured evidence is in git history; what a reader needs from a dead entry is which question was asked, whether this entry answered it, and which successor inherited it if not. Questions still marked `open` were never answered here.

- **OQ1: Does `opm publish` *enforce* or *generate* the canonical coordinates?** Status: open. Carried to 0011 OQ5.

- **OQ2: How is the import qualified when the package name is needed?** Status: resolved-by-D5.

- **OQ3: Does the library *derive* the reference from metadata or *record* the fetched reference at load?** Status: open. Not carried — no successor filed it.

- **OQ4: How do existing non-conforming in-repo modules migrate?** Status: open. Subsumed in scope by OQ9; carried to 0011 OQ6.

- **OQ5: How does the convention degrade for third-party modules not published via `opm publish`?** Status: resolved-by-D6.

- **OQ6: What does a version override flag on `opm module publish` mean under D4?** Status: resolved-by-D12.

- **OQ7: Does `#Catalog` get the same treatment, and who owns it?** Status: resolved-by-D7.

- **OQ8: Does a `cue.mod/local-module.cue` replacement chain survive more than one hop?** Status: informed-by-exp-04. Not carried. Bullets 1-2 answered in `experiments/04-local-module-chain-hops/` — the inner hop IS dropped, a hand-written chain-complete `local-module.cue` does resolve every hop, and `cue mod tidy` preserves it. Bullet 3 (whether catalog materialization honours `replaceWith` at all) was never run.

- **OQ9: How does the existing published fleet migrate to the owner-scoped namespace (D9)?** Status: open. Carried to 0011 OQ6.

- **OQ10: Should a primitive's `modulePath` be required to equal the `modulePath` of the catalog that ships it?** Status: open. Carried to 0010 OQ3.

- **OQ11: Does publishing to the central registry need an authentication story in this enhancement?** Status: open. Carried to 0011 OQ2.

- **OQ12: What are the republish and tag-immutability semantics of the central registry?** Status: open. Carried to 0011 OQ3. Prior art in `research/prior-art-version-agreement.md`.

- **OQ13: Where does a catalog's version come from under D4?** Status: resolved-by-D19. Evidence in `experiments/01-catalog-local-vs-published-parity/`, `experiments/02-catalog-version-declaration-variants/`, `experiments/03-identity-subpackage-necessity/`.

- **OQ14: What detects "this module changed" once the version lives in source?** Status: open. Carried to 0011 OQ4.

- **OQ15: What shape do `#Module.metadata.fqn` and the identity UUIDs take once the version is gone?** Status: resolved-by-D16.

- **OQ16: Do `#Resource`, `#Trait`, and `#Blueprint` follow D17 to major-keyed FQNs?** Status: resolved-by-D18.

- **OQ17: How does a `vMAJOR.0.0-dev` catalog interact with the D19 compatibility floor?** Status: resolved-by-D24. D24 supersedes D20.

- **OQ18: Is `#Module.metadata.modulePath` authored, or derived from `cue.mod/module.cue`?** Status: resolved-by-D23.

- **OQ19: Does generated identity target a subpackage or the artifact's own package, and can `core` supply the binding?** Status: resolved-by-D25.

- **OQ20: Does `#Catalog` gain a `name` field?** Status: open. Carried to 0010 OQ1.

- **OQ21: How does D24's dev version survive a committed `identity.cue`?** Status: open. Carried to 0010 OQ8.


## Recorded Non-Issues

Questions raised during design and closed without becoming Open Questions. Recorded so they are not re-opened.

- **Promoting or mirroring an artifact between registries does not conflict with D3.** `#PublishedModuleRef` binds `artifactPath` to `importPath`, which is derived from `metadata.modulePath` — and CUE resolves a module path to a *host* through the prefix→host mapping in `CUE_REGISTRY`, not through anything embedded in the path itself. So copying `opmodel.dev/m/<owner>/<name>` from a staging registry to production changes the host while the module path and the tag both stay put, and every invariant in this enhancement is stated over the path and the tag. Mirroring is transparent to D3, D6, and D9. (Raised 2026-07-25 during the publish-scenario walk.)
