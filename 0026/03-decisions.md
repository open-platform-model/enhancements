# Design Decisions: Module-Dictated Catalog Versions and the Generated Platform

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent**, never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** How that stays true depends on the entry's `status`:

- While the entry is **`draft`**, decisions are living text: a changed choice is an **in-place edit** to the existing `DN`, and the log never contains two conflicting decisions. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* (marked as previously adopted) before overwriting; a mere sketch may be replaced outright. A decision retracted outright keeps its number as a one-line tombstone (`### DN: (retracted, YYYY-MM-DD)`).
- Once **`accepted`**, decision bodies are **protected**. A change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields; existing bodies are edited only through the `enhancement-compaction` skill, which weaves stacked reversals into the decisions they reverse (lower number survives, vacated number keeps a tombstone), at latest in the mandatory pass immediately before the `implemented` flip.
- **`implemented`** entries are frozen; **`superseded`** entries are stubbed via compaction.

Either way the log stays safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed.

Each decision carries a `**Kind:**` line plus the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific: `"User decision YYYY-MM-DD"`, a URL, or a file path, so the provenance of a choice never gets lost. A decision revised in place or by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line. *Alternatives considered* always survives revision and compaction: it is what stops a rejected option being re-litigated later.

A decision that rests on another entry's decision also carries a `**Depends:** MMMM:DN` line (tokens only, comma-separated) directly after `Kind`, and `config.yaml.depends_on` lists exactly the entries those lines name; `task vet` enforces both directions and refuses a cycle. The test for whether the line is owed: *if that other decision were reversed, would this one need an `Amends:`?* If yes, it depends. A citation for precedent, contrast, or a delegated enforcement site is prose, not a dependency.

**The Kind gate.** A decision belongs in this log only if it passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Three kinds pass it:

- `contract`: changes what a consumer can observe or rely on: a schema shape, a command's semantics, a compatibility or refusal rule, a naming guarantee.
- `policy`: a posture OPM commits to ("publish never invents a version").
- `scope`: a boundary decision: what this entry defers, what a successor owns, what a supersession keeps.

A *mechanism* decision is how a repo achieves the contract: algorithm choice, code placement, internal wiring. It fails the admission test and belongs in the implementing slice's OpenSpec change in the target repo, decided when the code in front of the implementer is current. Measured evidence that *constrains* a contract (an experiment proving a primitive cannot express a rule) stays here, attached to the contract decision it constrains. The winning implementation design does not carry it.

**Prescriptive versus evidential.** The line that keeps mechanism out in practice: an entry never tells a repo *how to name a file, spell an identifier, lay out a directory, or structure its code*.

- Naming a path to **prove** something, or to say where something is emitted today, is evidence, and is wanted.
- The test: would deleting the named path change what an implementer is **obliged** to do, or only what a reader can **verify**? Obliged means prescription; it does not belong here. Verify means provenance; it stays.
- A decision may state that a name is part of the published contract (for example, a member name that reaches a key, or a command's flag) because that is what a consumer observes. It may not state what the file holding it is called.

---

## Decisions

### D1: A consumer module's committed catalog pin is the version its render holds

**Kind:** contract

**Depends:** 0019:D13, 0010:D14

**Amends:** 0019:D13

**Decision:** On every OPM catalog path a module imports, the render build holds the version the module's committed dependency list names, provided the platform admits it (D2). The render module's dependency list is still written by promotion from committed resolutions, never by a resolver or a render-time tidy; what changes against 0019 D13 is the source promoted on a catalog path: the module's list, not the platform's. Every other path the module carries, `core` included, is promoted from the module's tidied closure, so the list stays the complete main-module view 0019 D13 relies on. The build records the catalog versions it held, and that record is part of the render's identity.

**Requirements:**

- R1: On every catalog path a module imports, the render holds the version the module's committed dependency list names, provided the platform admits it.
- R2: Every other path the module carries, `core` included, is held at the version in the module's tidied closure; no resolver, tidy or maximum-version selection runs at render.
- R3: Every render records the catalog version it held on each path, and that record is part of the render's identity.
- R4: Two modules on one platform pinning different admitted releases of the same catalog each render at their own pin, and a platform catalog change moves neither.

**Alternatives considered:**

- **Platform-exact, the shipped rule (0019 D13).** The platform's pin is floor and ceiling. Rejected here because it makes the platform the throttle on catalog evolution and every platform bump a fleet re-render (Gaps 1 and 2).
- **Platform floor, module may raise, resolved by maximum-version selection.** Sound within the additive discipline, but it lets a pin below the floor be promoted silently, the failure mode this entry exists to remove; and 0019 D13 measured that authority fails by omission whenever a resolver is consulted. The floor survives as an admission bound (D2), not as a promotion target.
- **Module ships or selects transformer code.** Rejected by 0015 D10 and by the authority rule in 0019 D13. A version selects a published catalog artifact's bytes; the module still names no code.

**Rationale:** What the author tidied against is what the author tested. Discarding it made every render correct by policy rather than by construction. Keeping it costs nothing mechanically: the list is still a promotion, and the additive discipline that made the discard safe is what makes the shared-path check in D7 sufficient.

**Source:** User decision 2026-09-08 ("I want #Module to dictate which version of the transformers to use, but the Platform dictates which transformer to run").

---

### D2: A platform admits catalog lineages through a pure-data `#Platform` of `#CatalogAdmission` entries with a required floor and an optional ceiling; a pin outside the range is refused, never promoted; prereleases are admitted only by opt-in

**Kind:** contract

**Depends:** 0010:D1

**Decision:** `#Platform` is the authored platform: metadata, type, and a path-keyed map of `#CatalogAdmission` entries. An entry names a lineage by its module path with the major (0010 D1), an `enable` flag, an optional `registry` override for where the path resolves, a `prereleases` flag defaulting to false, a required `floor` and an optional `ceiling`. The platform has no imports and no `cue.mod` dependencies of its own. A module importing a catalog path with no enabled entry is refused as not admitted. A pin below the floor or above the ceiling is refused naming the module, the path, the pin and the bound. An absent ceiling admits every release of the major at or above the floor. With `prereleases` false, a pin carrying a prerelease suffix is refused as not admitted even when its ordering falls inside the range, and the bounds themselves carry no prerelease suffix, which CUE checks structurally; with it true, prerelease pins and bounds are admitted by ordering alone. Same major is structural through the path; version ordering is checked by the kernel, since CUE has no semver comparison.

**Requirements:**

- R1: An authored platform imports nothing and carries no dependency list of its own; it names each admitted lineage by module path with its major, with an enable flag, a required floor, an optional ceiling and a prerelease opt-in defaulting to off.
- R2: A module importing a catalog path with no enabled admission entry is refused as not admitted.
- R3: A pin below an entry's floor or above its ceiling is refused naming the module, the path, the pin and the bound; it is never promoted to a version inside the range.
- R4: An entry without a ceiling admits every release of the path's major at or above the floor.
- R5: With prereleases off, a pin carrying a prerelease suffix is refused even when its ordering falls inside the range, and a bound carrying a prerelease suffix is rejected at platform validation; with prereleases on, prerelease pins and bounds are admitted by ordering alone.
- R6: An entry without a floor, or whose floor or ceiling carries a major other than the path's, is rejected at platform validation.
- R7: The platform's own module-less build, for readiness and the contract inventory, holds each enabled static catalog at its floor, and never holds two majors of one catalog in one build: a platform admitting several majors of one catalog is built once per admitted major of that catalog or otherwise partitioned so that each build holds one (D9 R3, OQ11).

**Alternatives considered:**

- **Floor and ceiling as fields on the shipped `#CatalogEntry`.** Rejected: the entry embeds an import whose version cannot float, so a range on it describes nothing the import does.
- **Floor and ceiling in a `custom` block of the platform module's `cue.mod`.** Survives tidy and publish and co-locates with the pin, but keeps the platform an authored CUE module with imports, which D3 removes.
- **Optional floor.** Rejected: the platform's own build with no module in hand, for readiness and the inventory of 0015 D1, must import each static catalog at some version, and the floor is that version. An absent floor would mean "any release of the major" with nothing to build the module-less view at.
- **Required ceiling.** Rejected: it reintroduces a platform edit per catalog release before any module may use it, the throttle of Gap 1.
- **Promote a below-floor pin up to the floor instead of refusing.** Rejected: it is the silent re-route this entry removes, applied continuously rather than to new objects only. Refusal keeps the floor as a loud fleet-wide lever.
- **Name the authored value `#PlatformSpec` and the entry `#Subscription`** (this entry's first draft, 2026-09-08 to 2026-09-19). Rejected: `PlatformSpec` is a Kubernetes nesting convention leaking into core and leaves the public name on a generated artefact (D3), and a subscription, as the word is used by OLM and package managers, follows new releases on its own, which is exactly what this entry refuses to do. An admission admits and bounds, D4's own words.
- **Admit prereleases by ordering alone, no flag.** Rejected: semver orders `4.3.0-dev.5` above floor `4.2.0`, so every development tag inside a range would render on a platform whose team never opted in.

**Rationale:** Admission and version selection were one number doing two jobs. The platform does the first job and only the first. The floor earns its required status by being the reference version something else needs; the ceiling stays optional because the additive discipline, which 0015 D8 already leans on, is what makes an open upper bound tolerable, and a platform that wants to validate before admitting simply sets one. Prereleases are off by default because admitting them is a decision, and a range written in GA numbers should not admit anything a GA reader would not expect.

**Source:** User decision 2026-09-08 (floor required for static catalogs, ceiling optional; "a new schema that allows for a catalog OCI url or ModulePath to be defined, and an optional floor and ceiling"); user decision 2026-09-19 (the names `#Platform` and `#CatalogAdmission`; the prerelease flag).

**Revised:** 2026-09-30: R7 gains its one-major-per-build clause for side-by-side majors (D9). Holding every enabled static catalog at its floor in one build fails to evaluate once two majors of one catalog are admitted (experiments/01-one-major-per-build/, case A).

---

### D3: The shipped platform value moves to `#ResolvedPlatform`, unchanged in shape, and is generated per resolution from the authored `#Platform` and the pins; offline and cluster forms converge on the authored value

**Kind:** contract

**Depends:** 0019:D5, 0019:D6

**Amends:** 0019:D5, 0019:D6

**Resolves:** OQ8

**Decision:** The render-time registry 0019 D5 shipped as `#Platform`, with `#CatalogEntry`, `#registry` and `#composedTransformers` exactly as shipped, is renamed `#ResolvedPlatform` and is no longer authored; the name `#Platform` passes to the pure-data authored value of D2. The kernel generates a resolved-platform module whose dependency list carries the catalog versions the build will hold and whose value imports and embeds each catalog in the build, one `#registry` entry per path, and consumes it in the single render build as today. Generation is keyed by the resolved catalog set plus the authored platform's generation and the accepted registrations that reached the build, so renders with the same resolution share one resolved platform. The two authored forms of today, a platform module the CLI takes as an explicit directory and a Platform CR for the operator, become one: a `#Platform`, as a CR spec or as a file. A render takes a module and, optionally, an authored `#Platform`. A render given no platform is a platform-less path, stated as such: the kernel generates its resolved platform from the render's own pins alone, every pinned catalog is held, and D2's admission does not run. No `#Platform` is synthesized for it, so `#Platform` keeps meaning what a platform team wrote, and R1 and R3 hold for renders given a platform. The kernel generates the resolved platform on both paths; today the CLI generates the platform-less one itself, so delivering this decision moves that generation into the kernel. 0019 D6's platform-package generation remains the operator's, and moves from once per CR change to once per distinct resolution. The rename is a breaking change to a shipped core definition, admissible because `opmodel.dev/core@v2` is pre-GA; the only consumer of the shipped value is the kernel.

**Requirements:**

- R1: The render-time registry keeps the shape 0019 D5 shipped, under the name `#ResolvedPlatform`, and is never an authored input: a render given a platform takes that authored platform and a module, never a resolved platform.
- R2: The resolved platform for a render carries exactly one entry per catalog the build holds, at the version the build holds; an admitted lineage that no module imported and no registration supplied is absent.
- R3: For a render given a platform, one authored platform value, with the same fields, serves as the operator's Platform CR spec and as the offline file the render starts from; a hand-written platform module is no longer an input.
- R4: Platform-package generation happens once per distinct resolution, keyed by the resolved catalog set, the authored platform's generation and the accepted registrations, so renders with the same resolution share one generated package.
- R5: A render given no platform holds every catalog it pins at the pinned version, never two majors of one catalog (D9 R2; what happens to a module pinning two is OQ18), carries no registrations, and meets none of D2's admission refusals; no authored or synthesized `#Platform` takes part in it.

**Alternatives considered:**

- **Keep an authored platform module and override catalog versions in the render list.** Works mechanically, since the import resolves through the render list either way, but leaves an authored import whose version is decorative and keeps two authored forms alive.
- **Drop the embedded catalog and return to a version string plus an out-of-band pull.** The pre-0019 shape. Rejected: the out-of-band pull produced the Go twin whose drift from CUE unification 0019 exists to delete.
- **Generate once per Platform CR change, as 0019 D6 does.** Impossible once the module's pin decides the version; the platform's catalog import must resolve at that version.
- **Keep `#Platform` on the generated value and call the authored one `#PlatformSpec`** (this entry's first draft). Rejected: "nothing downstream learns anything new" protected only the kernel, which this workspace owns, at the cost of the public name resting on an artefact nobody authors. See D2's alternatives for the naming.
- **Synthesize a `#Platform` for a render given no platform, admitting exactly the render's pins** (OQ8's option A): one `#CatalogAdmission` per pinned catalog, floor and ceiling both at the pin, prereleases on when the pin is one, so every render goes through one admission step and one refusal vocabulary. Rejected: an admission that can never refuse is ceremony, and the value would be called authored while nobody authored it.

**Rationale:** A static import cannot float. Once the module's pin decides the version, the render-time value has to be produced after the pin is known, and producing it from data rather than editing a file is what lets the offline and cluster forms carry the same fields. The transformer bytes still enter the build through the resolved platform's import, so 0019 D13's authority rule keeps its footing: the module names a version of a published artifact, and the resolved platform is what loads it. What people author deserves the public name; what the kernel derives is named for what it is, a resolution, in 0010 D14's sense. With no platform there is no platform team whose authority an admission expresses, so a synthesized admission records nothing true; the platform-less path states what the CLI already does, at the cost of two input shapes at the kernel boundary.

**Source:** User decision 2026-09-08 ("there is nothing saying we cannot generate the #Platform definition and CUE module with its deps dynamically"; "a #Platform definition as it is TODAY"); user decision 2026-09-19 ("we switch #Platform over to become what we want from this enhancement and add #ResolvedPlatform which basically takes its place"); user decision 2026-09-29 on OQ8 ("B", chosen between a synthesized `#Platform` admitting exactly the pins and a platform-less path, with B recommended). Today's platform-less generation: cli `internal/platform/moduledeps.go`, 1.0.0-alpha.24.

**Revised:** 2026-09-29: today's offline form restated as an explicit platform directory; OQ8 resolved as a platform-less path, R1 and R3 narrowed to renders given a platform, R5 added.

**Revised:** 2026-09-30: R5 bounded by D9 R2, so the platform-less resolved platform also holds one major per catalog.

---

### D4: An admission entry admits and bounds; it never loads a catalog

**Kind:** policy

**Decision:** Listing a catalog in the authored `#Platform` does not put it in any build. A catalog enters a render build in exactly two ways: a consumer module imports it, or an accepted registration (0015 D3) supplies it, and a registration supplies it only to a resolution holding the major of the declaring catalog the provider was built against (D9 R4). A static catalog admitted by the platform and imported by no module is absent from that module's build. The platform's own module-less build, for readiness and inventory, imports each enabled static catalog at its floor, and never two majors of one catalog in one build (D9).

**Requirements:** none (policy; its observable consequences are homed elsewhere: an admitted-but-unimported catalog absent from the build is D3 R2, the module-less build at the floor is D2 R7)

**Alternatives considered:**

- **Load every enabled catalog into every build.** Rejected: it drags catalogs a module never named into its render, at versions the module never chose, and reintroduces a platform-held version for them.

**Rationale:** Separating admission from loading is what allows the same entry shape to serve static and provider catalogs (D5): for a static catalog the entry admits and the module loads; for a provider catalog the registration admits and loads, and the entry, if present, only bounds.

**Source:** User decision 2026-09-08 (discussion of admission versus load for provider catalogs).

**Revised:** 2026-09-30: the module-less build holds one major of a catalog per build once several are admitted, and a registration supplies only resolutions holding its declaring major (D9).

---

### D5: Provider catalogs use the same entry shape; the registration's derived version is the pick when no consumer pins the path, and the registration gains an author window

**Kind:** contract

**Depends:** 0015:D11, 0015:D3

**Amends:** 0015:D11

**Decision:** A provider catalog is a catalog. When a consumer module imports it, D1 and D2 apply unchanged. When no consumer pins the path, the version the build holds is the registration's `version`, which 0015 D11 derives from the provider module's own dependency on its catalog and verifies at acceptance; that derivation is unchanged. The registration's claim gains `floor` and `ceiling`, each defaulting to `version`, authored by the provider module beside the operator release it deploys: the releases of the catalog whose emitted resources that operator accepts. The `transformer-registration` contract in catalog_opm carries the two fields with their defaults; the rendering transformer copies them to the CR. This is the first authored field on the claim, and 0015 D11 is amended to that extent: `catalog`, `version` and `provides` stay derived and verified; the window is authored, trusted because the CR already requires the platform-admin identity to apply. The window carries no `prereleases` flag; whether it needs one is OQ7.

**Requirements:**

- R1: A consumer module importing a provider catalog's path renders at its own committed pin, checked against the effective window, under the same admission rules as a static catalog.
- R2: When no consumer pins a provider catalog's path, the render holds the registration's derived version.
- R3: A provider module may state a compatibility window, a floor and a ceiling, on its registration; each defaults to the registration's version, so a provider that states none is unchanged in behaviour, and catalog, version and provides stay derived and verified.
- R4: The window reaches the cluster on the rendered registration with its defaults filled, so the claim is readable without the provider module in hand.

**Alternatives considered:**

- **Derive the window from the catalog.** Impossible: a catalog release cannot vouch for releases after it. Only the provider module release, which post-dates the catalog releases it tested, can state the window.
- **Expose the window in the provider module's `#config` by convention, or inject it into `#config` for provider modules.** Rejected: `#config` is the deployer's surface, an installer could widen past what the author tested with nothing in CUE able to bound it, the platform team's ranges would then live in two file kinds, and core cannot inject a field tied to a catalog contract.
- **Keep the registration exact, no window.** The safe default is preserved by the defaults; a window is needed the moment a consumer may pin the provider catalog directly (D1), which today's exact claim cannot check anything against.

**Rationale:** The same rule with the provider module as the pinning module gives one vocabulary for static and dynamic catalogs. The window is the provider author's knowledge and nobody else's; defaulting it to the pin keeps every existing provider correct with no edit.

**Source:** User decision 2026-09-08 ("I would like if we could have the same ruleset for providers and catalogs"; the registration shape with `version`, `floor`, `ceiling` confirmed as "Good, that answers the operator side").

---

### D6: An admission entry for a provider catalog is optional and, when present, its range overrides the author's window; the registration's status reports the effective window and its source

**Kind:** contract

**Depends:** 0015:D3

**Decision:** A `#Platform` admission entry for a provider catalog's path is not required for the catalog to be admitted; admission is the accepted registration's (0015 D3), and install-and-register stays one act. When an entry exists, its `floor` and `ceiling` replace the registration's window, whole; when it does not, the registration's window binds. Acceptance writes the effective window and its source, platform or provider, to the registration's status, which the operator owns and no render overwrites. A platform range wider than the author's window is accepted with a warning condition on the registration naming both bounds. A platform range that excludes the registration's `version` is refused at acceptance, since the default pick would be inadmissible and nobody chose a replacement. Consumer pins are checked against the effective window.

**Requirements:**

- R1: A provider catalog is admitted by its accepted registration alone; no admission entry for its path is required.
- R2: When an admission entry exists for a provider catalog's path, its floor and ceiling replace the registration's window whole; when none exists, the registration's window is the effective one, and removing the entry makes the author's window bind again.
- R3: The registration's status reports the effective window and its source, platform or provider.
- R4: A platform range wider than the author's window is accepted with a warning condition on the registration naming both bounds.
- R5: A platform range that excludes the registration's version is refused at acceptance.
- R6: A consumer pin on a provider catalog's path outside the effective window is refused naming the module, the path, the pin and the bound.

**Alternatives considered:**

- **Intersect the platform range with the author's window.** Rejected: intersection can only narrow, and the platform team must be able to widen, for a catalog release that post-dates the provider module and that they have validated themselves.
- **Edit the CR.** Rejected: it is rendered output, reverted on the next reconcile, and a separately owned override field on it is a cluster hand-edit outside the platform's repository.
- **A platform-side pick override for the no-consumer-pin case.** Rejected as unnecessary: the pick moves by reinstalling the provider or by a consumer pinning inside the range; the platform's job is bounds.

**Rationale:** The author claims, the platform team decides, each in the file they already own, and the decision is attributable and reversible in the platform's repository. The claim survives as the baseline the override is measured against; without it the warning has nothing to compare.

**Source:** User decision 2026-09-08 (the platform team must be able to define floor and ceiling for dynamic catalogs; the optional-entry design confirmed).

---

### D7: The shared-path requirement check runs per render against the consumer's pins, and at acceptance against the platform floors

**Kind:** contract

**Depends:** 0015:D8

**Amends:** 0015:D8

**Decision:** For every catalog the build holds, its committed requirement on each shared OPM-namespace path must be at most the version the build holds there, within the same major; a different major refuses unconditionally. With the consumer's pin deciding the held version (D1), the comparison 0015 D8 defines runs per render, against the consumer's pins, and a failure names the provider catalog, the consumer module, the path and both versions. It also runs at registration acceptance against the platform's static floors, on each shared path the floor of the admitted entry sharing the provider's major (D9), so a provider that no admitted render could ever hold is refused where it can be named early. Acceptance-time success is necessary, not sufficient; the render-time check is the binding one.

**Requirements:**

- R1: For every catalog a build holds, its committed requirement on each shared OPM-namespace path is at most the version the build holds there within the same major, a different major refusing unconditionally; a render violating this is refused naming the provider catalog, the consumer module, the path and both versions.
- R2: The same comparison runs at registration acceptance against the platform's static floors, taking on each shared path the floor of the admitted entry that shares the provider's major (D9), and a provider no admitted render could hold is refused there naming the provider and the path.
- R3: A provider accepted at registration can still be refused at render when a consumer's pins do not hold the versions it requires; acceptance never exempts a render.

**Alternatives considered:**

- **Acceptance only, as 0015 D8.** Sufficient when the platform held one version per path; not once pins are free.
- **Render only.** Loses the early refusal at the site that can name the provider; 0015 OQ7's attribution problem.

**Rationale:** The premise 0015 D8 rests on is unchanged: within a GA major the only incompatibility is a version-ordering fact readable from committed files. What moves is the value on the right of the comparison.

**Source:** User decision 2026-09-08; premise per 0015 D8.

**Revised:** 2026-09-30: the decision and R2 name which floor is compared when several majors of one catalog are admitted (D9).

---

### D8: Matching, the transformer-set derivation, admission authority and provider routing are unchanged

**Kind:** scope

**Decision:** The render build's match glue, the fold that derives `#composedTransformers`, and the buckets derived from it are exactly as 0019 left them. Static catalogs are admitted by the authored platform and provider catalogs by the RBAC-gated registration, as before. Provider routing, classes and capability-based selection stay 0015 D2's successor material. Floating an instance forward within a range without an owner's act is out of scope and gated on enhancement 0021's answers about what a compatible module change is.

**Requirements:** none (scope; reaffirms 0019:D5's fold, 0015:D3's admission split and 0015:D2's routing deferral)

**Alternatives considered:**

- **Fold routing in, since the platform now names ranges.** Rejected: a range bounds versions of one lineage; routing chooses between lineages. Different question, and 0015 D2 asked for it to be designed against a real two-engine instance.

**Rationale:** The entry changes which version's bytes reach the fold, and nothing about the fold. Stating that as scope keeps a reviewer from reading a version rule as a matching rule.

**Source:** User decision 2026-09-08.

---

### D9: A platform may admit several majors of one catalog; each resolution holds exactly one major per catalog

**Kind:** contract

**Depends:** 0010:D1, 0010:D37, 0015:D2, 0015:D3, 0015:D8

**Amends:** 0010:D37, 0015:D2, 0015:D3

**Decision:** A platform may admit several majors of one catalog side by side, so that a catalog major can be upgraded one module at a time. Admitting `opmodel.dev/catalogs/opm@v4` and `opmodel.dev/catalogs/opm@v5` is two `#CatalogAdmission` entries, because an entry is keyed by module path with its major (D2, 0010 D1). The major is settled per resolution, before the resolved platform is written: the module's own pin names the major, and the resolved platform holds that major and no other major of the same catalog (D1, D3). No build ever holds two majors of one catalog, so the two-majors conflict cannot arise inside a render, and contract keys, the render glue and matching stay exactly as they are (D8). Four things change around that rule:

- **The module-less build is partitioned.** The platform's own build for readiness and the contract inventory never holds two majors of one catalog (D2 R7, revised); how it is split is OQ11.
- **A provider joins only resolutions holding the major it was built against.** How resolution learns that major is OQ9.
- **The one-provider count is taken per resolution, which amends 0010 D37.** 0010 D37 says a platform must carry exactly one transformer requiring a provider-fulfilled contract, and refuses two by naming both catalog paths and the contract key. What survives: each resolution carries exactly one provider of each provider-fulfilled contract it demands, and two providers serving the same major of the declaring catalog are still refused by name. What changes: the count is taken on each resolved platform, not across everything a platform admits, and two providers serving different majors of the declaring catalog are not two providers of one contract, because each can only match components of its own major (experiment 02). Against 0015 D2 the same change reads at the authored platform: it may carry both such providers.
- **Registration acceptance judges per declaring major.** What survives of 0015 D3 is the refusal of a second provider of a contract; what changes is that the refusal compares providers serving the same major of the declaring catalog only. The shared-path comparison of 0015 D8, as amended by D7, is taken against the admitted entry of the provider's own major.

A module whose own dependencies import two majors of one catalog is refused at resolution, so migration across a major is per module (OQ10 asks whether per component is also needed). The same rule holds on the platform-less path (OQ18).

**Requirements:**

- R1: An authored platform may admit several majors of one catalog as separate admission entries, and admitting or disabling one major never changes what a render of a module on another major holds.
- R2: Each resolved platform holds at most one major of any catalog: a render of a module pinned to one major holds that major and no other major of the same catalog.
- R3: The platform's module-less build for readiness and the contract inventory never holds two majors of one catalog in one build, and a platform admitting two majors of one catalog evaluates and reports readiness.
- R4: A resolution includes a registered provider only when the provider was built against the major of its declaring catalog that the resolution holds; a provider built only against another major is absent from that resolution.
- R5: The single-provider count of 0010 D37 is taken per resolution: two registered providers of one contract serving different majors of the declaring catalog are both accepted and never counted against each other, and two serving the same major are still refused.
- R6: A module whose own dependency list imports two majors of one catalog is refused at resolution, naming the module, the catalog path and both majors.
- R7: Registration acceptance refuses a contract conflict only between providers serving the same major of the declaring catalog, and compares a provider's shared-path requirements against the admitted entry of the provider's own major, refusing a major mismatch only when no admitted entry shares that major.

**Alternatives considered:**

- **Put the catalog major into every contract key** (module-qualified keys, `opmodel.dev/catalogs/opm@v5/traits/backup@v1alpha1`). Measured end to end on 2026-09-30 through a patched core (`experiments/03-module-qualified-keys/`) and a real render through the shipped library (`experiments/08-render-module-qualified-keys/`): disjoint routing per major, one provider build serving two majors, and a module split across majors by component all worked. The same holds for the major as a key path segment (`experiments/04-major-segment-keys/`), which also needs a ban on registry paths ending in a major-shaped element. Rejected: every catalog major re-keys every contract it declares, unchanged ones included; the published opm@v4 needs a legacy flag to keep its keys, which is a third authored identity field; the publish gates change; and the user rejected changing contract IDs ("Instead of forcing @v5 into the contract, can't we utilize the already existing FQN or similar").
- **Keep shared keys and make the major a matching scope**, identity being the pair of contract key and catalog major in the render buckets and the inventory. Measured end to end on 2026-09-30 through a patched core (`experiments/05-major-as-matching-scope/`) and a real render with a patched render glue, with no artifact republished (`experiments/09-render-major-as-matching-scope/`). Rejected: it reshapes every consumer of the inventory, core pins, library types, CLI output and two operator CRD fields, in one lockstep release, and it promotes provenance (`catalogVersion`, 0010 D25) into matching, which 0010 D26 keeps out of the match comparison.
- **Count providers and refuse conflicts across the whole platform, the shipped rule (0010 D37, 0015 D2, 0015 D3).** Rejected for side-by-side majors: k8up@v2 built on opm@v4 and k8up@v3 built on opm@v5 each match only their own major's components, yet counted together they read as two providers of one contract and the platform is refused as over-subscribed (experiment 02).
- **One major at a time, the shipped behaviour.** A second major can be on record only disabled; experiment 01 case D. Rejected: a catalog major upgrade is then all at once across the fleet, the fleet-wide move this entry exists to remove.

**Rationale:** 0026 already carries most of this. An admission entry is keyed by module path with its major, so two majors are two entries, and each render's resolved platform holds exactly the catalog versions the module pins, omitting admitted lineages it does not import. Settling the major before `#ResolvedPlatform` is written keeps the code impact small: the resolved platform, the fold, the glue and matching never meet two majors of one catalog, so none of them changes. What had to be added is everything that looks at more than one resolution: the module-less build, provider selection, the provider count and registration acceptance. Two measurements fix those requirements. With shared keys a build holding two majors fails to evaluate and, with that conflict sidestepped, both majors' transformers claim every component (experiment 01). A provider built on the old major is disqualified for new-major components at plain unification, so counting it against a new-major provider is a false over-subscription (experiment 02). Refusing a module that imports two majors keeps each resolution to one major without a matching change.

**Source:** User decision 2026-09-30 ("The #Platform becomes a list of catalogs we 'subscribe' to. The #ResolvedPlatform is the exact catalog match that we did. #ResolvedPlatform is the one that is used in the rendering, that means we minimize the code impact by handling the matching of exact major before #ResolvedPlatform is written. So #ResolvedPlatform will never have this kind of conflict problem."; "Add it to 0026. For all open questions you found add them as open questions."); goal "so that we can update the catalogs". Measured 2026-09-30 with cue v0.17.1 against `core` 2.0.0-alpha.12: `experiments/01-one-major-per-build/`, `experiments/02-provider-serves-its-major/`. The rejected alternatives: `experiments/03-module-qualified-keys/`, `experiments/04-major-segment-keys/` and `experiments/05-major-as-matching-scope/` in core, `experiments/08-render-module-qualified-keys/` and `experiments/09-render-major-as-matching-scope/` through library `30f08c1`; the shipped behaviour through the same library: `experiments/07-render-shipped-core/`. User decision 2026-09-30 that D9 amends 0010 D37 ("it should amend"), and that the evidence be reproducible ("I would like it reproducible").

**Revised:** 2026-09-30: states the amendment of 0010 D37 plainly (the count taken per resolution; providers serving different majors of the declaring catalog not counted together), adds 0010:D37 to Amends, and re-cites the alternatives to reproducible experiments 03 to 09.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
