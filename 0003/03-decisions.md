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

---

## Open Questions

- **OQ1: Does `opm publish` *enforce* or *generate* the canonical coordinates?** Status: open. Two modes: (a) enforce — read the author's `cue.mod/module.cue` `module:` path and `package` clause and reject the push if they don't match `#CanonicalModuleRef`; (b) generate — synthesize the conformant `cue.mod` from metadata so the author never writes it. Enforce is less magical and keeps authored source authoritative; generate is more ergonomic but hides the path. Could support both (generate with a `--check`-only mode). Resolving this fixes the cli command's contract.

- **OQ2: How is the import qualified when the package name is needed?** Status: **resolved-by-D5**. A bare `import "path@vN"` binds, verified empirically through enhancement 0006's C2 fixture work and the C3 handoff e2e.

- **OQ3: Does the library *derive* the reference from metadata or *record* the fetched reference at load?** Status: open. With D1, deriving from metadata is sufficient *if* every consumed module conforms. Recording the exact `modPath@version` the registry loader fetched by (on `*module.Module`) is strictly more robust for non-conforming third-party modules, at the cost of a new field on the module type. The two compose: derive as the rule, record as the safety net + validation input. Resolving this fixes whether `module.go` gains a field.

- **OQ4: How do existing non-conforming in-repo modules migrate?** Status: open. `web-app` (testdata) is published at a hyphenated leaf `…/web-app@v1` with package `web_app` and `metadata.version 0.1.0` (an `@v1`/`0.1.0` mismatch); it must move to `…/web_app@v0`. Are there other workspace modules whose `cue.mod` leaf ≠ `nameSnakeCase`? Migration renames published identities, so it needs an inventory + a hard-switch vs transition-window call. Resolving this fixes the `affects` fixture work and the rollout sequence.

- **OQ5: How does the convention degrade for third-party modules not published via `opm publish`?** Status: **resolved-by-D6**. Hard error at acquire, naming both the expected and actual coordinates. Best-effort fallback was rejected because it makes a wrong-artifact condition survivable and therefore invisible.

- **OQ6: What does a version override flag on `opm module publish` mean under D4?** Status: open. D4 makes `metadata.version` authoritative, which appears to leave no room for a `--version` flag — but the publishing workflow needs one (release automation, pre-release tags, republishing a fixed build). Three candidate shapes:
  - **(a) Assertion.** `--version` is accepted only when it equals `metadata.version`; a mismatch is refused. Useful as a CI guard ("publish exactly what I reviewed"), changes nothing about authority.
  - **(b) Rewrite-then-publish.** `--version` writes the value into `metadata.version` in the *source file*, then derives from it. This is stamping into source rather than into the artifact, so artifact bytes still equal source bytes and D4's reproducibility rationale holds. It effectively makes publish a release command, and pairs naturally with OQ1's "generate" mode.
  - **(c) Tag-only override.** `--version` changes the pushed tag without touching metadata. **Ruled out** — it reintroduces exactly the drift D3 removes.

  Resolving this fixes the publish command's contract and interacts with OQ1: if publish may rewrite `module.cue`, "generate" largely subsumes "enforce". Note also that whichever shape wins must not let release automation (release-please and the `modules` repo's bump-and-publish task) reintroduce a second source of truth.

- **OQ7: Does `#Catalog` get the same treatment, and who owns it?** Status: open. `core`'s `#Catalog` declares `version!: #VersionType | *"0.0.0-dev"` — a *default*, meaning a catalog can silently publish under a placeholder version. Catalog FQNs embed that version and transformer matching keys off it, so the failure mode is the already-familiar "no matching transformer" rather than a legible error. The same D3/D6 pair applies. This entry's scope says `#Catalog` publishing belongs to enhancement 0001; resolving this decides whether the invariant is specified here and implemented there, or moves wholesale.
