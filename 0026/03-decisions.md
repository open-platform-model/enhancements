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

**Decision:** On every OPM catalog path a module imports, the render build holds the version the module's committed dependency list names, provided the platform admits it (D2). The render module's dependency list is still written by promotion from committed resolutions, never by a resolver or a render-time tidy; what changes against 0019 D13 is the source promoted on a catalog path: the module's list, not the platform's. Every other path the module carries, `core` included, is promoted from the module's tidied closure, so the list stays the complete main-module view 0019 D13 relies on. The build records the catalog versions it held, and that record is part of the render's identity.

**Alternatives considered:**

- **Platform-exact, the shipped rule (0019 D13).** The platform's pin is floor and ceiling. Rejected here because it makes the platform the throttle on catalog evolution and every platform bump a fleet re-render (Gaps 1 and 2).
- **Platform floor, module may raise, resolved by maximum-version selection.** Sound within the additive discipline, but it lets a pin below the floor be promoted silently, the failure mode this entry exists to remove; and 0019 D13 measured that authority fails by omission whenever a resolver is consulted. The floor survives as an admission bound (D2), not as a promotion target.
- **Module ships or selects transformer code.** Rejected by 0015 D10 and by the authority rule in 0019 D13. A version selects a published catalog artifact's bytes; the module still names no code.

**Rationale:** What the author tidied against is what the author tested. Discarding it made every render correct by policy rather than by construction. Keeping it costs nothing mechanically: the list is still a promotion, and the additive discipline that made the discard safe is what makes the shared-path check in D7 sufficient.

**Source:** User decision 2026-09-08 ("I want #Module to dictate which version of the transformers to use, but the Platform dictates which transformer to run").

---

### D2: A platform admits catalog lineages through a pure-data spec with a required floor and an optional ceiling; a pin outside the range is refused, never promoted

**Kind:** contract

**Depends:** 0010:D1

**Decision:** `#PlatformSpec` is the authored platform: metadata, type, and a path-keyed map of `#Subscription` entries. An entry names a lineage by its module path with the major (0010 D1), an `enable` flag, an optional `registry` override for where the path resolves, a required `floor` and an optional `ceiling`. The spec has no imports and no `cue.mod` dependencies of its own. A module importing a catalog path with no enabled spec entry is refused as not admitted. A pin below the floor or above the ceiling is refused naming the module, the path, the pin and the bound. An absent ceiling admits every release of the major at or above the floor. Same major is structural through the path; version ordering is checked by the kernel, since CUE has no semver comparison.

**Alternatives considered:**

- **Floor and ceiling as fields on today's `#CatalogEntry`.** Rejected: the entry embeds an import whose version cannot float, so a range on it describes nothing the import does.
- **Floor and ceiling in a `custom` block of the platform module's `cue.mod`.** Survives tidy and publish and co-locates with the pin, but keeps the platform an authored CUE module with imports, which D3 removes.
- **Optional floor.** Rejected: the platform's own build with no module in hand, for readiness and the inventory of 0015 D1, must import each static catalog at some version, and the floor is that version. An absent floor would mean "any release of the major" with nothing to build the module-less view at.
- **Required ceiling.** Rejected: it reintroduces a platform edit per catalog release before any module may use it, the throttle of Gap 1.
- **Promote a below-floor pin up to the floor instead of refusing.** Rejected: it is the silent re-route this entry removes, applied continuously rather than to new objects only. Refusal keeps the floor as a loud fleet-wide lever.

**Rationale:** Admission and version selection were one number doing two jobs. The spec does the first job and only the first. The floor earns its required status by being the reference version something else needs; the ceiling stays optional because the additive discipline, which 0015 D8 already leans on, is what makes an open upper bound tolerable, and a platform that wants to validate before admitting simply sets one.

**Source:** User decision 2026-09-08 (floor required for static catalogs, ceiling optional; "a new schema that allows for a catalog OCI url or ModulePath to be defined, and an optional floor and ceiling").

---

### D3: `#Platform` keeps its shape and is generated per resolution from the spec and the pins; offline and cluster forms converge on the spec

**Kind:** contract

**Depends:** 0019:D5, 0019:D6

**Decision:** The render-time `#Platform`, with `#CatalogEntry`, `#registry` and `#composedTransformers` exactly as 0019 D5 shipped them, is no longer authored. The kernel generates a platform module whose dependency list carries the catalog versions the build will hold and whose value imports and embeds each catalog in the build, one `#registry` entry per path, and consumes it in the single render build as today. Generation is keyed by the resolved catalog set plus the spec's generation and the accepted registrations that reached the build, so renders with the same resolution share one generated platform. The two authored forms of today, a hand-written platform module for offline renders and a Platform CR for the operator, become one: a `#PlatformSpec`, as a CR spec or as a file. 0019 D6's platform-package generation remains the operator's, and moves from once per CR change to once per distinct resolution.

**Alternatives considered:**

- **Keep an authored platform module and override catalog versions in the render list.** Works mechanically, since the import resolves through the render list either way, but leaves an authored import whose version is decorative and keeps two authored forms alive.
- **Drop the embedded catalog and return to a version string plus an out-of-band pull.** The pre-0019 shape. Rejected: the out-of-band pull produced the Go twin whose drift from CUE unification 0019 exists to delete.
- **Generate once per Platform CR change, as 0019 D6 does.** Impossible once the module's pin decides the version; the platform's catalog import must resolve at that version.

**Rationale:** A static import cannot float. Once the module's pin decides the version, the platform value has to be produced after the pin is known, and producing it from data rather than editing a file is what lets the offline and cluster forms carry the same fields. The transformer bytes still enter the build through the platform's import, so 0019 D13's authority rule keeps its footing: the module names a version of a published artifact, and the generated platform is what loads it.

**Source:** User decision 2026-09-08 ("there is nothing saying we cannot generate the #Platform definition and CUE module with its deps dynamically"; "a #Platform definition as it is TODAY").

---

### D4: A spec entry admits and bounds; it never loads a catalog

**Kind:** policy

**Decision:** Listing a catalog in `#PlatformSpec` does not put it in any build. A catalog enters a render build in exactly two ways: a consumer module imports it, or an accepted registration (0015 D3) supplies it. A static catalog admitted by the spec and imported by no module is absent from that module's build. The platform's own module-less build, for readiness and inventory, imports each enabled static catalog at its floor.

**Alternatives considered:**

- **Load every enabled catalog into every build.** Rejected: it drags catalogs a module never named into its render, at versions the module never chose, and reintroduces a platform-held version for them.

**Rationale:** Separating admission from loading is what allows the same entry shape to serve static and provider catalogs (D5): for a static catalog the entry admits and the module loads; for a provider catalog the registration admits and loads, and the entry, if present, only bounds.

**Source:** User decision 2026-09-08 (discussion of admission versus load for provider catalogs).

---

### D5: Provider catalogs use the same entry shape; the registration's derived version is the pick when no consumer pins the path, and the registration gains an author window

**Kind:** contract

**Depends:** 0015:D11, 0015:D3

**Decision:** A provider catalog is a catalog. When a consumer module imports it, D1 and D2 apply unchanged. When no consumer pins the path, the version the build holds is the registration's `version`, which 0015 D11 derives from the provider module's own dependency on its catalog and verifies at acceptance; that derivation is unchanged. The registration's claim gains `floor` and `ceiling`, each defaulting to `version`, authored by the provider module beside the operator release it deploys: the releases of the catalog whose emitted resources that operator accepts. The `transformer-registration` contract in catalog_opm carries the two fields with their defaults; the rendering transformer copies them to the CR. This is the first authored field on the claim, and 0015 D11 is amended to that extent: `catalog`, `version` and `provides` stay derived and verified; the window is authored, trusted because the CR already requires the platform-admin identity to apply.

**Alternatives considered:**

- **Derive the window from the catalog.** Impossible: a catalog release cannot vouch for releases after it. Only the provider module release, which post-dates the catalog releases it tested, can state the window.
- **Expose the window in the provider module's `#config` by convention, or inject it into `#config` for provider modules.** Rejected: `#config` is the deployer's surface, an installer could widen past what the author tested with nothing in CUE able to bound it, the platform team's ranges would then live in two file kinds, and core cannot inject a field tied to a catalog contract.
- **Keep the registration exact, no window.** The safe default is preserved by the defaults; a window is needed the moment a consumer may pin the provider catalog directly (D1), which today's exact claim cannot check anything against.

**Rationale:** The same rule with the provider module as the pinning module gives one vocabulary for static and dynamic catalogs. The window is the provider author's knowledge and nobody else's; defaulting it to the pin keeps every existing provider correct with no edit.

**Source:** User decision 2026-09-08 ("I would like if we could have the same ruleset for providers and catalogs"; the registration shape with `version`, `floor`, `ceiling` confirmed as "Good, that answers the operator side").

---

### D6: A spec entry for a provider catalog is optional and, when present, its range overrides the author's window; the registration's status reports the effective window and its source

**Kind:** contract

**Depends:** 0015:D3

**Decision:** A `#PlatformSpec` entry for a provider catalog's path is not required for the catalog to be admitted; admission is the accepted registration's (0015 D3), and install-and-register stays one act. When an entry exists, its `floor` and `ceiling` replace the registration's window, whole; when it does not, the registration's window binds. Acceptance writes the effective window and its source, spec or provider, to the registration's status, which the operator owns and no render overwrites. A spec range wider than the author's window is accepted with a warning condition on the registration naming both bounds. A spec range that excludes the registration's `version` is refused at acceptance, since the default pick would be inadmissible and nobody chose a replacement. Consumer pins are checked against the effective window.

**Alternatives considered:**

- **Intersect the spec range with the author's window.** Rejected: intersection can only narrow, and the platform team must be able to widen, for a catalog release that post-dates the provider module and that they have validated themselves.
- **Edit the CR.** Rejected: it is rendered output, reverted on the next reconcile, and a separately owned override field on it is a cluster hand-edit outside the platform's repository.
- **A spec-side pick override for the no-consumer-pin case.** Rejected as unnecessary: the pick moves by reinstalling the provider or by a consumer pinning inside the range; the spec's job is bounds.

**Rationale:** The author claims, the platform team decides, each in the file they already own, and the decision is attributable and reversible in the platform's repository. The claim survives as the baseline the override is measured against; without it the warning has nothing to compare.

**Source:** User decision 2026-09-08 (the platform team must be able to define floor and ceiling for dynamic catalogs; the optional-entry design confirmed).

---

### D7: The shared-path requirement check runs per render against the consumer's pins, and at acceptance against the spec floors

**Kind:** contract

**Depends:** 0015:D8

**Decision:** For every catalog the build holds, its committed requirement on each shared OPM-namespace path must be at most the version the build holds there, within the same major; a different major refuses unconditionally. With the consumer's pin deciding the held version (D1), the comparison 0015 D8 defines runs per render, against the consumer's pins, and a failure names the provider catalog, the consumer module, the path and both versions. It also runs at registration acceptance against the spec's static floors, so a provider that no admitted render could ever hold is refused where it can be named early. Acceptance-time success is necessary, not sufficient; the render-time check is the binding one.

**Alternatives considered:**

- **Acceptance only, as 0015 D8.** Sufficient when the platform held one version per path; not once pins are free.
- **Render only.** Loses the early refusal at the site that can name the provider; 0015 OQ7's attribution problem.

**Rationale:** The premise 0015 D8 rests on is unchanged: within a GA major the only incompatibility is a version-ordering fact readable from committed files. What moves is the value on the right of the comparison.

**Source:** User decision 2026-09-08; premise per 0015 D8.

---

### D8: Matching, the transformer-set derivation, admission authority and provider routing are unchanged

**Kind:** scope

**Decision:** The render build's match glue, the fold that derives `#composedTransformers`, and the buckets derived from it are exactly as 0019 left them. Static catalogs are admitted by the spec and provider catalogs by the RBAC-gated registration, as before. Provider routing, classes and capability-based selection stay 0015 D2's successor material. Floating an instance forward within a range without an owner's act is out of scope and gated on enhancement 0021's answers about what a compatible module change is.

**Alternatives considered:**

- **Fold routing in, since the spec now names ranges.** Rejected: a range bounds versions of one lineage; routing chooses between lineages. Different question, and 0015 D2 asked for it to be designed against a real two-engine instance.

**Rationale:** The entry changes which version's bytes reach the fold, and nothing about the fold. Stating that as scope keeps a reviewer from reading a version rule as a matching rule.

**Source:** User decision 2026-09-08.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
