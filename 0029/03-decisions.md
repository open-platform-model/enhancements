# Design Decisions: Gated Ownership Transfer from CLI to Operator

This document records every design choice, with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**: never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, a changed choice is an in-place edit to the existing `DN`, with an evidence-backed old position folded into *Alternatives considered*. Once `accepted`, bodies are protected and a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract`, `policy` or `scope`) and passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Mechanism decisions belong in the implementing OpenSpec change in the target repo.

Two experiments run beside this draft. D2, D3 and D6 carry requirements whose final wording waits on them; each such dependency is an Open Question in [`07-questions.md`](07-questions.md) that names the experiment that resolves it.

---

## Decisions

### D1: A forward-only transfer command returns

**Kind:** contract

**Depends:** 0006:D16

**Amends:** 0006:D7

**Decision:** `opm instance handoff` returns as the one supported way to move a CLI-owned instance to operator ownership. It moves ownership forward only: operator to CLI stays out of scope, as 0006:D16 decided, and that decision stands unchanged. What survives of 0006:D7: a CLI command verifies before it flips, flips once, and waits for the operator's first reconcile. What changes against 0006:D7: the gate set is re-specified by D2 and D3, because the command 0006:D7 described was removed for checking too little, and the reverse mode it named is gone for good.

**Requirements:**

- R1: The CLI offers a command that moves a CLI-owned instance to operator ownership, and offers none that moves an operator-owned instance back.
- R2: A refused transfer leaves the instance's record exactly as it found it: owner, spec, annotations and status unchanged.
- R3: A transfer that fails after the owner changed is reported as a failure that left the instance operator-owned, with where to look next; the CLI never reverts the owner.

**Alternatives considered:**

- **Export only (0014) as the path off the CLI.** A user who wants the operator, not Git, would have to commit a tree to get there, and committing an exported tree for a CLI-owned instance is itself an unverified transfer (0014's third question). Not chosen: the owner chose to revive the command.
- **Write the owner on apply (an owner choice on `opm instance apply`).** The removal change ruled this out explicitly, and an apply that also changes ownership merges two operations whose failures need different remedies.
- **Restore reverse transfer.** 0006:D16's reasons hold: operator-written control-loop status left on a record that flips back, and a relinquish race. The dogfood case that might want undo, the operator's own instance, never transfers (D2 R4).

**Rationale:** The ownership model the command rested on stayed in place when the command was removed: the owner field, the operator's hands-off rule, the recorded digest, the thin editor. What was missing was a gate, not a model. Reviving the command on the same model keeps one user-visible step between "the CLI applied it" and "the operator reconciles it", which is the story 0006 was written for.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)"). Removal reason quoted from cli PR 196 and its archived change `cli/openspec/changes/archive/2026-08-31-remove-instance-handoff/proposal.md`.

---

### D2: The transfer's gate set, and what success means

**Kind:** contract

**Depends:** 0006:D11, 0006:D38, 0006:D40, 0028:D4

**Amends:** 0006:D7

**Decision:** Before writing anything, the transfer requires every one of these to hold, checked cheapest first:

1. The cluster gates every mutating CLI path runs: the instance CRD present, its field floor met, the operator's version within the CLI's ceiling.
2. The operator is installed and ready.
3. The instance's record exists and is CLI-owned.
4. The instance is not the one that deploys the operator itself (0028:D4).
5. The record carries no local-provenance marker (D6).
6. The record names a complete published coordinate: module path and version.
7. The render skipped no contract.
8. The record carries the render digest of what the CLI applied.
9. The applier identity the user names can apply, and if asked to prune can delete, every entry of the recorded inventory (D3).
10. The module resolves through the operator's own registry mapping (D4).
11. A strict re-render reproduces the recorded digest. It resolves through that mapping only, ignores any local replacement, uses a module cache no earlier fetch could have filled, renders against the cluster Platform (0006:D11), and replays the recorded values.
12. The record's generation is unchanged since it was read for gate 3.

A force option skips gate 11's comparison and nothing else. Then one write sets the owner to `operator`, restates the verified module and values, and records the applier identity and prune intent. Success is 0006:D40's inventory-stable reconcile: ready for the written generation, the inventory entry set unchanged, the revision incremented, nothing pruned.

What survives of 0006:D7: operator ready, CLI-owned, a published and resolvable coordinate, a digest re-render, force limited to the digest, and a bounded wait. What changes: gates 4, 7, 9 and 10 are new; gate 11 resolves through the operator's mapping rather than the CLI's; gate 12 is the stale-snapshot guard the old implementation added; and the write records the applier identity, which 0006:D7's single-field flip never did.

**Requirements:**

- R1: The transfer writes nothing to the cluster until every gate holds; any refusal names the gate and the remedy.
- R2: A refusal that needs no registry access is reported before any registry access is made.
- R3: A forced transfer skips only the digest comparison; a missing coordinate, an unreachable module, a missing applier right, a local render, a skipped contract or the operator's own instance is never overridden.
- R4: The instance that deploys the operator is never transferred.
- R5: The verification render resolves the module through the operator's reported registry mapping, never the CLI's own, and cannot be satisfied by a module cached before the transfer started.
- R6: The verification render uses the cluster Platform; when it cannot be read, the transfer refuses rather than falling back to another platform source.
- R7: A digest mismatch is reported with both digests and, where the CLI can tell, which input moved: the module bytes, the Platform, or the values.
- R8: When the record changed between verification and the write, the transfer refuses and leaves the owner unchanged; it never writes a spec it did not verify.
- R9: After a successful write, the instance's module and values equal the verified ones, and its owner, applier identity and prune intent are the ones the transfer wrote.
- R10: The transfer reports success only when the operator has reconciled the written generation as ready, with the same inventory entry set, an incremented revision and nothing pruned; the managed-by relabel is reported, not counted as a change.

**Alternatives considered:**

- **The old chain unchanged (the delivered rule, 0006:D7 with 0006:D38 and 0006:D40).** It stranded every instance on a stock install, because nothing checked who applies. Not chosen: it is the removed command.
- **Verify reachability through the CLI's own mapping, as the old chain did.** It proves the CLI can fetch, which is not the question. Not chosen; D4 gives the CLI the operator's mapping.
- **Let force skip the reachability gate too.** A forced transfer of a module the operator cannot fetch fails on the first reconcile with no way back (D1 R3). Not chosen.
- **Re-read and flip the fresh spec when the generation moved.** Nothing verified that spec. Not chosen, for the reason the old implementation gave.
- **An operator-side admission webhook as the only gate.** The operator cannot run gate 11 without a second render path, and a webhook outage would block every write to every instance. Not chosen as the primary gate; D5 keeps a reconcile-time backstop instead.

**Rationale:** Each new gate answers a way the old command, or a hand flip, strands an instance. Gate 9 is the removal reason. Gate 10 closes the case where the CLI fetches from a registry the operator cannot see. Gate 7 refuses a render the operator can never reproduce, because the operator never skips a contract. Gate 4 keeps the operator from adopting the instance that can delete it. Ordering cheap reads before the registry render keeps the common refusals fast and offline, which the old chain already did.

Gate 11's comparison is a self-comparison: the CLI re-renders with its own runtime name and compares to its own recorded digest, so 0006:D40's ban on cross-actor digest comparison is untouched. 0012:D6, which drops the runtime name from the digest, does not change this gate's meaning.

R5 and R9 wait on evidence. Whether a CLI-side fetch through the operator's mapping predicts the operator's own fetch is measured by experiment 01 (OQ1). Whether the flip leaves server-side-apply field ownership the verdict should also judge is measured by experiment 02 (OQ4).

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)": revive the old gate chain plus applier-identity and registry-reachability gates). Old chain read from cli commit `093b9761` and the archived change `cli/openspec/changes/archive/2026-07-20-cli-instance-handoff/`. Pending evidence: `experiments/01-provenance-digest-reachability/`, `experiments/02-applier-identity-and-field-transfer/`.

---

### D3: Applier identity is completed at transfer, never guessed

**Kind:** contract

**Depends:** 0006:D17

**Amends:** 0006:D7

**Decision:** The user names, at transfer, the service account the operator will apply the instance as and whether the operator prunes it. The transfer refuses when either is unstated. It never falls back to the operator's default account or the controller's own identity. Before writing, the transfer asks the cluster's authorizer whether that account may do what the operator will do with every entry of the recorded inventory: read, create and update it, and delete it when pruning is asked for. It also asks whether the operator's own identity may act as that account. The write records the named account and the prune intent on the instance, so the identity the operator uses is the one the gate checked. What changes against 0006:D7: its flip wrote only the owner, leaving the applier to whatever the operator defaulted to, which is the defect that removed the command.

**Requirements:**

- R1: A transfer without a named applier account, or without a stated prune intent, refuses before any write.
- R2: The transfer refuses when the named account does not exist in the instance's namespace.
- R3: The transfer refuses when the authorizer denies the named account any right the operator needs on any recorded inventory entry, naming the entry and the right; delete rights are checked only when pruning is asked for.
- R4: The transfer refuses when the operator's own identity may not act as the named account.
- R5: After the transfer, the instance records the named account and the stated prune intent, and the operator applies it as that account.
- R6: When the person running the transfer lacks the right to ask the authorizer about another identity, the transfer refuses and names that right; it never treats an unanswered review as a pass.

**Alternatives considered:**

- **Infer the operator's default account.** The default is an operator flag, empty by default, and it can change after the transfer without the instance noticing. Not chosen: the instance would apply as whatever the operator is configured with on the day of each reconcile.
- **Create the account and its RBAC as part of the transfer.** Granting rights needs rights the user may not have, and a tool that writes RBAC decides a security posture for the user (0014's second question faces the same choice). Not chosen for this decision; a helper is OQ6.
- **Check two representative kinds, as the old end-to-end precondition did.** It proves nothing about the kinds it skipped. Not chosen: the gate checks every recorded entry.
- **Default the prune intent to on, or to off.** Either default silently decides whether a later delete removes workloads. Not chosen: the CLI never wrote the field, so the transfer is the first moment anyone states it.

**Rationale:** The removed command stranded instances because the operator applied as an identity nobody chose. Making the user name one, and proving it against the exact entries the operator will apply, turns the stranding into a refusal before anything changes. Recording the identity on the instance keeps the proof valid after the transfer: the operator uses what was checked, not what its flags say later. The transfer is an operator-adoption step and already needs the cluster Platform, so needing the right to review another identity's access fits the administrator context 0006:D17 allows for it.

Whether an access review over the inventory predicts the operator's apply is measured, not assumed. An RBAC object in the inventory is the known gap: the authorizer can allow creating a role while escalation prevention still refuses the role's content. OQ2 holds R3's wording open until experiment 02 reports.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)", naming the applier-identity gate). Removal reason quoted from cli PR 196. The operator's impersonation precedence (instance account, then default flag, then its own client) read from `opm-operator/internal/apply/` on 2026-10-04. Pending evidence: `experiments/02-applier-identity-and-field-transfer/`.

---

### D4: The operator reports the module registry mapping it resolves with

**Kind:** contract

**Decision:** The operator reports, on the cluster Platform's status beside the operator version it already reports there, the module registry mapping it resolves modules with: the effective value after its own precedence of flag, environment and built-in default. The CLI's reachability gate (D2, gate 10) and verification render (D2, gate 11) read it. A transfer against an operator that does not report it refuses and names the upgrade. Credentials are out of scope: the operator presents none, so the mapping is the whole of what decides where it fetches from.

**Requirements:**

- R1: The cluster Platform's status reports the module registry mapping the running operator resolves with, and it changes when the operator restarts with a different mapping.
- R2: The report carries no credential.
- R3: A transfer against an operator that does not report a mapping refuses and names the operator upgrade that adds the report.
- R4: The verification fetch presents the same registry credentials the operator does, which is none.

**Alternatives considered:**

- **Read the operator Deployment's arguments.** It misses the environment and default arms of the precedence, and it ties the CLI to how the operator happens to be deployed. Not chosen.
- **An operator-side probe the CLI asks to resolve the module.** It proves reachability from the operator's own network position, which a CLI-side fetch cannot. Not chosen yet: it needs a request channel the operator does not have, and experiment 01 measures whether the simpler report is enough (OQ1).
- **Reuse the Platform status's catalog registry list.** That list is the catalog subscriptions the Platform resolves, not the module registry mapping. Not chosen: different data under a similar name.

**Rationale:** Reachability is a property of the operator, so the operator must say what it is. The Platform is the singleton the operator already owns and the CLI already reads for the version ceiling and the verification render, so the report costs no new resource and no new read right. R4 keeps a CLI holding registry credentials from passing a gate the anonymous operator would fail.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)", naming the registry-reachability gate). The operator's registry precedence read from `opm-operator/cmd/main.go` at release 1.0.0-beta.5; the Platform status fields read from `opm-operator/api/v1alpha1/platform_types.go` the same day.

---

### D5: The operator refuses to adopt what the transfer would refuse

**Kind:** contract

**Depends:** 0006:D38, 0028:D4

**Amends:** 0006:D38

**Decision:** Before it registers a finalizer on an instance whose owner says `operator`, the operator refuses to adopt it when the instance carries the local-provenance marker, or when it is the instance that deploys the operator itself (0028:D4). A refused instance shows a stalled status that names the reason and the remedy. The operator renders, applies, prunes and finalizes nothing for it, so deleting it never waits on the operator. What survives of 0006:D38: the marker only ever blocks, and the CLI's strict-registry digest gate stays the authority on render parity. What changes against 0006:D38: the operator reads the marker too, so a hand edit of the owner field meets a refusal it did not meet before.

**Requirements:**

- R1: The operator does not apply, prune or finalize an operator-owned instance that carries the local-provenance marker, and its status names the marker as the reason.
- R2: The operator does not apply, prune or finalize the instance that deploys the operator, whatever its owner field says, and its status names the reason.
- R3: A refused instance carries no operator finalizer, so its deletion completes without the operator.
- R4: Once the cause is removed, by a registry re-apply that clears the marker, the next reconcile adopts the instance through the ordinary path.

**Alternatives considered:**

- **CLI gates only, the delivered design (0006:D38).** A hand edit of the owner field bypasses every one of them, and the operator then applies registry bytes that may differ from what runs. Not chosen: the owner asked for a backstop.
- **A validating admission webhook on the owner field.** It refuses the edit itself, which is stronger. Not chosen here: it adds a certificate and an availability dependency the operator does not have, and operator issue 144 tracks webhooks as their own question.
- **The operator re-renders and compares its digest to the CLI's before adopting.** It would catch a stripped marker, which this backstop cannot. Not chosen yet: 0006:D40 bans cross-actor digest comparison under the digest as defined there, and that changes only once 0012:D6 drops the runtime name from the digest. OQ5 holds it.
- **Refuse adoption when no applier account is named.** It would also catch the old stranding on a hand flip. Not chosen: an instance created operator-owned by hand legitimately relies on the operator's default account, and the operator cannot tell a flip from a creation by the record alone.

**Rationale:** The CLI gates protect the command; the backstop protects the cluster. The two refusals are the cases where adoption does damage that a later reconcile cannot undo. Applying bytes nobody published replaces a running workload. Adopting the operator's own instance hands the operator the means to delete itself and then wait forever on its own finalizer. Refusing before the finalizer keeps a refused instance as deletable as a CLI-owned one. The marker stays user-editable, so the backstop is defence in depth, not a proof; the proof is D2's gate 11.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)": "the operator also refuses to adopt a source:local instance so kubectl edit cannot bypass it"); user decision 2026-10-04 ("Who owns the operator's own ModuleInstance after opm operator install?": "CLI-owned forever", with handoff refusing it). Operator reconcile order read from `opm-operator/internal/reconcile/moduleinstance.go` at release 1.0.0-beta.5.

---

### D6: Every render that is not a registry artifact is marked local

**Kind:** contract

**Depends:** 0006:D38

**Amends:** 0006:D38

**Decision:** The CLI marks an instance's record with the local-provenance marker whenever the rendered bytes are not wholly reproducible from a registry artifact at the recorded coordinate plus the recorded values. That covers a module applied from a directory, any local replacement in effect for the render, and any other input experiment 01 finds that puts local bytes into the render (OQ3). A render that is wholly registry-resolved carries no marker, and a registry re-apply removes one left by an earlier local apply. What survives of 0006:D38: the marker's key and value, that it only ever blocks, and that the strict-registry digest gate stays the authority. What changes: 0006:D38 named two triggers; this decision names the property, so the instance-file path stops marking only when a replacement file is present.

**Requirements:**

- R1: An instance whose rendered bytes include any content not reproducible from its recorded coordinate and values carries the local-provenance marker after the apply.
- R2: An apply whose render resolved wholly from registries leaves the instance without the marker, removing one an earlier apply wrote.
- R3: The marker is conservative: when the CLI cannot tell whether an input was local, it marks the render local.

**Alternatives considered:**

- **Keep 0006:D38's two named triggers (the delivered rule).** The instance-file path then marks a render local only when a replacement file exists, which the CLI's own comment on its result type already contradicts. Not chosen.
- **Drop the marker and rely on the digest gate alone.** 0006:D38 rejected this for the CLI: the refusal would arrive late, as a digest mismatch with no recorded reason. It is weaker still now, because the operator backstop (D5) has nothing else to read.
- **Mark a render local when it used a non-cluster Platform.** The digest gate re-renders against the cluster Platform anyway, and a Platform difference is not a module-bytes difference. Not chosen: the marker would refuse transfers the digest gate would pass.

**Rationale:** A marker that misses a local path is worse than none, because the operator backstop trusts its absence. Naming the property instead of the triggers makes every new render path answer one question. Over-marking costs one re-apply from the registry before a transfer; under-marking costs a refusal that arrives late or never.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)"). The instance-file trigger read from `cli/internal/workflow/render/` at cli release 1.0.0-beta.7. Pending evidence: `experiments/01-provenance-digest-reachability/` (OQ3).

---

### D7: Export reuses this gate set

**Kind:** scope

**Decision:** This entry owns the gate set for moving an instance's management away from the CLI. Entry 0014's export reuses the gates of D2 that apply to it, and depends on this entry instead of citing the removed command. Which gates export drops, such as operator readiness, stays 0014's to say. The edit to 0014 is a coordination change made in 0014 itself; this entry does not change 0014's decisions.

**Requirements:** none (a boundary between two entries; the observable behaviour is carried by D2 here and by 0014's own decisions).

**Alternatives considered:**

- **Fold export into this entry.** Export has its own questions about the exported tree, values and field managers, and none of them bear on the transfer. Not chosen.
- **Let 0014 keep its own copy of the gate list.** Two copies drift, which is how 0014 came to cite a command that no longer exists. Not chosen.

**Rationale:** One gate set means one place to add the next gate. Export applied to a CLI-owned instance is itself a transfer (0014's third question), so the two must not disagree on what a safe transfer requires.

**Source:** Design discussion 2026-10-04 (the supervisor's brief for this entry), following the owner's 2026-10-04 choice of two enhancement entries ("Planning vehicle before OpenSpec changes?": "Two enhancement entries (Recommended)"). 0014's stale citation read from `0014/03-decisions.md` (D2) and `0014/07-questions.md` (OQ3).

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
