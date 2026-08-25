# Class 3: catalog contract (resources, traits, blueprints)

**Carrier:** the member's own `apiVersion` on the Kubernetes ladder. **Surface:** the contract's shape at that level. **Bump:** additive-only inside a beta or GA level; a break is a level bump that may ship beside its predecessor. **Pre-stable:** the alpha rung, which promises nothing; a break at alpha *should* bump the alpha number (D5, below). **Enforcement:** publish gate plus the match rung; the check command is an aid. Promotion and retirement are enhancement 0020 (D1..D12), cited.

## Alpha contracts: bump the alpha number on a break (D5)

An alpha contract promises nothing and its publish gate is off (0010 D34, below). The policy adds one courtesy on top. When an alpha contract breaks, by adding a required field, removing or renaming a field, narrowing a type or changing a default, its author **should** bump the alpha number, `v1alpha1` → `v1alpha2`, instead of reshaping the same key in place. Nothing refuses an in-place break and nothing reports one; the bump is a signal to whoever matched on the old key that it no longer means what it did, delivered at the import line rather than as a `field not allowed` at render. Rung filing (0010 D49) already gives the new level its own directory, and skipping rungs is permitted (0020 D5), so `v1alpha2` is an ordinary address.

> **Verbatim from `enhancements/0010/03-decisions.md`.**

### D27: Inside one API version a contract is additive-only, and both ends enforce it

**Decision:** Within a single `apiVersion`, a primitive's definition may **add, never remove** fields or options. Two riders are part of the rule rather than notes on it:

- a newly added field MUST be optional or carry a default, since a new required field breaks every component authored against an earlier build; and
- an existing field's default is **immutable** — changing it adds nothing and removes nothing, and moves rendered output for every component that left the field unset.

Removing a field, narrowing a type, or changing a default requires a **new `apiVersion`**, which may ship alongside the old one in the same catalog build.

**The rule binds per level, not uniformly.** At **alpha** (`vNalphaM`) there is no promise at all — a build may remove a field, narrow a type or change a default without bumping, and 0011 D9's publish gate is off. At **beta** (`vNbetaM`) and **GA** (`vN`) the rule above applies in full, and a break requires a level bump (`v1beta1` → `v1beta2`, or a new major) which may ship beside its predecessor in one build. The ladder those forms come from, the day-one assignment per catalog, and the comparator that orders them are D34's.

Enforcement is split across both ends, deliberately: **at publish** by a compatibility gate (enhancement 0011 D9), and **at match** by the always-unify rung that already exists. The publish gate is level-aware for the same reason the rule is.

**Measured** (`experiments/02-primitive-closedness-skew/`, 7 of 7 cases as predicted under D26's exclusion):

- provider on 1.0.0, module on 1.1.0 **using** the added field → `spec.backup.retention: field not allowed`. Loud, and precisely when it matters — the module asked for something this provider cannot honour.
- same skew, module staying inside the shared fields → passes, and renders against the older provider correctly.
- provider *ahead* of the module → passes. This is the direction the promise is for.
- a provider whose build broke the promise by narrowing `schedule` → fails, naming both arms of the disjunction.
- **default drift → passes the match**, and the probe shows why that is not acceptable: after unification `spec.backup.mode` is `"retain" | "delete"` and **not concrete**. Neither build's default survives. The render then fails on an incomplete value, far from the catalog release that caused it, naming a field rather than a build.

**Alternatives considered:**

- **Publisher discipline alone.** Rejected: this is D13's own objection to D4 and it was fair. A promise nothing checks is a convention, and D17 already records that a third-party catalog author has no reason to copy a convention nothing checks.
- **Match-time enforcement only.** Rejected on the default-drift measurement above: the one violation that unification cannot catch is also the one that silently moves output, so the match rung cannot be the only gate.
- **Publish-time enforcement only.** Not chosen as sufficient, because `cue mod publish` keeps working and is what every artifact published to date used (D11's argument). Whether the read side gets its own counterpart is OQ13.
- **Forbid all change within a major.** Rejected: additive evolution is the normal case, and forbidding it would make every new field an `apiVersion` bump — which is exactly the cost D4 was rejected for.
- **Bind the rule uniformly at every API version, alpha included.** **Originally adopted here, then narrowed by D34 (2026-07-31).** It was the simpler rule and it made the gate uniform, but it commits a catalog to compatibility on shapes still known to be wrong: both workspace catalogs were on `1.0.0-alpha.*` with primitive shapes still moving, so declaring the promise everywhere would either freeze those shapes or be routinely violated. Carving alpha out costs exactly one class — the default drift `experiments/02` measured, which no consumer-side check catches — and under D34's day-one assignment that is confined to `catalog_opm_experimental`.

**Rationale:** The promise is what replaces the version join. Under D4 the key no longer guarantees that two builds agree, so something has to, and "additive-only inside a major" is both the weakest sufficient rule and the one CUE can check from both ends. The measurement is what makes it more than an aspiration: closedness makes the lagging-provider direction fail loudly on the exact condition that matters, which is the property the whole model rests on.

**Source:** User decision 2026-07-29. Every case measured in `experiments/02-primitive-closedness-skew/` against cue v0.17.1.
**Revised:** 2026-07-31 — absorbed D34's narrowing of scope: the rule binds at beta and GA, not at alpha. D34 stands as its own decision for the API-version ladder it defines.

> **Verbatim from `enhancements/0010/03-decisions.md`.**

### D34: Contract API versions follow the Kubernetes ladder, and the promise is keyed to the level

**Decision:** `#APIVersionType` admits the three Kubernetes forms — `vNalphaM`, `vNbetaM`, `vN` — and D27's additive-only rule binds **per level** rather than uniformly. `core/src/types.cue:22-24`'s `#MajorVersionType` (`^v[0-9]+$`) is untouched and keeps naming module majors; `#APIVersionType` is the widened sibling D4's contract keys read.

- **alpha (`vNalphaM`)** — no compatibility promise. A build may remove a field, narrow a type or change a default without bumping. 0011 D9's publish gate is **off** at this level.
- **beta (`vNbetaM`)** — D27 applies in full. A break requires a beta bump (`v1beta1` → `v1beta2`), which may ship beside its predecessor in one build.
- **GA (`vN`)** — D27 applies in full. A break requires a major bump, likewise shippable side by side.

The level-keyed scope now lives in **D27** itself, so the rule reads correctly where it is stated; what remains here is the ladder, its day-one assignment, and the ordering it requires.

**Day one, per catalog.** Every contract-bearing primitive in a catalog takes that catalog's level, so the judgement is per catalog rather than per primitive:

| Catalog | Contracts | `apiVersion` |
| --- | --- | --- |
| `catalog_opm` | 38 (7 resources, 26 traits, 5 blueprints) | `v1beta1` |
| `catalog_kubernetes` | 27 resources | `v1beta1` |
| `catalog_opm_experimental` | 3 resources | `v1alpha1` |

Transformers take no `apiVersion` — they keep the build SemVer (D4), so the ~50 of them are unaffected.

**The level is not the catalog's release prerelease, and conflating the two is the likely misreading.** A catalog's release version (`1.0.0-alpha.2`) and a contract's pre-stable level (`v1beta1`) are independent axes, and only the second decides whether D27 binds. A beta contract shipped inside an alpha catalog build is gated in full; an alpha contract inside a stable catalog build is not gated at all. Both spell "alpha", and the day-one table above assigns `v1beta1` to two catalogs that publish only `1.0.0-alpha.*` today — so the two values disagree in the live regime rather than in a constructed example.

**Ordering is not required for correctness and is required for diagnostics.** The match path is exact-key (`bucketTransformers`, `library/opm/compile/match.go:128`), so no comparator ever decides what matches. The one reader is `sortFQNsBySemVer` (`match.go:322-336`), which orders the alternatives in a `MissingFQN`. It gets a kube-aware comparator for contract keys while build keys keep SemVer — a split along a line D4 already draws.

**Not imported from Kubernetes, each for a stated reason.** Conversion and storage versions: Kubernetes needs them because it persists objects; OPM renders, so two `apiVersions` are two independent contracts and a module names one. Feature gates: OPM has no per-primitive opt-out, and the nearest analogue is coarser and already exists — `catalog_opm_experimental` is a separate subscription a platform takes or declines. Deprecation windows: Kubernetes's exist because cluster upgrades force version moves on a support lifecycle, and under D14 a platform moves only when someone edits `version:` in its own source, so any window would be arbitrary.

**Alternatives considered:**

- **A uniform gate at every level, with the ladder spelled but alpha still gated.** This was the recommendation offered and it was rejected on coherence: gating alpha enforces additivity on the one level whose definition is *no additivity promise*, which empties the label. Alpha's whole value is that it is honest about what it does not guarantee.
- **`v1` from the start with the gate on immediately.** Rejected: it commits to compatibility on catalogs that are all still pre-1.0 at the build level (`1.0.0-alpha.*`, `1.1.0-alpha`, `1.2.0-alpha.*`), and it leaves no honest label for a contract that genuinely is experimental — which `catalog_opm_experimental` exists to hold.
- **`v1alpha1` across the board on day one.** Rejected on measurement: `catalog_opm`'s entire contract history is 715 field-declaration additions against 30 removals (2815 lines added, 118 deleted), and inspection shows most of the 30 are the blueprint propagation-guard hoist (`81641e0`) rather than contract surface. These catalogs have behaved like beta or better since bootstrap; alpha would be a label their own history contradicts.
- **Enforcing "alpha contracts only in the experimental catalog" as a publish rule.** Rejected as unenforceable in general: it cannot bind a third-party provider catalog, and 0011 OQ7 is open on exactly that first-party/third-party boundary. It stays a first-party convention, and the real contract is the ordinary one — do not depend on alpha, and a platform's only lever is declining the subscription.
- **Keeping `#APIVersionType` narrow at `^v[0-9]+$`** (the "resolves the other way" branch `schemas/target.cue`'s comment anticipated). Rejected: it forces every pre-stable break to present as a GA-looking bump, so the string carries no stability signal at exactly the point in the project's life where one is most useful.

**Rationale:** The ladder is what the author asked for — alpha and beta handled the way Kubernetes handles them — and the measurements say the expensive parts of that model are the parts OPM does not need. Coexistence is already in D4. Ordering never reaches the matcher. What remains is a string form and a per-level promise, both cheap.

The level-keyed promise is also the more internally consistent reading of D27. D27 exists because D4's contract key no longer guarantees that two builds agree, so something has to; but "something has to" is a claim about levels that make a promise. Alpha makes none, and saying so plainly is better than enforcing a rule the label denies.

The day-one assignment follows the evidence rather than caution: `v1beta1` for `catalog_opm` and `catalog_kubernetes`, whose measured history is overwhelmingly additive, and `v1alpha1` for `catalog_opm_experimental`, which is the catalog whose name already says what its promise is.

One consequence is recorded rather than left to be discovered: **0011 D9's publish gate becomes level-aware.** It defers to D27 by name, so the carve-out propagates by reference rather than by amendment, but its own wording says *every primitive in the tree* and an implementer would check all of them — the gate must classify each primitive's `apiVersion` and run the pull-and-compare only at beta and GA. What that gives up at alpha is narrow and specific: closedness still fails a removed field loudly at match time, so the only class that goes unguarded is the default drift `experiments/02` measured, which surfaces as a deferred render failure. Under this decision's day-one assignment that is confined to `catalog_opm_experimental`'s three contracts. With both mainline catalogs at beta the gate is load-bearing from day one rather than deferred to `v1`, which raises the priority of the unmeasured `cue.Value.Subsume` question `02-design.md:86` records. The same carve-out would apply to OQ13's candidate (c) if a read-side check ever ships.

A second, smaller consequence: admitting the alpha/beta forms exposes a defect already in the tree. `sortFQNsBySemVer` switches comparison rule per pair — SemVer when both sides parse, lexical otherwise — which is not transitive. Measured against Masterminds v3: `v1alpha1 < v2`, `v2 < v10` and `v10 < v1alpha1` all return true, and the same three FQNs sort to `[v2, v10, v1alpha1]` or `[v1alpha1, v2, v10]` depending on input order. The kube-aware comparator this decision requires is also the fix.

**Source:** User decision 2026-07-31. `#APIVersionType` spelling measured against Masterminds v3 in `library/opm/compile` on 2026-07-31 (throwaway probe, removed after the run): `v1`/`v2` parse as `1.0.0`/`2.0.0`, `v1alpha1`/`v1alpha2`/`v1beta1` fail with `invalid semantic version`, and the resulting lexical fallback orders `v1` ahead of its own pre-releases. Contract counts and churn measured the same day across `catalog_opm`, `catalog_kubernetes` and `catalog_opm_experimental`.

> **Verbatim from `enhancements/0010/03-decisions.md`.**

### D35: Compatibility enforcement is publish-side only; a catalog check command is an aid, not a guarantee

**Decision:** D27's additive-only promise is enforced at **publish** (0011 D9) and at the **match rung**, and nothing else is a guarantee. There is no compatibility check on the render path, none at materialize, and none required before a platform's subscription moves.

A catalog check command ships alongside — 0011 D7's `opm catalog registry check` gains a compatibility mode — and it is explicitly an **aid**. It can be run deliberately against a published catalog by someone who did not publish it, and nothing requires it to have been run. It does not convert publish-side enforcement into a guarantee, and this entry does not claim it does.

**The exposure, stated plainly because the acceptance criteria ask for exactly this:** a catalog published outside `opm catalog publish` carries no compatibility promise OPM can verify on a consumer's behalf. `cue mod publish` keeps working (D11), so the chain 0011 D9's induction rests on is breakable by any publisher who declines the tool, and OPM reports nothing when it is broken. Under D34 that exposure exists at beta and GA only — alpha promises nothing, so it has nothing to break.

**Alternatives considered:**

- **The subscription-bump check — deferred, not rejected.** Under D14 the only moment a platform's catalog bytes change is an edit to `version:`, which makes that edit a determinate trigger with both builds nameable and no I/O on the render path. Recorded as future work rather than adopted now, and filed as [`open-platform-model/opm-operator#63`](https://github.com/open-platform-model/opm-operator/issues/63), because the operator is the actor that holds both the previous applied state and the incoming one without needing to read git.
- **A read-side check on every render or materialize.** Rejected: it puts a registry round-trip on the path D14 exists to keep offline and deterministic, and it reports to whoever renders next rather than to whoever caused it.
- **Treating the check command as the guarantee.** Rejected on D11's own reasoning: a check nobody is required to run is not something a consumer can rely on. Shipping it as an aid and saying so is honest; shipping it and calling it enforcement is not.
- **Materialize compares a newly-pulled build against another build of the same catalog it already holds.** Eliminated by D14 rather than argued: a subscription names one build, so materialize never holds two and this check could never fire. This was the free option when the question was filed, which is what raised the price of every remaining answer.

**Rationale:** The actor a read-side check protects against is prospective. All four catalog repositories in [`research/migration-inventory.md`](research/migration-inventory.md) are first-party, and D32's measurement found cross-catalog fulfilment entirely prospective — so the third-party publisher who declines `opm catalog publish` does not exist yet. The cost of being wrong is also bounded and legible: `experiments/02` measured that the removal class fails loudly at match (`spec.backup.retention: field not allowed`), leaving only default drift deferred, and that surfaces as an incomplete-value render error rather than as wrong output. Against a prospective actor and a bounded failure, a permanent read-side mechanism is not yet earned.

The check command is worth shipping anyway because it is nearly free: the `catalog` command group is being created for D7 and D9 regardless — measured 2026-07-31, `cli/internal/cmd/` today carries only `module`, `instance`, `config` and `operator` — and the comparator is D9's.

**One exposure this accepts that is not about third parties.** D14's reproducibility rests on a named tag meaning fixed bytes, and 0011 OQ3 records that OCI registries make immutability opt-in configuration. If a tag is overwritten, a named build's bytes change under a platform that edited nothing, and with no read-side check nothing in OPM notices. The deferred subscription-bump check is the mechanism that would; until it exists, tag immutability is a deployment constraint OPM **states** rather than a property it verifies.

**Source:** User decision 2026-07-31.

> **Verbatim from `enhancements/0010/03-decisions.md`.**

### D48: A raw-family contract's `apiVersion` mirrors the upstream Kubernetes API version, assigned at adoption

**Decision:** A `k8s-*` contract's `apiVersion` is the version of the upstream API it passes through: apps/v1 → `k8s-deployment@v1`, autoscaling/v2 → `k8s-hpa@v2`, an upstream beta arrives as `@vNbetaM`. The raw family's ladder is thereby **upstream-owned**: a contract graduates when upstream graduates, and a new upstream version is a new contract — which is D27's semantics by construction, since two upstream versions of one kind are two independent shapes. D34's day-one per-catalog table is superseded for the two absorbed catalogs: the per-catalog assignment survives only for the abstraction family (`v1beta1`; the ex-experimental members `v1alpha1`), and the raw family is assigned per member.

The default is **one version per kind per catalog build** — the version the vendored schema tree carries. Coexistence of two versions of one kind in one build is supported (the matcher keys on the full contract FQN and `availableApiVersions` already diagnoses a level mismatch by name) and reserved for genuine transition windows, such as an upstream deprecation overlap a single platform must straddle; the ordinary skew case — clusters on different Kubernetes versions — is served by different platforms pinning different catalog builds under D14. When two versions do ship, the current version's transformer keeps the bare name and the other suffixes its level (`k8s-hpa-v2beta2`), because a transformer carries no `apiVersion` (D44) and its name is its key.

`#APIVersionType` admits every form this produces unchanged, and `#APIVersionGated` prices the levels correctly without modification: upstream GA and beta carry D27's additive-only promise — which at those levels is precisely upstream's own API guarantee — and an upstream alpha, should one ever be worth vendoring, promises nothing.

**Alternatives considered:**

- **Blanket `v1beta1`, D34's original assignment for `catalog_kubernetes`.** Rejected: it launches GA-mirrored APIs at a level below the promise upstream already makes, and the eventual graduation moves the contract key — every module demanding `k8s-deployment@v1beta1` migrates for a change that changed no shape. Starting where upstream is avoids a scheduled pointless migration.
- **An OPM-owned per-member stability judgement.** Rejected: it invents a second opinion on a surface whose entire contract is "as upstream". The moment OPM's level and upstream's diverge, the label misleads in one direction or the other.
- **Mirroring the full upstream coordinate, group included, into the key.** Rejected: the group disambiguates rarely and would be paid for on every demand string (`k8s-apps-deployment`); D47's curation rule covers the rare collision.

**Rationale:** The raw family's one promise is fidelity to upstream, and a version key that mirrors upstream is that promise made structural. It also settles who moves the key: nobody at OPM — upstream does, and the catalog follows at adoption. The corner this backs into — several members at different majors within one kind space, versions coexisting during transitions — is priced by D49's filing scheme rather than left to accumulate as identifier suffixes.

**Source:** User decision 2026-08-10. Matcher coexistence support read from `schemas/target.cue` `#PrimitiveDemand.availableApiVersions`; `#APIVersionType` form coverage checked against `core/src/types.cue` the same day.
