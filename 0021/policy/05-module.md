# Class 5: module (`opmodel.dev/modules/<name>` and any third-party path)

**Carrier:** CUE module SemVer, major in the path, authored through the identity package (0011 D12, D15). **Surface:** the `#config` schema, compared by subsumption over accepted values (D2); whether stateful identity of rendered resources is a second surface is OQ1. **Bump:** the stable table, classified as follows. **Pre-stable:** OQ4. **Enforcement:** the already-published refusal and the cross-train major guard today; the compatibility gate is OQ5/OQ6.

| Change to `#config` | Class |
| --- | --- |
| Add an optional field, or a field with a default | additive |
| Loosen a constraint (widen a disjunction, drop a bound) | additive |
| Add a required field | breaking |
| Remove or rename a field | breaking |
| Tighten a constraint, change a field's type | breaking |
| Accept a field and stop reading it | breaking (behaviour, invisible to unification; stated because a gate cannot see it) |
| Change a default | OQ3 |
| Documentation only; the accepted value set is unchanged | fix |

> **Verbatim from `modules/CLAUDE.md`.**

**Major separation rule:** a registry path may exist on several trains (directory names differ — legacy `jellyfin_v016/` publishes `opmodel.dev/modules/jellyfin@v1`, the v1 train's `jellyfin/` publishes `@v2`), but two trains must never share a major for the same path. When promoting a module from an older train, bump its path major past that train's line. CI enforces this (`Cross-train major separation guard` in `publish.yml`).

> **Verbatim from `enhancements/0010/03-decisions.md`.**

### D41: Instance identity derives from the module's registry path, not from its FQN

**Decision:** `#ModuleInstance.metadata` gains an explicit `fqn`, and `uuid` derives from it:

```cue
fqn:  "\(#moduleMetadata.registryPath):\(name):\(namespace)"
uuid: #UUIDType & cue_uuid.SHA1(OPMNamespace, fqn)
```

`#Module.metadata` exposes `registryPath` — the module path with the major stripped, already computed as `_ref.registryPath` under D1. **Neither the module's version nor its major reaches instance identity.**

`#Module.metadata.fqn` and `.uuid` are **unchanged** and keep the major.

The two values answer different questions, and deriving one from the other forced them to agree when they should not:

- `module.uuid` is **artifact** identity — *which module is this*. `@v2` and `@v3` are genuinely distinct modules under both CUE and Go semantics (D1), so it must move across a major.
- `instance.uuid` is **ownership** identity — *which live resources does this manage*. It is the `module-instance.opmodel.dev/uuid` label `opm-operator/internal/apply/prune.go:107` reads, so it must survive every upgrade of the same deployment, a major bump included.

Both labels already ship on every rendered resource. The names promised they were different facts; this makes them so.

**Alternatives considered:**

- **Keep deriving `instance.uuid` from `module.uuid`** — today's shape, and this entry's as accepted. Rejected: it makes a `@v2 → @v3` upgrade orphan every resource the new major no longer renders, silently. D1 already reduced the blast radius from *every release* to *every major*, which is why this was not visible while D2 held; it does not remove it.
- **Take the major out of `#Module.metadata.fqn`,** so the existing derivation becomes major-free without touching `#ModuleInstance`. Rejected: it breaks artifact identity to fix ownership identity. D1 rejected dropping the major from artifact paths on its own grounds — for a module the path is the only thing distinguishing `@v1` from `@v2` — and that argument is unchanged.
- **Derive instance identity from the module's `name`** rather than its path. Rejected on collision: `opmodel.dev/modules/jellyfin` and `example.com/jellyfin` both carry `name: "jellyfin"`, so two unrelated modules deployed under one instance name in one namespace would fight over the same resources. A full module path is unique **by construction**, so `registryPath` distinguishes them structurally — measured 2026-08-03 against the owner-scoped spelling then in force: two such paths yield `a0be73cc-…` and `ebc35491-…`. *(Citation corrected 2026-08-04: this originally read "`registryPath` is owner-scoped under 0011 D5". 0011 D13 removed owner-scoping under `opmodel.dev` in favour of domain ownership, so the uniqueness now comes from the domain rather than from an owner segment. The property this alternative depends on is unchanged.)*
- **Add a second, major-free UUID to `#Module.metadata`** and derive the instance from that. Available, and rejected as a spare identity value: `registryPath` is already computed under D1 and has independent callers (it is the OCI repository every address-composition site in `cli` and `library` collapses into), whereas a second UUID would exist only to be hashed again.
- **Defer to a later entry.** Rejected on migration timing, which is the strongest argument for doing it now. This entry already moves every instance UUID once, and D18 settles that adoption is a one-time manual pass over an enumerable fleet. Landing this in the same window costs nothing extra and makes it the **last** time an instance UUID ever moves. Landed later it is a second fleet-wide relabelling, carrying the same silent-orphaning exposure through a second cutover.

**Consequences, each measured:**

- **`#TransformerContext.#moduleInstanceMetadata.fqn` has to pick a meaning.** It is filled today with `inst.ModuleFQN()` (`library/opm/schema/context.go:59`) — the *module's* FQN, under an instance-shaped name. With an instance FQN defined, the block exposes the **instance's**, and the module's takes its own key if a reader appears. Free today: measured 2026-08-03, no shipped transformer reads `.fqn` from that block — the same 117-use survey that found no reader for `.version`, all `.name` or `.namespace`.
- **Two majors of one module, deployed under the same instance name in the same namespace, now collide on `instance.uuid`.** Not a new constraint: rendered resource names are instance-scoped, so that pair already collides on names.
- **`#Module.metadata.uuid` keeps a reader** after losing this one — the `module.opmodel.dev/uuid` label. It does not become the reader-less field D33 and D16 delete.

**Rationale:** The owner label exists to answer "does this controller own this object", and the answer must not change because a module author made a breaking schema change. A major bump is a new *module* and the same *deployment*; the previous derivation could not express that, because it had only one identity to spend.

Stating the derivation as an explicit `fqn` rather than an inline interpolation inside `uuid` is what makes the "custom set of fields" reviewable in one place, and it mirrors `#Module`'s own `fqn → uuid` shape.

**Source:** User decision 2026-08-03, on a worked tree carrying this entry's target shapes; the invariance matrix (version bump, major bump, owner change, namespace change) measured against `cue v0.17.1` the same day. Prune behaviour at `opm-operator/internal/apply/prune.go:107`; `Status.InstanceUUID` repopulation at `opm-operator/internal/reconcile/moduleinstance.go:308`; context fill at `library/opm/schema/context.go:59`. **Restates the identity invariant now stated at D2**, and touches `#ModuleInstance`, whose shape is otherwise enhancement 0001's.

> **Verbatim from `enhancements/0010/03-decisions.md`.**

### D45: The version-major agreement is asserted in the identity package alone for `#Module` too

**Decision:** D43's holding transposes to `#Module`. `core` asserts no relation between `#Module.metadata.version`'s major and `modulePath`'s; `identity/identity.cue`'s `VersionMajor: Major` is the only assertion, reaching `metadata` through the wiring D2 establishes (`modulePath: id.ModulePath`, `version: id.Version`). **D40's `#Module` half is superseded**; its identity-package half is untouched, as it was for `#Catalog`.

This settles what D43 left explicitly undecided, and it settles it the way D43 recommended on the record. The two artifact types now answer "where is the major checked" identically, which is the asymmetry D2 and 0011 D12 spent two decisions removing.

**Alternatives considered:**

- **Keep the `core` assertion on `#Module` while `#Catalog` has none — the state D43 leaves behind.** Rejected: nothing distinguishes the two cases. Both write `ModulePath` and `Version` in an identity package that asserts the relation between them; both reach `metadata` by authored wiring; both have that wiring checked at publish by 0011 D12. A rule that binds one artifact type and not the other is a rule the next reader has to look up rather than know.
- **Drop both assertions.** Rejected on D40's measurement, which is unchanged and is why the identity-package half survives: `ModulePath: ".../jellyfin@v2"` with `Version: "3.0.0"` **vets clean**, and the disagreement then surfaces at `#SubscriptionSelection`'s `_majorAgrees` in a platform author's file, about a publisher's mistake they cannot fix.
- **Keep both `core` copies and reverse D43 instead.** Genuinely available, and rejected for D43's reason rather than by preference: for a conformant artifact the `core` copy re-derives the same relation over the same two values one hop downstream, and 0011 D8 plus D21 already refuse an identity file that does not match `#IdentityPackage`.

**Rationale:** The exposure this accepts is identical to D43's and is worth restating rather than inheriting silently: a module whose identity package is absent, hand-written or non-conformant carries **no major-agreement check any consumer can run**, because `identity/identity.cue` is never evaluated as a package by a consumer — it reaches them only through the values it produced. `cue mod publish` keeps working (D11), so that artifact class is not hypothetical.

Two things bound it. The residual failure is loud rather than silent — a version whose major disagrees with its path is caught at publish by 0011 D12's `metadata.version == id.Version` check for any artifact that goes through the tool. And D43's recommended follow-on removes the exposure for both artifact types at once: have `core` **export** `#IdentityPackage` and have each `identity/identity.cue` embed it, so `VersionMajor` comes from the definition rather than from an author remembering to write it. That is now cheaper than when D43 recorded it, because 0011 D21 already requires `#IdentityPackage` to ship in `core` and 0011 D22 puts `#CatalogMemberFQNGate` beside it.

**Source:** User decision 2026-08-05, taking D43's recorded recommendation. Measurements are D40's and D43's, unchanged; publish-side wiring check from 0011 D12; identity-file shape validation from 0011 D8 and D21. **Supersedes D40's `#Module` half; completes D43.**

**Revised:** 2026-08-08 — the decision stands. Its exposure paragraph inherits D43's, and so does D43's 2026-08-08 note: both named replacements are still unbuilt, so the relation this decision moved out of `core` is currently checked by nothing that runs. 0011's `core-identity-package` landed the schema on 2026-08-08 and nothing unifies against it yet. See D43.

> **Verbatim from `enhancements/0011/03-decisions.md`.**

### D15: The authored version is the trigger; an already-published version is always a refusal; nothing predicts a version

**Resolves:** OQ4

**Decision:** Publishing is decided by the version an author wrote, and by nothing else.

- **The trigger is the authored `Version`** in `identity/identity.cue`, written by `version set` or supplied by `--version` (D3, D12). Writing a version the registry does not hold *is* the decision to release.
- **An already-published version is always a refusal.** Publish resolves whether the tag exists and errors if it does, naming the artifact, the version, and that it must be bumped. There is no sweep mode, no `--skip-if-published`, and no invocation in which the condition is a success. This is the same client-side check D10 specifies from the immutability side, reached from the other direction.
- **Idempotency belongs to the sweep, not to publish.** The sweep resolves which artifacts carry an unpublished version and invokes publish only for those, rather than invoking publish on everything and relying on it to no-op. The filter is a registry lookup, so nothing is predicted and no ledger is consulted.
- **CI needs no notion of whether an artifact changed** — only of what the registry already holds. That is the trigger question this decision dissolves and the thing the checksum was doing wrong. A sweep over every module on `main` stays idempotent by construction; running it twice, or on every commit, changes nothing.
- **`modules/versions.yml` and the checksum machinery are deleted**, not demoted to advisory.
- **The "you forgot to bump" warning survives, sourced from git.** Has anything under a module's directory changed since the commit tagged with its current version? That is a `git diff`, it cannot drift out of sync the way a side ledger did, and it is a warning rather than a gate.
- **`branch-tag.sh` is retained unchanged.** The `-dev` prerelease path already derives a correct, deterministic version with no clock and no network, and OQ4 filed it as an open case that shipped code had in fact already closed.
- **Catalogs keep release-please, and nothing requires modules to adopt it.** Release-please decides a version and hands it to `version set` / `--version`; it must **not** write `identity.cue` directly through an `x-release-please-version` annotation, which would make it a second writer beside D3's and reintroduce the drift this design removes. Conventional commits stay a catalog convention rather than a requirement this decision imposes on `modules/`.

**Measured 2026-08-04, and this is why the checksum is deleted rather than kept.** `modules/versions.yml` lists twelve modules and **two** carry a `checksum` (`seerr`, `web_app`). `modules/Taskfile.yml`'s `publish` treats a missing checksum as changed — `if [ -z "$stored" ]; then … changed+=("$module")` — so ten of twelve are blind patch-bumped on every run. The mechanism presents as change detection and behaves as an unconditional bump. (The task is named `publish`. Several documents called it `publish:smart`, which is the name of the equivalent task in a deployment repository outside the workspace; corrected across `01-problem.md`, `02-design.md`, `06-operational.md` and `README.md` on 2026-08-04.)

**Alternatives considered:**

- **Conventional commits drive the decision** (OQ4 candidate (a)), with release-please calling `version set`. Rejected as a *requirement*, not as a practice: it is the only candidate that can distinguish a breaking change from a patch, and that is exactly the inference the author declined to build a system around. It stays in place for catalogs, where it already runs, and is not imposed on `modules/`, which has no release-please today and would need per-module components or a single repo-wide version to gain one.
- **Keep the checksum as an advisory warning** (OQ4 candidate (c)). Rejected on the measurement above and on redundancy: with a version now authored in-tree (D12), "files changed and the version did not" is a git question, and answering it from a committed ledger reintroduces the drift that left ten of twelve entries empty.
- **Hash decides *whether*, the author decides *what***. The author's intermediate proposal, and rejected on a case analysis rather than on taste. Across the four states — {substance changed, version bumped} — the hash agrees with the registry check when nothing changed and when both changed, is merely noisier when substance changed without a bump, and is **wrong when a version is bumped with no other change**: it reports "unchanged" and silently blocks a deliberate act, which is what an author does when escaping a bad tag or republishing after a registry incident. The registry lookup is correct in all four, and needs no ledger, no per-file hashing and no stored state.
- **Publish infers the version from the last published tag and increments.** Rejected by D3 already, and this decision does not reopen it: a tool cannot know whether a change is a patch, a minor or a major, and the fleet produced by trying is the evidence.
- **Skip rather than refuse when publish is run as a fleet sweep, and refuse when targeted — originally adopted here, then reversed.** This decision first had the registry lookup used "to *skip* rather than to *refuse* when publish is run as a fleet sweep", leaving which behaviour applied to a mode on the command, and it was carried as the last unsettled item on the command surface. Reversed by the author: it makes one condition mean two things depending on how the command was reached, and the mode itself would have needed a spelling nobody wanted to invent. The consistency argument is the stronger one — D10 already has publish "refuse client-side to overwrite an existing tag", so a skip in sweep mode would have been a carve-out from a rule the design had already stated, and carve-outs on refusals are how the producer-side half becomes decorative (`05-risks.md`, *a refusal that fires too easily gets routed around*, arriving from the opposite direction).
- **Always skip.** Rejected as bad on the interactive path, which is the one a human uses: a command asked to publish that exits zero having published nothing has reported success for a non-event.
- **Refuse, and have the sweep tolerate the specific exit code.** Viable and not chosen: it makes the sweep parse failure to detect a normal state, so a genuine error and an expected no-op arrive on the same channel and are distinguished by a number. Filtering first keeps the sweep's success path free of expected failures.

**Rationale:** In the author's words — "I don't want to develop and maintain a complex system that tries to predict what version to publish, I would rather it be up to the authors." What makes this cheap rather than merely simple is that the trigger question dissolves once versions are authored: the registry already knows what has been released, so nothing needs to infer it. The mechanism that was there to answer that question was answering it wrongly at a rate of ten modules in twelve.

That the check is a **refusal** rather than a tolerated no-op follows from the same place — in the author's words, "It should be a refusal. It should check against the registry and error." A command asked to publish that exits zero having published nothing has reported success for a non-event, and a mode flag that made the condition mean two things would have been a carve-out from a rule D10 already stated. Idempotency is a property the *caller* arranges by filtering, which keeps the sweep's success path free of expected failures.

The failure mode is stated rather than designed around: an author who changes code and forgets to bump gets silence — nothing publishes and nothing refuses. The git-sourced warning is what addresses it, and it is deliberately not a gate, because a gate here would block the fourth case above for the same reason the checksum did.

**Source:** User decision 2026-08-04. `modules/versions.yml` and `modules/Taskfile.yml`'s `publish` read 2026-08-04 (twelve modules, two checksums, missing-checksum-means-changed at `Taskfile.yml:143-145`); `catalog_opm/.tasks/branch-tag.sh` and `.github/workflows/branch-publish.yml` read the same day; release-please configuration from `catalog_opm/release-please-config.json`. **Resolves OQ4.** Depends on D12 for the authored module version and on D10 for tag immutability, which is what makes an unpublished version a safe trigger.
**Revised:** 2026-08-04 — absorbed D19, which reversed the skip-in-sweep half of the idempotency bullet and narrowed the CI claim. The trigger half is untouched: the authored version still decides a release, nothing predicts a version, and no ledger is consulted. D19 also closed the last item under the command-surface gate — whether an already-published version is a skip or a refusal — so no mode flag exists and nothing needs a spelling.
