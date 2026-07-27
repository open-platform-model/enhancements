# Design Decisions — OPM Module Publishing Workflow

This document records every significant design choice with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, …) and recorded as they are made. The log is **append-only** — never remove or renumber existing entries. If a decision is reversed, add a new decision that supersedes it and leave the original in place.

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

- **OQ1: Does `opm publish` *enforce* or *generate* the canonical coordinates?** Status: open. Two modes: (a) enforce — read the author's `cue.mod/module.cue` `module:` path and `package` clause and reject the push if they don't match `#CanonicalModuleRef`; (b) generate — synthesize the conformant `cue.mod` from metadata so the author never writes it. Enforce is less magical and keeps authored source authoritative; generate is more ergonomic but hides the path. Could support both (generate with a `--check`-only mode). Resolving this fixes the cli command's contract.

- **OQ2: How is the import qualified when the package name is needed?** Status: **resolved-by-D5**. A bare `import "path@vN"` binds, verified empirically through enhancement 0006's C2 fixture work and the C3 handoff e2e.

- **OQ3: Does the library *derive* the reference from metadata or *record* the fetched reference at load?** Status: open. With D1, deriving from metadata is sufficient *if* every consumed module conforms. Recording the exact `modPath@version` the registry loader fetched by (on `*module.Module`) is strictly more robust for non-conforming third-party modules, at the cost of a new field on the module type. The two compose: derive as the rule, record as the safety net + validation input. Resolving this fixes whether `module.go` gains a field.

- **OQ4: How do existing non-conforming in-repo modules migrate?** Status: open. **Subsumed in scope by OQ9**, which asks the same question for the whole fleet after D9 rather than for the handful of non-conforming leaves. Answer them together; OQ4's specific cases remain the worked examples. `web-app` (testdata) is published at a hyphenated leaf `…/web-app@v1` with package `web_app` and `metadata.version 0.1.0` (an `@v1`/`0.1.0` mismatch); it must move to `…/web_app@v0`. Are there other workspace modules whose `cue.mod` leaf ≠ `nameSnakeCase`? Migration renames published identities, so it needs an inventory + a hard-switch vs transition-window call. Resolving this fixes the `affects` fixture work and the rollout sequence.

- **OQ5: How does the convention degrade for third-party modules not published via `opm publish`?** Status: **resolved-by-D6**. Hard error at acquire, naming both the expected and actual coordinates. Best-effort fallback was rejected because it makes a wrong-artifact condition survivable and therefore invisible.

- **OQ6: What does a version override flag on `opm module publish` mean under D4?** Status: **resolved-by-D12**. It means nothing, because there is no such flag: version authoring moves to `opm module version set` and publish takes no version input at all. The question was framed as *what should the flag mean* and the answer turned out to be *there should not be one* — (c) is dead by measurement, (a) is subsumed by an idempotent setter, and (b) is real but belongs to a different command so the commit can sit between authoring and pushing. Original framing follows. D4 makes `metadata.version` authoritative, which appears to leave no room for a `--version` flag — but the publishing workflow needs one (release automation, pre-release tags, republishing a fixed build). Three candidate shapes:
  - **(a) Assertion.** `--version` is accepted only when it equals `metadata.version`; a mismatch is refused. Useful as a CI guard ("publish exactly what I reviewed"), changes nothing about authority.
  - **(b) Rewrite-then-publish.** `--version` writes the value into `metadata.version` in the *source file*, then derives from it. This is stamping into source rather than into the artifact, so artifact bytes still equal source bytes and D4's reproducibility rationale holds. It effectively makes publish a release command, and pairs naturally with OQ1's "generate" mode.
  - **(c) Tag-only override.** `--version` changes the pushed tag without touching metadata. **Ruled out** — it reintroduces exactly the drift D3 removes.

  Resolving this fixes the publish command's contract and interacts with OQ1: if publish may rewrite `module.cue`, "generate" largely subsumes "enforce". Note also that whichever shape wins must not let release automation (release-please and the `modules` repo's bump-and-publish task) reintroduce a second source of truth.

  **Measured 2026-07-25.** Option (c) is no longer ruled out by reasoning alone — it is what the `modules` repo does today, and `01-problem.md` records what it produced: `publish:smart` chooses the tag from a checksum diff and never writes `metadata.version`, so two of the three modules with published history now carry artifacts whose declared version names an earlier release. (c) is not a hypothetical drift risk but a demonstrated drift *generator*. The same evidence eliminates the external-version-registry mechanism generally — `versions.yml` cannot satisfy D3 by construction, because nothing in the flow writes back into the source the invariant is about. What survives is (a) and (b), which differ only in whether the flag may write the source file; both keep artifact bytes equal to source bytes, and (b) is the only one of the two that gives release automation somewhere to put its answer.

- **OQ7: Does `#Catalog` get the same treatment, and who owns it?** Status: **resolved-by-D7**. Both, here: `opm catalog publish` ships in this enhancement because it is the same pipeline as `opm module publish` with a different artifact type. Original framing follows. `core`'s `#Catalog` declares `version!: #VersionType | *"0.0.0-dev"` — a *default*, meaning a catalog can silently publish under a placeholder version. Catalog FQNs embed that version and transformer matching keys off it, so the failure mode is the already-familiar "no matching transformer" rather than a legible error. The same D3/D6 pair applies. This entry's scope says `#Catalog` publishing belongs to enhancement 0001; resolving this decides whether the invariant is specified here and implemented there, or moves wholesale.

- **OQ8: Does a `cue.mod/local-module.cue` replacement chain survive more than one hop?** Status: informed-by-exp-04. Bullets 1 and 2 are answered and the central claim is confirmed; bullet 3 (catalog materialization) remains open and needs its own kernel-level experiment. CUE honours `local-module.cue` only for the **main** module; a replaced dependency's own `local-module.cue` is ignored (<https://cuelang.org/docs/reference/modules/#local-module-file>). The dev loop OPM actually wants is two hops deep: an `instance.cue` package replaces its module with a local checkout, and that module in turn replaces a catalog with a local checkout. The inner hop is dropped, so the instance resolves the local module against the *published* catalog — a mixed resolution that is not what either replacement asked for, and whose failure mode is the familiar catalog-version skew (`no matching transformer`) rather than anything naming a replacement.

  Unverified, and each needs a runnable check under `experiments/`:
  - Whether the instance's own `local-module.cue` can carry **both** entries (module and catalog) to reconstruct the full local chain by hand, including when the inner dep exists solely to be replaced and therefore has no `v`.
  - Whether `cue mod tidy` maintains such a two-entry file, or silently drops the transitive entry as unreferenced.
  - How this interacts with catalog materialization, which resolves subscriptions through the registry client (`library/opm/materialize/enumerate.go`) **independently of main-module load** — so a `replaceWith` on a catalog appears not to reach the transformer set at all today, even at one hop. If confirmed, a local catalog checkout supplies the primitives a module imports while the registry supplies the transformers that render them, which is exactly the skew above.

  Mostly a dev-loop question rather than a publish question — the artifact being published is always the main module, so D8's gate sees the file it needs to see. It is recorded here because D8 is where `local-module.cue` enters this design; it may migrate to the CLI platform-resolution entry when that entry exists.

  **Measured 2026-07-25** (`experiments/04-local-module-chain-hops/`, cue v0.17.1, live registry). A three-link chain `inst → mod → cat` where every artifact carries an `Origin` marker and `mod` re-exports the `Origin` of whichever `cat` it resolved against:

  - **The inner hop is dropped, confirming the premise.** Replacing only `mod` yields `modOrigin: LOCAL-CHECKOUT` with `catOrigin: REGISTRY` — `local/mod`'s own `local-module.cue` asking for a local `cat` is ignored, so the instance renders local module bytes against the published catalog. Nothing in the output names the discarded replacement; the only symptom is a value from somewhere the developer did not intend.
  - **Bullet 1 answered: the chain can be reconstructed by hand.** A main-module `local-module.cue` carrying one entry per hop resolves every link locally. This holds whether the transitive dep is pinned (`v: "v1.0.0"`) or present with no version at all (`{}`) — so a dependency that exists solely to be replaced does not need a published version to be replaceable, and the never-published case is covered.
  - **Bullet 2 answered: `cue mod tidy` preserves the multi-entry file.** It reformats (`x: y: z` → nested braces) and sorts keys alphabetically, but prunes nothing from `module.cue` or `local-module.cue`; re-resolution after tidy still resolves both hops locally. Tooling that *generates* a chain-complete `local-module.cue` is therefore viable rather than being fought by tidy.
  - **Bullet 3 not answered.** Whether catalog materialization honours `replaceWith` is a kernel question needing a full render fixture (Platform with a `#registry` subscription + catalog + module). Code-level prior only: `library/opm/materialize/enumerate.go` builds its own `modconfig.NewResolver` and calls `client.ModuleVersions(ctx, path)` to enumerate *published versions* of a subscription path, independently of main-module load. A local directory has no version list to enumerate, so a `replaceWith` appears to have no way to participate — which would mean a local catalog checkout supplies the primitives a module imports while the registry supplies the transformers that render them, even at one hop. Prior, not result.

  The practical consequence for the dev loop: the natural thing — putting the catalog replacement next to the module that depends on it — silently does nothing, and only the outermost `local-module.cue` is honoured. That asymmetry needs an explicit note wherever the local-dev workflow is documented.

- **OQ9: How does the existing published fleet migrate to the owner-scoped namespace (D9)?** Status: open. Supersedes the scope of OQ4, which asked the same question for a handful of non-conforming leaves; D9 makes it universal, because *every* module currently published under `opmodel.dev/modules/<name>` moves to `opmodel.dev/m/<owner>/<name>`. The path is part of `metadata.modulePath`, which feeds `fqn` → `module.uuid` → `instance.uuid` → the identity label stamped on every rendered resource — so this is not a redirect, it is a new identity for every module and every live instance of it. Unresolved: whether deployed instances are adopted (relabel in place, requiring the operator and CLI to accept a recorded old identity) or recreated; whether the old paths are republished as aliases during a transition window or hard-cut; and what happens to the artifacts that share the namespace without being modules at all — the workspace registry currently carries `opmodel.dev/library/testdata/modules/web-app` (a test fixture) and a set of legacy `opmodel.dev/<name>/v1alpha1` paths alongside real modules. The migration is cheap now and compounds with every module published, so this is the sequencing constraint on D9 rather than a detail of it.

- **OQ10: Should a primitive's `modulePath` be required to equal the `modulePath` of the catalog that ships it?** Status: open. The convention is already *followed*, just not *enforced*. `core` types `#Resource` / `#Trait` `metadata.modulePath` as a free-form `#ModulePathType` (`core/src/resource.cue:18`, `trait.cue:17`), and the doc-comment examples there show an unrelated path (`opmodel.dev/opm/resources/workload/container@1.4.0`). But the shipped catalog binds them: every primitive in `opmodel.dev/catalogs/opm@v1.0.0-alpha.2` sets `modulePath: "\(id.ModulePath)/resources"` (or `/traits`) from the catalog's `identity` subpackage, so its FQNs read `opmodel.dev/catalogs/opm/resources/config-maps@1.0.0-alpha.2` (artifact inspected 2026-07-25). The reverse lookup — "which catalog ships FQN X?" — therefore *works today* by stripping the trailing `resources`/`traits`/`transformers` segment, for any catalog that follows the convention. That is exactly the D1 situation restated: derivable by convention, enforced nowhere, so it will drift the moment a third-party catalog is authored without reading the first-party one. Note the partial asymmetry in `core`: `#Catalog`'s pattern constraint *does* structurally stamp every `#transformers` entry with `metadata.modulePath: "\(M.modulePath)/transformers"`, so transformers are bound while resources and traits rely on author discipline. Extending the same stamping has no site to attach to, because resources and traits reach a catalog only transitively through each transformer's `required`/`optional` maps rather than through a map `#Catalog` owns. Resolving this decides whether the constraint lands in `core` (a new stamping site), in this enhancement's publish gate (`opm catalog publish` rejects a catalog whose primitives sit outside its own path), or both — and it is load-bearing for third-party catalogs (see the vendor-primitives pattern), where the convention has no first-party example to copy from.

- **OQ11: Does publishing to the central registry need an authentication story in this enhancement?** Status: open. In tension with the stated scope. `README.md ## Out of scope` excludes "registry authentication, credentials, signing, and provenance/attestation" — a boundary drawn when this entry was only about a naming convention. D9 makes the central registry the source, which means `opm module publish` must be able to *write* to it, and the CLI has no credential surface at all today: no `opm login`, no credential-helper handling, no token storage. It inherits whatever the CUE SDK's resolver finds. The minimum viable answer may be "inherit `cue login` and document it", which is still an answer this entry has to give rather than assume. Signing and attestation stay out of scope regardless.

- **OQ12: What are the republish and tag-immutability semantics of the central registry?** Status: open. **Prior art (`research/prior-art-version-agreement.md`, 2026-07-26):** the survey found a clean split — package registries treat release immutability as fundamental (Maven Central rejects redeployment of releases outright), while OCI registries treat it as **opt-in configuration** (ECR repositories are mutable by default and must be explicitly set immutable; Harbor implements project-level immutability rules covering re-push, re-tag, delete, and replication). CUE modules are published to OCI registries, so OPM inherits the *weaker* default rather than the packaging-ecosystem norm — this is a gap to close deliberately, not a property to assume. Tag mutability is also treated as a security defect in its own right (a TOCTOU vector where the artifact scanned is not the artifact run), which raises the stakes above bookkeeping. The remedy is two-sided and well-precedented: a registry-side immutability requirement that OPM must *state* as a deployment constraint, plus client-side refusal to overwrite an existing tag at publish. The yank question remains genuinely open, and the survey shows the ecosystems disagree on it (Maven: immutable forever, no deletion; npm/crates: restricted unpublish windows) — with the constraint that deleting an artifact breaks reproducibility for anyone who already resolved it. D3 makes `metadata.version` and the artifact tag the same value, which is only meaningful if a tag names one immutable artifact. If the registry permits overwriting an existing tag, then a consumer's pinned `v1.2.3` can change bytes under it and every downstream digest gate — including 0006's handoff verification — silently compares against a moving target. Unresolved: whether `opm module publish` and `opm catalog publish` refuse to overwrite an existing tag client-side, whether the registry enforces immutability server-side, and what the sanctioned recovery is for a bad publish (yank/deprecate metadata versus deletion, noting that deleting an artifact breaks reproducibility for anyone who already resolved it).

- **OQ13: Where does a catalog's version come from under D4?** Status: **resolved-by-D19** — a concrete SemVer committed in source, which is experiment 02 variant B's conclusion. D17 briefly answered "nowhere" by deleting the field; D19 reversed that, because the full version is what lets a module record which catalog build it was authored against and therefore what makes the too-old-platform check possible. FQNs remain major-keyed (D18), so the version is the compatibility signal rather than the match key. Original framing and the measured evidence follow. The candidate mechanisms are now measured against a live registry; the choice between them is still open. The direct catalog analogue of OQ6. Today the mechanism is a generated `identity/version_override.cue` that unifies over the `*"0.0.0-dev"` default in `identity/identity.cue` (`core/src/catalog.cue`'s doc comment: "Publish-time stamping targets `identity/version_override.cue`"; both artifacts inspected 2026-07-25 carry a correctly-stamped override). That is OQ6 option (b) — rewrite source, then derive — and it is compatible with D4 *only if* the override file is committed to the source tree rather than generated into the artifact during the push. **It is not:** the published artifact's own `identity/identity.cue` states it outright — "Publish-time stamping writes a **transient** `version_override.cue` into this package pinning a concrete SemVer; the committed tree always resolves `Version` to the `0.0.0-dev` default" (inspected 2026-07-25). So catalog publishing today writes bytes into the artifact that do not exist in source, which is the practice D4 rules out for modules. Whatever resolves this must reconcile the two rather than leave one artifact type stamping and the other deriving. Unresolved: whether `opm catalog publish` adopts the override file as the authored version site, replaces it with a plain authored `metadata.version`, or keeps generation but requires the generated file to be committed. Whichever wins must also close the placeholder hole — a catalog that reaches the registry still carrying `0.0.0-dev` should be refused at publish and at materialize, not silently indexed.

  **Measured 2026-07-25** across three experiments (cue v0.17.1; experiment 01 against a live registry at `localhost:5000`):

  - **The stamping mechanism does not merely risk a placeholder — it guarantees local/published divergence.** A catalog published the current way resolves to `…/transformers/foo@0.0.0-dev` from a local checkout and `…/transformers/foo@1.0.0` from the registry; a catalog with a committed concrete version yields byte-identical FQNs from both. Since transformer matching keys off those FQNs and `local-module.cue` `replaceWith` onto a catalog checkout is a sanctioned dev workflow, the divergence is reachable in ordinary use. Both trees `cue vet` clean, so only a cross-tree comparison surfaces it — which is why enhancement 0001's experiment 04 missed it: that experiment measured that stamping *works*, never whether local and published agree. (`experiments/01-catalog-local-vs-published-parity/`)
  - **`core`'s documented catalog default does not exist.** `core/src/catalog.cue:63` declares `version!: #VersionType | *"0.0.0-dev"` and `core/SPEC.md:576` describes it as a source-tree default. A required field's disjunction default never applies — the requirement wins. The dev-time ergonomics attributed to that line come from `identity.Version`, a plain field whose default does apply. Both the schema line and the SPEC paragraph are misleading about the mechanism regardless of how OQ13 resolves, and are worth correcting on their own. (`experiments/02-…/`, variant `a1`)
  - **Removing the default costs nothing at vet time.** Strict-committed and sentinel-default variants both pass plain `cue vet` and `cue vet -c`. 0001 D8's stated benefit — zero-friction dev-time vet — does not distinguish them; the friction avoided is one committed line, not a failing command. A strict schema with the version omitted fails immediately and by name (`catalog.metadata.version: field is required but not present`). (`experiments/02-…/`, variants `b`, `c`)
  - **The placeholder guard 0001 relies on cannot be made unbypassable.** Expressed in CUE, a `!="0.0.0-dev"` guard does not reject the sentinel — it eliminates the default branch and leaves the value *incomplete*, so it fires during development and reports an incompleteness error rather than a missing stamp. CUE has no publish-time to condition on, so the guard can only live in a publish task, where `cue mod publish` routes around it. This is the enforcement gap D6 rejects, restated for catalogs. (`experiments/02-…/`, variant `e`)
  - **A version-free catalog source tree is structurally dead**, exactly as for `#Module`: omitting the field fails at `#Catalog.metadata.fqn: reference "version" not found`, because the derived identity interpolates it. (`experiments/02-…/`, variant `d`)
  - **Enhancement 0001's `identity/` subpackage survives any answer here.** Removing it makes the catalog root and its transformer subpackage import each other, which CUE rejects (`package import cycle not allowed`, citing both files). Its purpose is import-graph topology, not stamping — so "commit a concrete version and stop stamping" changes what `identity.Version` contains without disturbing 0001 D7/D19. (`experiments/03-identity-subpackage-necessity/`)

  What the evidence does **not** settle: whether the concrete version is authored directly in `identity/identity.cue`, or whether `opm catalog publish` keeps a generated override file that must be committed (OQ6 option (b) applied to catalogs). Both satisfy artifact-bytes-equal-source-bytes; they differ in who edits the file and whether release automation writes to the source tree.

  **Prior art (`research/prior-art-version-agreement.md`, 2026-07-26)** bears on the placeholder half rather than the authoring-site half. Maven's `-SNAPSHOT` is the mature form of what `0.0.0-dev` gestures at, and it differs in every property that matters: it is a *suffix on a real version* (`1.2.0-SNAPSHOT`) so it names the release it is heading for; it is *explicitly authored* rather than appearing when the author says nothing; its mutability is *declared by contract* rather than accidental; it is served from a *separate repository*; and **Maven Central refuses to accept it at all**. OPM already has the namespace for free — SemVer prerelease syntax — so what is missing is the non-defaulted authoring and the registry-side refusal, not the notation. Separately, the survey confirms that generating the version into the artifact (the current `version_override.cue` mechanism) is a *build-output* pattern: `setuptools-scm` does exactly this and its own documentation says the generated `_version.py` should not be kept in version control. That is coherent when the artifact is a wheel; a CUE module's artifact **is** its source, which is why the same move produces experiment 01's divergence. External confirmation of D4 from a system that made the opposite choice for a defensible reason.

- **OQ14: What detects "this module changed" once the version lives in source?** Status: open. Surfaced by the publish-scenario walk on 2026-07-25. The `modules` repo answers "should this publish?" with a content checksum over each module's `.cue` files excluding `cue.mod/` (`modules/versions.yml` stores one per module; `publish:smart` compares and bumps on difference). Under D4 — and under D12, which puts the write in `opm module version set` rather than in publish — `metadata.version` is authored *in those same `.cue` files*, so a pure version bump changes the content hash. The detector stops answering "did this module's substance change?" and starts answering "did anything about this module change, including the act of versioning it." Today's flow happens to converge, because it stores the new checksum after publishing rather than before, but the signal no longer means what its comment says it means, and any flow that computes the checksum before deciding the version will oscillate. Candidate answers: hash the source with `metadata.version` masked out; drop content-hash detection entirely and let the authored version be the sole publish trigger (a version equal to the highest published tag means "nothing to do"); or keep the checksum purely as an advisory "you changed this and forgot to bump" warning rather than as the bump trigger. **Prior art (`research/prior-art-version-agreement.md`, 2026-07-26)** supplies a mechanism and a tension. release-please can update the version in *arbitrary* files through its generic updater: a line annotated `x-release-please-version` (in a comment) has its version replaced, so `version: "2.0.0" // x-release-please-version` in a module's `.cue` file would work directly. But that makes release-please a **second writer** of `metadata.version`, contradicting D12's "sole writer" claim, and one with no knowledge of the coupled `cue.mod` `@vN` edit that `version set` owns on a major bump. OQ14 should choose deliberately between (i) automation *calls* `version set`, so release-please contributes the decision but not the write and D12 survives intact, and (ii) adopting the annotation and narrowing D12 to "sole writer among OPM commands" — cheaper to wire, but it reintroduces a second mechanism that must independently get the major coupling right, which is the exact shape of drift this entry exists to remove. (i) is more consistent with everything else decided here. This interacts with D12 — `opm module version set` is what writes the version, so it is also what has to leave the detector in a coherent state — and with OQ12, since "nothing to do" is only a safe no-op if republishing a tag is refused anyway. Resolving it fixes what replaces `publish:smart`.

- **OQ15: What shape do `#Module.metadata.fqn` and the identity UUIDs take once the version is gone?** Status: **resolved-by-D16** — candidate (d): `metadata.modulePath` becomes the full CUE module path including `@vN`, `fqn` is that path, and the uuid formulas are unchanged. Original framing and the measured evidence follow. Deliberately pinned when D13 was taken — the decision to remove `metadata.version` was made on its own merits, and the replacement identity is a separate design question that should not be settled in passing. Today `fqn: "\(modulePath)/\(name):\(version)"` (`core/src/module.cue:23`) feeds `uuid: SHA1(OPMNamespace, fqn)`, which feeds `instance.uuid: SHA1(OPMNamespace, "\(module.uuid):\(name):\(namespace)")`, which is stamped on every rendered resource. Removing `version` leaves `modulePath` and `name` as the only identity inputs in source. Candidate shapes: (a) `modulePath/name` with no version component at all — module identity becomes "which module", and two majors of the same module share a uuid; (b) `modulePath/name@vN` carrying the major from the CUE module path, so incompatible majors are distinct identities exactly as CUE and Go treat them, and patch/minor upgrades keep one identity; (c) drop `fqn` entirely and compute `uuid` from `(modulePath, name)` directly, since nothing parses the module FQN — `library/opm/module/instance.go:103` returns it as an opaque string and the matcher keys off *primitive* FQNs, not module ones. (b) is the shape most consistent with D13's rationale, since the major is the one version component CUE deliberately keeps in the path; Go states the reasoning outright — major suffixes exist so the toolchain can treat multiple majors of a project as genuinely distinct modules.

  **Measured 2026-07-26 (cue v0.17.1), and it constrains every candidate that keeps the major.** `metadata.modulePath` is `opmodel.dev/modules` — it carries neither the name nor the major. The major exists in exactly one place, `cue.mod/module.cue`'s `module: "opmodel.dev/modules/jellyfin@v2"`, and **core's schema cannot see it**:

  - CUE exposes no builtin for "what module am I in." Confirmed by probe.
  - A module *can* read its own module file: `@extern(embed)` plus `_raw: _ @embed(file="cue.mod/module.cue", type=text)` and a `regexp.FindSubmatch` yields `"v2"`. Verified working. (`type=cue` is rejected — "encoding not (yet) supported" — so it is a text read plus a regex, not a structured one.)
  - This survives publishing: `cue.mod/module.cue` ships **inside** the artifact zip (confirmed by unzipping `opmodel.dev/modules/jellyfin@v2` tag `v2.0.2` from the workspace registry), so a registry-loaded module carries the file an embed would read.
  - **But the embed must live in the consuming module's own file, not in `core`.** `@embed` resolves relative to the file's own module, so a `@embed(file="cue.mod/module.cue")` written in `core` reads *core's* module file. Core therefore cannot derive a consumer's major; every module would carry the embed boilerplate itself.

  So keeping the major costs one of: **(i)** an authored `major` field in `#Module.metadata`, checked against `cue.mod` at publish and at acquire — one line, human-readable, mechanically verifiable, but it does put a version component back in source; **(ii)** per-module `@embed` boilerplate, self-deriving and unforgeable but requiring every module to carry an attribute + regex it did not ask for, and untested through `library`'s overlay load path (embed resolves relative to a module root, and registry loads stage a synthetic one — worth an experiment before relying on it); or **(iii)** candidate (d) below.

  **(d) Make `metadata.modulePath` the full CUE module path** (`opmodel.dev/modules/jellyfin@v2`) instead of the bare prefix. Then `fqn` *is* `modulePath`, the major comes along at no extra cost, and D1's derive-the-registry-address problem partly dissolves because the declared path already **is** the registry address rather than a prefix that must be recombined with `nameSnakeCase`. It still duplicates `cue.mod`'s `module:` line, so it needs the same publish/acquire check as (i) — but it is one authored string that is checkable in full, rather than a version fragment checkable in part. Costs: `#ModulePathType` changes shape, `name`/`nameSnakeCase` become a display projection whose agreement with the path leaf is now checkable *within one field*, and D9's owner-scoping simply changes the value. Resolving this fixes `core/src/types.cue:26-28`'s `#ModuleFQNType`, the four `core/SPEC.md` rationale paragraphs that justify the current shape, and the migration's final identity values. Note the uniqueness question the user raised is contained here: whatever replaces the version must still make two same-named modules from different publishers distinct, which D9's owner-scoped `modulePath` already supplies.

- **OQ16: Do `#Resource`, `#Trait`, and `#Blueprint` follow D17 to major-keyed FQNs?** Status: **resolved-by-D18** — yes, uniformly, and the exact catalog version becomes a kernel-held coordinate from the resolved tag rather than part of any FQN. Original framing follows. Opened by D17, which changes `#ComponentTransformer` FQNs to `@vN` because the catalog stamps them — but resources, traits, and blueprints are **not** stamped by `#Catalog` (they are reached transitively through each transformer's `required`/`optional` maps, per the note at `core/src/catalog.cue:55-58`), so they keep their independently-authored `version!` and `@semver` FQNs. That leaves the primitive FQN space internally inconsistent: transformers keyed `@v1`, resources and traits keyed `@1.4.0`, both matched through the same `#FQNType`. Three ways out: (a) extend D17 to every primitive, making `#FQNType` uniformly major-keyed — most consistent, and it makes patch releases of a resource non-events for matching, but it means two builds of a primitive at adjacent patches become indistinguishable, which `core/src/types.cue:43`'s comment says is deliberately not wanted today; (b) leave the split and widen `#FQNType` to accept either form, accepting that "what does an FQN's suffix mean" now depends on which primitive kind you are looking at; (c) give resources and traits a catalog-stamped identity as OQ10 contemplates, at which point they inherit whatever the catalog carries and the question collapses into OQ10. Note this interacts with OQ10 directly — that question asks whether a primitive's `modulePath` must equal its owning catalog's, and (c) would answer both at once. Resolving this fixes `#FQNType` and the matcher's key contract.

- **OQ17: How does a `vMAJOR.0.0-dev` catalog interact with the D19 compatibility floor?** Status: **resolved-by-D24** — it does not, because the placeholder is no longer `vMAJOR.0.0-dev`. The dev version is the latest published tag in the major, patch-bumped, with `-dev` appended, so it sorts above every release rather than below. Original framing follows. Opened by D20 meeting D19. Under real SemVer a prerelease sorts *below* its release, so a locally-developed catalog at `1.0.0-dev` compares as **older than every published 1.x** — and would therefore fail D19's floor check against any module built against `1.2.0`, even though the dev checkout is HEAD and almost certainly contains more than 1.2.0 did. The dev loop would break precisely when a developer is working on the catalog, which is when it must work. Candidates: (a) skip the floor check entirely when either side carries a `-dev` prerelease, trading the check away exactly where local changes make it least reliable; (b) make the placeholder sort *high* rather than low — a dev build is by construction ahead of every release, so something like `vMAJOR.MAX.MAX-dev` or a bare `vMAJOR` treated as unbounded expresses the truth better than `vMAJOR.0.0-dev` does; (c) keep the check and require developers to pin a floor-satisfying version by hand, which is the status quo failure mode wearing a new hat. Note the illustration in `schemas/target.cue` sidesteps this by comparing MAJOR.MINOR.PATCH numerically and ignoring prerelease ordering — under that simplification `1.0.0-dev` compares equal to `1.0.0` — so the schema currently states a *weaker* rule than a correct semver implementation would. `library/opm/materialize/filter.go:61` already uses a real semver library, so the production comparison will apply true prerelease ordering and will hit this. Resolving this fixes the placeholder's exact spelling and whether the floor check has a dev-mode exemption.

- **OQ18: Is `#Module.metadata.modulePath` authored, or derived from `cue.mod/module.cue`?** Status: **resolved-by-D23** — generated by OPM tooling from the `module:` line, never authored. The mechanism question it leaves behind is OQ19. Original framing follows. D16 records it as authored — one line duplicated with `cue.mod`, checked at publish and acquire. Deriving it instead would remove the duplication entirely, and both options produce the *identical* value locally and published, because both read the same file (`cue.mod/module.cue` ships inside the artifact zip — verified 2026-07-26 by unzipping `jellyfin@v2` tag `v2.0.2`). The choice is ergonomics, not correctness. **What is settled is where a derivation may live.** Measured 2026-07-26 (cue v0.17.1): `@embed` paths are resolved relative to the *embedding file's own directory* and cannot escape upward — a package at `identity/` embedding `cue.mod/module.cue` fails with `open cue.mod/module.cue: no such file or directory`, and `../cue.mod/module.cue` fails with `@embed: cannot refer to parent directory`. **So the derivation must sit in a file at the module root, beside `cue.mod/`; an `identity/` subpackage cannot host it.** That rules out giving `#Module` a catalog-style `identity/` package as the mechanism — and separately, modules have no structural need for one: the workspace modules are all single-package (`jellyfin`, `seerr`, `web_app` are two `.cue` files in one package with no subdirectories; `cert_manager` and `metallb` have a `crds/` subdirectory holding YAML, not CUE), so nothing computes an FQN from a module-wide constant across a package boundary and there is no import cycle to break. The catalog's `identity/` is a workaround for a cycle experiment 03 measured, not a pattern to copy. **`@embed` is ruled out (user decision 2026-07-26)** — it was a live option and is no longer one, regardless of the measurements above. The live options are therefore: **(a) authored**, as D16 records — one line duplicated with `cue.mod`, checked at publish and acquire; or **(c) generated at publish** into an `identity` package that is gitignored and exists only in the artifact, which is what `experiments/05-decided-shapes-module-catalog/` implements. The trade is explicit: (a) keeps artifact bytes equal to source bytes and leaves the committed tree independently evaluable by plain `cue vet`; (c) removes the hand-maintained duplication entirely but makes the artifact differ from source and means a fresh clone does not vet until an `opm` command has generated the package.

- **OQ19: Does generated identity target a subpackage or the artifact's own package, and can `core` supply the binding?** Status: **resolved-by-D25** — the artifact's own package for both, with catalogs additionally keeping `identity/` for their leaves; `core` cannot supply the binding. Original framing follows. D23 fixes that identity is generated; this asks where it lands. The proposal was an `identity/` subpackage referenced as `metadata: modulePath: id.ModulePath`, with that binding line "part of the schema so the author doesn't have to write it". **The binding cannot live in `core`**: `#Module` and `#Catalog` are defined in `opmodel.dev/core`, which cannot import a consumer's `identity` package — it does not know the consumer's path, and there is no CUE construct for "import a package relative to whoever is unifying me". So a schema-side `modulePath: id.ModulePath` is not expressible. Two ways to get the author-writes-nothing property anyway: **(i) generate a file in the artifact's OWN package** that sets `metadata: modulePath: "..."` directly — no subpackage, no import, nothing for the author to write, and it works for `#Module` immediately; **(ii) keep the `identity/` subpackage and generate the binding line into the root package too**, so the author still writes nothing but two generated files exist. For `#Catalog` the subpackage is not optional regardless — experiment 03 measured that removing it makes the catalog root and its transformer subpackage import each other (`package import cycle not allowed`), and the leaves need the constant at their own definition site to compute their FQNs. So the likely shape is asymmetric: modules get (i), catalogs keep `identity/` and additionally get a generated root binding. Resolving this fixes what `opm module publish` and the local build path actually write.

- **OQ20: Does `#Catalog` gain a `name` field?** Status: open. Opened by D26, which makes `#Module.metadata.name` snake_case and ties the module path's leaf to it. `#Catalog` has **no `name` field at all** today — its identity is `modulePath` alone, which is why the addressing half of this enhancement was always degenerate for catalogs. Applying D26's rule to catalogs therefore means *adding* a field rather than retyping one, and the only sensible value is the path leaf (`opm` in `opmodel.dev/catalogs/opm@v1`). For: symmetry with `#Module`, a leaf constraint catalogs currently lack, and a human-readable name for diagnostics that today must be parsed out of a path. Against: nothing consumes a catalog name — catalog FQNs carry no name segment, the matcher keys off primitive FQNs, and a field with no reader is the kind of surface D13 has been deleting. Note the catalog leaf is *not* a CUE package name the way a module's is, so the snake_case argument does not transfer directly. Resolving this fixes whether `#Catalog.metadata` grows or stays at `modulePath`.

- **OQ21: How does D24's dev version survive a committed `identity.cue`?** Status: open. Created by D27 meeting D24. D24 says an unpublished build carries `latest-in-major + 1 patch + -dev`; D27 says the version lives in a committed file holding a concrete value — normally the *last published* one. Those pull in opposite directions, and experiment 06 rules out the obvious escape. **In-memory override does not work**, for the same reason `@tag()` does not: a module that imports a locally-replaced catalog resolves that catalog's committed bytes, so an override the kernel holds in memory never reaches the transitive import. That leaves three real options. **(a) Tooling rewrites `identity.cue` on every dev build** — correct versions, but the working tree is dirty after any `opm module vet`, which is intolerable in a repo and would fight every diff. **(b) The committed value stands during development** — clean tree, but a module built against a locally-extended catalog records compatibility with the *published* version, so the D19 floor passes while the primitive it needs is missing; the failure moves from a clear "your catalog is too old" to a bare missing FQN, which is the diagnostic regression D19 exists to prevent. **(c) The dev version is written only by an explicit command** (`opm catalog version dev` or similar) that the developer runs deliberately and commits or reverts, making the dirty tree a chosen state rather than a side effect of vetting. (c) looks closest to D27's own logic — tooling writes files you can see, when you ask it to — but it means a developer who forgets is in case (b). Resolving this fixes what the local build path does to `identity.cue`, and whether D24 applies to committed artifacts at all or only to never-published ones.

## Recorded Non-Issues

Questions raised during design and closed without becoming Open Questions. Recorded so they are not re-opened.

- **Promoting or mirroring an artifact between registries does not conflict with D3.** `#PublishedModuleRef` binds `artifactPath` to `importPath`, which is derived from `metadata.modulePath` — and CUE resolves a module path to a *host* through the prefix→host mapping in `CUE_REGISTRY`, not through anything embedded in the path itself. So copying `opmodel.dev/m/<owner>/<name>` from a staging registry to production changes the host while the module path and the tag both stay put, and every invariant in this enhancement is stated over the path and the tag. Mirroring is transparent to D3, D6, and D9. (Raised 2026-07-25 during the publish-scenario walk.)
