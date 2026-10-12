# Migration map: 0012

source: 0012 @ 18705155d2c7312029132c30d2b106ca59e57125

The old text stays in git at that commit: `git show 18705155d2c7312029132c30d2b106ca59e57125:0012/03-decisions.md`. The 39 requirements are the lines of that file that start `- Rn:` under a `**Requirements:**` heading. Every `kept` or `merged` target is `capability/Requirement name` in `specs/` of this folder. A `cut` or `repo` target is the line of `cut-requirements.md` that starts with the old id. Decision D2 has no requirement. Nine requirement lines name Go packages (or, for D3:R8, hold a library-internal rule) and go to `cut-requirements.md` marked for the owning repo; two are tombstones of requirements the owner withdrew on 2026-10-09. 0012 restarts as a draft, so the open questions OQ4, OQ5, OQ6, OQ9 and OQ10 stay in the proposal. A decision row names one target for each of its dispositions, written `<disposition>: <name>` and separated by a semicolon; a free note goes in the Note column.

Totals: kept 25, merged 3, cut 2, repo 9, moved 0; together 39. The delta specs hold 28 requirements that carry the 28 live old requirements that are not named after Go packages.

## Requirements

| Old id | Disposition | Target | Note |
| --- | --- | --- | --- |
| 0012:D1:R1 | kept | shared-decisions/Both frontends decide alike |  |
| 0012:D1:R2 | kept | deletion-protocol/A skipped object is never deleted |  |
| 0012:D1:R3 | kept | deletion-protocol/Namespaces and CRDs are never deleted automatically |  |
| 0012:D1:R4 | kept | deletion-protocol/Objects OPM does not own are skipped |  |
| 0012:D1:R5 | kept | deletion-protocol/The hold verdict follows policy and outcome |  |
| 0012:D1:R6 | merged | object-ordering/Frontends order objects by kind class | the delete half of the one order |
| 0012:D1:R7 | kept | apply-verdict/Each object gets an apply verdict; apply-verdict/Ownership refusals follow the inventory; apply-verdict/An object being deleted is never applied | the verdict, the ownership refusals and the terminating-object refusal are three requirements |
| 0012:D3:R1 | repo | cut-requirements.md: 0012:D3:R1 | names the tier package; the intent is in the design theme |
| 0012:D3:R2 | repo | cut-requirements.md: 0012:D3:R2 | fence: the kernel imports no Kubernetes package |
| 0012:D3:R3 | repo | cut-requirements.md: 0012:D3:R3 | fence: what the tier imports |
| 0012:D3:R4 | repo | cut-requirements.md: 0012:D3:R4 | fence: the library checks that refuse a bad import |
| 0012:D3:R5 | repo | cut-requirements.md: 0012:D3:R5 | one module version for kernel and tier |
| 0012:D3:R6 | repo | cut-requirements.md: 0012:D3:R6 | the frontends adopt a package and refuse a copy; cli and opm-operator |
| 0012:D3:R7 | repo | cut-requirements.md: 0012:D3:R7 | the apply identity check moves from the helper tier |
| 0012:D3:R8 | repo | cut-requirements.md: 0012:D3:R8 | a library-internal rule, not a package name: no loop and no cluster action in the library |
| 0012:D4:R1 | kept | deletion-protocol/A frontend deletes only what the plan names |  |
| 0012:D4:R2 | merged | apply-verdict/Each object gets an apply verdict |  |
| 0012:D4:R3 | merged | object-ordering/Frontends order objects by kind class | submission in the library order; engine staging may refine it |
| 0012:D4:R4 | repo | cut-requirements.md: 0012:D4:R4 | names Flux and controller-runtime packages; cli |
| 0012:D4:R5 | kept | deletion-protocol/A stored deletion state advances identically |  |
| 0012:D4:R6 | kept | deletion-protocol/A deletion plan holds only deletions and skips |  |
| 0012:D5:R1 | kept | object-ordering/Frontends order objects by kind class |  |
| 0012:D5:R2 | kept | object-ordering/Kind-class order changes once |  |
| 0012:D5:R3 | kept | object-ordering/Order does not depend on the module |  |
| 0012:D6:R1 | kept | inventory-identity/Labels are stamped by the CUE render |  |
| 0012:D6:R2 | kept | inventory-identity/The render digest ignores the runtime name |  |
| 0012:D6:R3 | kept | inventory-identity/Any other difference changes the render digest |  |
| 0012:D7:R1 | kept | inventory-identity/The stale set ignores component and version |  |
| 0012:D7:R2 | kept | inventory-identity/The inventory digest depends on field values only |  |
| 0012:D7:R3 | kept | inventory-identity/Different inventories give different digests |  |
| 0012:D7:R4 | kept | inventory-identity/A digest change ships a migration note |  |
| 0012:D8:R1 | kept | apply-verdict/A foreign object is refused on every apply |  |
| 0012:D8:R2 | kept | apply-verdict/The adopt annotation overrides ownership refusals |  |
| 0012:D8:R3 | kept | apply-verdict/No other override exists |  |
| 0012:D8:R4 | kept | apply-verdict/A ModulePackage keeps its instance identity |  |
| 0012:D8:R5 | kept | apply-verdict/An object being deleted is never applied |  |
| 0012:D8:R6 | cut | cut-requirements.md: 0012:D8:R6 | tombstone: the install admission was withdrawn on 2026-10-09; the number stays |
| 0012:D8:R7 | cut | cut-requirements.md: 0012:D8:R7 | tombstone: the install deletions were withdrawn on 2026-10-09; the number stays |
| 0012:D8:R8 | kept | apply-verdict/An annotation for another instance is refused; apply-verdict/An object adopted elsewhere is let go; apply-verdict/An unknown identity counts every annotation as foreign; deletion-protocol/Objects OPM does not own are skipped | the two reasons of the refusal, what the instance does, the unknown-identity default and the delete half are four requirements |

## Decisions

| Old heading | Disposition | Target | Note |
| --- | --- | --- | --- |
| D1: The Kubernetes runtime surface homes in the library's Kubernetes tier (supersedes only 0006:D31's placement conclusion) | design; evidence | design: One tier for every Kubernetes decision; evidence: decision-log.md | the alternatives and the three single-actor defects are in decision-log.md; the rejected options are in the design |
| D2: The library is written for Kubernetes; no portability abstraction is maintained on its behalf | design | design: One tier for every Kubernetes decision |  |
| D3: The Kubernetes runtime decisions live in a fenced tier, `opm/k8s`, beside the kernel and inside the library module | design; evidence | design: The tier is fenced and mandatory; evidence: cut-requirements.md | its eight requirement lines name Go packages and are in cut-requirements.md; it amends 0009:D4, which the design states as prose |
| D4: The library owns the whole deletion sequence but only the per-object verdict and the order for apply | design | design: Deletion is a protocol and apply is a verdict |  |
| D5: Ordering is kind-class order in the Kubernetes tier; no module-internal ordering is planned, and cross-module order belongs to a future Bundle | design | design: Ordering is kind-class order |  |
| D6: Labels are stamped by the CUE render; the shared render digest ignores the runtime-name label value | design | design: Labels come from CUE |  |
| D7: The stale set is component-blind, and the inventory digest hashes a canonical field encoding | design | design: The inventory has one identity |  |
| D8: The apply guard runs on every apply, refusing foreign objects outside the inventory and any object adopted by another instance; a per-object adopt annotation is its only override | design; evidence | design: The apply guard runs every time; evidence: decision-log.md | the revision history and the withdrawn install admission are in decision-log.md |

## Open questions

| Old id | Disposition | Target |
| --- | --- | --- |
| OQ1 | design (resolved by D4) | Deletion is a protocol and apply is a verdict |
| OQ2 | design (answered 2026-09-14, amended 2026-10-02) | The tier is fenced and mandatory |
| OQ3 | design (answered 2026-09-01) | One tier for every Kubernetes decision |
| OQ4 | proposal (still open, blocks accept) | Open questions |
| OQ5 | proposal (still open, not blocking) | Open questions |
| OQ6 | proposal (still open, not blocking) | Open questions |
| OQ7 | design (resolved by D7) | The inventory has one identity |
| OQ8 | design (resolved by D8) | The apply guard runs every time |
| OQ9 | proposal (still open, blocks accept) | Open questions |
| OQ10 | proposal (deferred to 0009, not blocking) | Open questions |
| OQ11 | design (resolved by D6) | Labels come from CUE |
