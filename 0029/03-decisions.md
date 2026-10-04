# Design Decisions: Gated Ownership Transfer from CLI to Operator

This document records every design choice, with its reasoning and the alternatives that were ruled out.

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**: never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, a changed choice is an in-place edit to the existing `DN`, with an evidence-backed old position folded into *Alternatives considered*. Once `accepted`, bodies are protected and a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract`, `policy` or `scope`) and passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Mechanism decisions belong in the implementing OpenSpec change in the target repo.

Both experiments have concluded, and the decisions below rest on them. Experiment 01 ([`experiments/01-provenance-digest-reachability/`](experiments/01-provenance-digest-reachability/)) refuted the drafted reachability design, so D4 was rewritten in place. Experiment 02 ([`experiments/02-applier-identity-and-field-transfer/`](experiments/02-applier-identity-and-field-transfer/)) sharpened D2 and D3 and forced D8. One consequence of the D4 rewrite conflicts with the owner's choice of a CLI-side reachability gate; OQ8 states it and blocks acceptance.

---

## Decisions

### D1: A forward-only transfer command returns

**Kind:** contract

**Depends:** 0006:D16

**Amends:** 0006:D7

**Decision:** `opm instance handoff` returns as the one supported way to move a CLI-owned instance to operator ownership. It moves ownership forward only: operator to CLI stays out of scope, as 0006:D16 decided, and that decision stands unchanged. What survives of 0006:D7: a CLI command verifies before it flips, flips once, and waits for the operator's first reconcile. What changes against 0006:D7: the gate set is re-specified by D2, D3 and D4, because the command 0006:D7 described was removed for checking too little, and the reverse mode it named is gone for good.

**Requirements:**

- R1: The CLI offers a command that moves a CLI-owned instance to operator ownership, and offers none that moves an operator-owned instance back.
- R2: A refused transfer leaves the instance's record exactly as it found it: owner, spec, annotations and status unchanged.
- R3: A transfer that fails after the owner changed is reported as a failure that left the instance operator-owned, with where to look next; the CLI never reverts the owner. This includes the operator refusing the adoption (D4, D5).

**Alternatives considered:**

- **Export only (0014) as the path off the CLI.** A user who wants the operator, not Git, would have to commit a tree to get there, and committing an exported tree for a CLI-owned instance is itself an unverified transfer (0014's third question). Not chosen: the owner chose to revive the command.
- **Write the owner on apply (an owner choice on `opm instance apply`).** The removal change ruled this out explicitly, and an apply that also changes ownership merges two operations whose failures need different remedies.
- **Restore reverse transfer.** 0006:D16's reasons hold: operator-written control-loop status left on a record that flips back, and a relinquish race. The dogfood case that might want undo, the operator's own instance, never transfers (D2 R4). Experiment 02 measured what a reverse takes today: a hand server-side apply of the owner as the CLI's field manager works at once, but an operator finalizer added before the reverse stays, and the CR then hangs in deletion (OQ10).

**Rationale:** The ownership model the command rested on stayed in place when the command was removed: the owner field, the operator's hands-off rule, the recorded digest, the thin editor. What was missing was a gate, not a model. Reviving the command on the same model keeps one user-visible step between "the CLI applied it" and "the operator reconciles it", which is the story 0006 was written for.

Experiment 02 reproduced the removal reason on a stock install. With no applier named, the operator added its finalizer, failed the first apply as its own controller identity, and retried forever on backoff while every object stayed byte-identical. `opm instance apply` could not take the instance back: it saw an operator-owned record and only edited its spec.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)"). Removal reason quoted from cli PR 196 and its archived change `cli/openspec/changes/archive/2026-08-31-remove-instance-handoff/proposal.md`. Strand and recovery measured in `experiments/02-applier-identity-and-field-transfer/` (case 1).

---

### D2: The transfer's gate set, and what success means

**Kind:** contract

**Depends:** 0006:D11, 0006:D38, 0006:D40, 0028:D4

**Amends:** 0006:D7, 0006:D40

**Decision:** Before writing anything, the transfer requires every one of these to hold, checked cheapest first:

1. The cluster gates every mutating CLI path runs: the instance CRD present, its field floor met, the operator's version within the CLI's ceiling.
2. The operator is installed and ready.
3. The instance's record exists and is CLI-owned.
4. The instance is not the one that deploys the operator itself (0028:D4).
5. The record carries no local-provenance marker (D6).
6. The record names a complete published coordinate: module path and version.
7. The render skipped no contract.
8. The record carries the render digest of what the CLI applied.
9. The applier identity the user names can apply, and if asked to prune can delete, every entry the instance renders (D3).
10. The running operator performs the adoption check of D4.
11. A strict re-render reproduces the recorded digest. It resolves from registries only, ignores any local replacement, uses a module cache no earlier fetch could have filled, renders against the cluster Platform (0006:D11), and replays the recorded values.
12. The record is unchanged since it was read for gate 3, apart from its status.

A force option skips gate 11's comparison and nothing else. Then one write, conditional on the record being the one the gates read, sets the owner to `operator`, restates the verified module and values, records the applier identity and prune intent, and states the digest the operator must reproduce (D4). Success is 0006:D40's inventory-stable reconcile, plus one check 0006:D40 banned: the digest the operator recorded for its first apply equals the digest the transfer stated. After success the CLI gives up its field ownership (D8).

What survives of 0006:D7: operator ready, CLI-owned, a published and resolvable coordinate, a digest re-render, force limited to the digest, and a bounded wait. What changes against 0006:D7: gates 4, 7, 9 and 10 are new; gate 12 becomes a condition on the write itself rather than a re-read before it; the write records the applier identity and the expected digest, which 0006:D7's single-field flip never did. What survives of 0006:D40: the inventory-stable verdict and the reported relabel. What changes against 0006:D40: the verdict also compares the operator's recorded render digest to the stated one, which its first corollary forbade.

**Requirements:**

- R1: The transfer writes nothing to the cluster until every gate holds; any refusal names the gate and the remedy.
- R2: A refusal that needs no registry access is reported before any registry access is made.
- R3: A forced transfer skips only the digest comparison; a missing coordinate, a module the verification render cannot resolve, a missing applier right, a local render, a skipped contract, an operator without the adoption check or the operator's own instance is never overridden.
- R4: The instance that deploys the operator is never transferred.
- R5: (retired, 2026-10-04) The verification render resolved through the operator's reported registry mapping; experiment 01 showed the CLI cannot use that mapping (D4). The surviving half is R11.
- R6: The verification render uses the cluster Platform; when it cannot be read, the transfer refuses rather than falling back to another platform source.
- R7: A digest mismatch is reported with both digests and, where the CLI can tell, which input moved: the module bytes, the Platform, or the values.
- R8: When the record's spec, owner or annotations changed between verification and the write, the write fails and the owner stays unchanged; the transfer never writes a spec it did not verify.
- R9: After a successful write, the instance's module and values equal the verified ones, and its owner, applier identity and prune intent are the ones the transfer wrote.
- R10: The transfer reports success only when the operator has reconciled the written generation as ready, with the same inventory entry set, an incremented revision and nothing pruned; the managed-by relabel is reported, not counted as a change.
- R11: The verification render cannot be satisfied by a module cached before the transfer started, and resolves no local replacement.
- R12: The transfer reports success only when the render digest the operator recorded for its first apply equals the digest the transfer stated.
- R13: A change to the record's status alone between verification and the write does not refuse the transfer.

**Alternatives considered:**

- **The old chain unchanged (the delivered rule, 0006:D7 with 0006:D38 and 0006:D40).** It stranded every instance on a stock install, because nothing checked who applies. Not chosen: it is the removed command.
- **Verify reachability through the operator's reported registry mapping (previously adopted in this draft).** Refuted by experiment 01: the mapping names hosts only the cluster network resolves, and a mapping that resolves the same coordinate to different bytes passes every CLI gate. D4 moves the proof into the operator.
- **Verify reachability through the CLI's own mapping, as the old chain did.** It proves the CLI can fetch, which is not the question. Experiment 01 flipped two instances that passed every CLI gate this way: one stranded on `module not found`, the other silently swapped bytes and reported Ready. Not chosen as the reachability proof; the CLI's own fetch remains only what gate 11 needs.
- **Success as 0006:D40 alone (entry set, revision, nothing pruned).** Experiment 01 scored two broken adoptions as success under it: a hybrid object keeping fields only the CLI owned, and a silent swap of bytes. Not chosen; R12 adds the digest check.
- **Re-read the generation before the write (the old implementation's guard).** Experiment 02 case 4 showed the window between the re-read and the write: a stale flip silently reverted a concurrent apply, and the verdict still passed. A write conditioned on the record version the gates read refused the stale write. Not chosen alone; R8 makes the write itself conditional.
- **Compare the two actors' inventory fingerprints in the verdict.** Experiment 02 case 3 measured different fingerprints for an identical entry set, because the two actors serialise empty fields differently. Not chosen: the verdict compares entry sets.
- **Let force skip the operator-side check too.** A forced transfer of a module the operator cannot fetch fails on the first reconcile with no way back (D1 R3). Not chosen.
- **An operator-side admission webhook as the only gate.** A webhook outage would block every write to every instance. Not chosen as the primary gate; D4 and D5 keep reconcile-time checks instead.

**Rationale:** Each new gate answers a way the old command, or a hand flip, strands an instance. Gate 9 is the removal reason. Gate 10 refuses an operator that would adopt without proving it reproduces the render. Gate 7 refuses a render the operator can never reproduce, because the operator never skips a contract. Gate 4 keeps the operator from adopting the instance that can delete it. Ordering cheap reads before the registry render keeps the common refusals fast and offline, which the old chain already did.

Gate 11's isolated cache is measured, not assumed. Experiment 01 republished a tag with other bytes: a fresh cache refused, a warm cache passed wrongly. A cold verification of a one-object module took about 3 seconds, almost all of it fetching core and the catalog. Gate 11 is still a self-comparison through the CLI's own registries; the cross-actor proof is D4's.

R13 exists because the record's version also moves on status writes, such as the operator's own acknowledgement of a CLI-owned record (experiment 02 case 4). A guard that refused those would refuse transfers for no reason.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)": revive the old gate chain plus applier-identity and registry-reachability gates). Old chain read from cli commit `093b9761` and the archived change `cli/openspec/changes/archive/2026-07-20-cli-instance-handoff/`. Experiment outcomes: `experiments/01-provenance-digest-reachability/` (gate verdicts per case, cold verification time); `experiments/02-applier-identity-and-field-transfer/` (cases 3 and 4).

---

### D3: Applier identity is completed at transfer, never guessed

**Kind:** contract

**Depends:** 0006:D17

**Amends:** 0006:D7

**Decision:** The user names, at transfer, the service account the operator will apply the instance as and whether the operator prunes it. The transfer refuses when either is unstated. It never falls back to the operator's default account or the controller's own identity. Before writing, the transfer asks the cluster's authorizer whether that account, as the operator will impersonate it, may do what the operator will do with every entry the instance renders: read, create and patch it, and delete it when pruning is asked for. For an entry that is a role or a role binding, it also asks what Kubernetes escalation prevention will ask: whether the account holds every right the role grants, or may escalate that role, or may bind the role a binding references. It also asks whether the operator's own identity may act as that account. A refusal reports every denied entry and right, not the first. The write records the named account and the prune intent on the instance, so the identity the operator uses is the one the gate checked. What changes against 0006:D7: its flip wrote only the owner, leaving the applier to whatever the operator defaulted to, which is the defect that removed the command.

**Requirements:**

- R1: A transfer without a named applier account, or without a stated prune intent, refuses before any write.
- R2: The transfer refuses when the named account does not exist in the instance's namespace.
- R3: The transfer refuses when the authorizer denies the named account any right the operator needs on any entry the instance renders, naming every such entry and right; delete rights are checked only when pruning is asked for.
- R4: The transfer refuses when the operator's own identity may not act as the named account.
- R5: After the transfer, the instance records the named account and the stated prune intent, and the operator applies it as that account.
- R6: When the person running the transfer lacks the right to ask the authorizer about another identity, the transfer refuses and names that right; it never treats an unanswered review as a pass.
- R7: The transfer refuses when an entry is a role the named account could not create without escalation, or a binding it could not create without the bind right, naming the rights it lacks.
- R8: The access review answers for the account with the group memberships the operator's impersonation presents.

**Alternatives considered:**

- **Infer the operator's default account.** The default is an operator flag, empty by default, and it can change after the transfer without the instance noticing. The CLI also cannot read it today. Not chosen: the instance would apply as whatever the operator is configured with on the day of each reconcile.
- **Review only the apply verbs.** Experiment 02 case 2b gave an account every verb on cluster roles and their bindings but not the node read the rendered role grants. The verb-only review passed every entry; the operator's apply was refused as an escalation. Not chosen: it gives a false pass for any module that renders RBAC, and the operator module does.
- **Report the operator's own failure instead of a full review.** The operator's condition names only the first refused object, and its staged apply aborts before reaching later entries (experiment 02 case 2). Not chosen: the user would fix one right per round trip.
- **Create the account and its RBAC as part of the transfer.** Granting rights needs rights the user may not have, and a tool that writes RBAC decides a security posture for the user (0014's second question faces the same choice). Not chosen for this decision; a helper is OQ6.
- **Check two representative kinds, as the old end-to-end precondition did.** It proves nothing about the kinds it skipped. Not chosen: the gate checks every entry.
- **Default the prune intent to on, or to off.** Either default silently decides whether a later delete removes workloads. Not chosen: the CLI never wrote the field, so the transfer is the first moment anyone states it.

**Rationale:** The removed command stranded instances because the operator applied as an identity nobody chose. Making the user name one, and proving it against the exact entries the operator will apply, turns the stranding into a refusal before anything changes. Recording the identity on the instance keeps the proof valid after the transfer: the operator uses what was checked, not what its flags say later. The transfer is an operator-adoption step and already needs the cluster Platform, so needing the right to review another identity's access fits the administrator context 0006:D17 allows for it.

Experiment 02 measured the prediction against the operator's real apply in five cases. Once escalation was modelled, every outcome matched: two predicted failures stranded or stalled, three predicted passes adopted. The entries reviewed are the verification render's, which gate 11 proves equal to the recorded inventory; reviewing the inventory alone would miss an entry the render adds.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)", naming the applier-identity gate). Removal reason quoted from cli PR 196. The operator's impersonation precedence (instance account, then default flag, then its own client) read from `opm-operator/internal/apply/` on 2026-10-04. Experiment outcome: `experiments/02-applier-identity-and-field-transfer/` (cases 1, 2, 2b and 3; prototype gate `predict.sh`).

---

### D4: The operator adopts only a render it proves equal to the verified one

**Kind:** contract

**Depends:** 0006:D40

**Amends:** 0006:D40

**Revised:** 2026-10-04 — experiment 01 refuted the drafted registry-mapping report; the proof of reachability moved into the operator's adoption.

**Decision:** Before it registers a finalizer on an instance it has never applied, the operator renders the instance through its own registries and compares the render's digest to the digest the adoption expects. The transfer's write states that digest: the digest of the CLI's verification render (D2, gate 11), as the operator's render of the same bytes would digest it. A record whose owner was changed by hand states none; for it the operator expects the render digest the CLI recorded for what it applied. The comparison ignores only which runtime stamped the render. The operator refuses the adoption when the module does not resolve, when the digests differ, or when a record another actor applied carries neither digest. A refusal is a stalled status naming the reason, with no finalizer and nothing applied or pruned, as D5's refusals are. This check is the transfer's reachability gate: the proof runs where the fetch runs.

What survives of 0006:D40: success is the inventory-stable reconcile, and the managed-by relabel is reported, not counted. What changes against 0006:D40: its first corollary banned every cross-actor digest comparison; this decision makes one, at adoption, because experiment 01 showed it is exact.

**Requirements:**

- R1: (retired, 2026-10-04) The Platform's status reported the operator's module registry mapping.
- R2: (retired, 2026-10-04) The mapping report carried no credential.
- R3: (retired, 2026-10-04) A transfer against an operator without the report refused.
- R4: (retired, 2026-10-04) The verification fetch presented the operator's credentials.
- R5: The operator applies, prunes and finalizes nothing for an instance it has never applied until its own render of that instance reproduces the expected digest.
- R6: When the operator cannot resolve the module, or its render differs from the expected one, the instance stays unadopted with a stalled status naming the reason, and its workloads are unchanged.
- R7: The transfer states the expected digest in the same write that changes the owner; a forced transfer states the digest of the render the user accepted.
- R8: An instance whose owner was changed by hand is adopted only if the operator's render reproduces the digest the CLI recorded for what it applied.
- R9: A transfer against an operator that does not perform this check refuses, naming the operator release that adds it.

**Alternatives considered:**

- **The operator reports its registry mapping on the cluster Platform's status, and the CLI fetches through it (previously adopted in this draft).** Refuted by experiment 01. The mapping names hosts only the cluster network resolves, so the CLI cannot fetch through it from where it runs. A mapping also is not bytes: the case where both sides resolve the same coordinate to different bytes passes every CLI gate. Today the mapping is visible only in the operator Deployment's arguments and a startup log line; publishing it for diagnostics stays possible and is not part of this decision.
- **An operator-side resolve the CLI requests before the flip.** It proves reachability before any write, which this decision cannot. Not chosen yet: it needs a request path on a record the operator otherwise ignores (0006:D3), and the adoption check is still needed afterwards, because the operator's cache or the tag can change between the probe and the adoption. OQ8 holds it as an option.
- **Compare digests only at the CLI (0006:D40's first corollary, the delivered rule).** It leaves the operator's own fetch unchecked. Experiment 01 flipped a republished tag while the operator's cache was warm, and the operator applied the old bytes. Not chosen.
- **Wait for 0012:D6's runtime-neutral digest before comparing across actors (this draft's OQ5).** Not needed: experiment 01 reproduced the operator's recorded digest byte for byte for three instances by rendering with the operator's runtime name. 0012:D6 makes the comparison simpler when it lands; it does not change this decision.
- **Rely on the local-provenance marker as the operator's only check.** The marker misses renders experiment 01 found (D5, D6). Not chosen.

**Rationale:** Reachability and byte identity are properties of the operator's fetch, so only the operator's fetch proves them. Experiment 01 showed three ways a CLI-side proof fails: a version only the CLI's registry has (stranded on `module not found`), a coordinate two registries serve differently (silent swap, reported Ready), and the operator's own stale cache (old bytes applied). This check refuses all three, and every hand flip of a local render, from one comparison. Checking before the finalizer keeps a refused adoption as easy to undo as a CLI-owned record; experiment 02 showed what a finalizer on an unmanaged record costs.

The price is that a reachability failure is now found after the owner field changed, not before. The instance is then operator-owned, unadopted and untouched. OQ8 states this against the owner's choice of a CLI-side reachability gate.

**Source:** Experiment outcome `experiments/01-provenance-digest-reachability/` (cases ii and iii, "What the operator did after a flip", "The CLI can predict the operator's digest"). User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)", naming the registry-reachability gate and the operator backstop). The operator's registry precedence read from `opm-operator/cmd/main.go` at release 1.0.0-beta.5.

---

### D5: The operator refuses to adopt what the transfer would refuse

**Kind:** contract

**Depends:** 0006:D38, 0028:D4

**Amends:** 0006:D38

**Decision:** Before it registers a finalizer on an instance whose owner says `operator`, the operator refuses to adopt it when the instance carries the local-provenance marker, or when it is the instance that deploys the operator itself (0028:D4). The self check also runs on what the instance renders, before any apply, so an instance created operator-owned, which has no recorded inventory, is refused too. A refused instance shows a stalled status that names the reason and the remedy. The operator renders nothing for a marked instance and applies, prunes and finalizes nothing for either, so deleting it never waits on the operator. The operator never prunes the objects of the instance that deploys it, even when that instance is deleted while carrying an operator finalizer. What survives of 0006:D38: the marker only ever blocks, and the CLI's strict-registry digest gate stays the authority on render parity. What changes against 0006:D38: the operator reads the marker too, so a hand edit of the owner field meets a refusal it did not meet before. The marker refusal is the early, explained refusal; D4's digest check is the proof.

**Requirements:**

- R1: The operator does not apply, prune or finalize an operator-owned instance that carries the local-provenance marker, and its status names the marker as the reason.
- R2: The operator does not apply, prune or finalize the instance that deploys the operator, whatever its owner field says, and its status names the reason.
- R3: A refused instance carries no operator finalizer, so its deletion completes without the operator.
- R4: Once the cause is removed, by a registry re-apply that clears the marker, the next reconcile adopts the instance through the ordinary path.
- R5: The self refusal of R2 holds for an instance that records no inventory, judged by what the instance renders.
- R6: Deleting the instance that deploys the operator never makes the operator delete its own objects, even when an operator finalizer is present.

**Alternatives considered:**

- **CLI gates only, the delivered design (0006:D38).** A hand edit of the owner field bypasses every one of them. Experiment 01 confirmed the operator then adopts: two marked instances flipped by hand reached Ready, one keeping the marker and one with it stripped by the flip itself. Not chosen: the owner asked for a backstop.
- **The marker as the whole backstop.** The old flip's own server-side apply drops the marker, and a module copied into the instance's own package is rendered with none (experiment 01, cases i and iv). Not chosen: D4's digest check carries the proof, and the marker gives the early, named refusal.
- **A validating admission webhook on the owner field.** It refuses the edit itself, which is stronger. Not chosen here: it adds a certificate and an availability dependency the operator does not have, and operator issue 144 tracks webhooks as their own question.
- **Refuse adoption when no applier account is named.** It would also catch the old stranding on a hand flip. Not chosen: an instance created operator-owned by hand legitimately relies on the operator's default account, and the operator cannot tell a flip from a creation by the record alone.

**Rationale:** The CLI gates protect the command; the backstop protects the cluster. The two refusals are the cases where adoption does damage that a later reconcile cannot undo. Applying bytes nobody published replaces a running workload. Adopting the operator's own instance hands the operator the means to delete itself and then wait forever on its own finalizer. Refusing before the finalizer keeps a refused instance as deletable as a CLI-owned one: experiment 02 case 1 showed a finalizer left on a record the operator no longer manages wedges its deletion. The self check must also judge the render because the recorded inventory is written by the CLI, and an instance created operator-owned has none.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)": "the operator also refuses to adopt a source:local instance so kubectl edit cannot bypass it"); user decision 2026-10-04 ("Who owns the operator's own ModuleInstance after opm operator install?": "CLI-owned forever", with handoff refusing it). Operator reconcile order read from `opm-operator/internal/reconcile/moduleinstance.go` at release 1.0.0-beta.5. Experiment outcomes: `experiments/01-provenance-digest-reachability/` (what the operator did after a flip); `experiments/02-applier-identity-and-field-transfer/` (case 1 recovery, case 5 sketch).

---

### D6: Every render that is not a registry artifact is marked local

**Kind:** contract

**Depends:** 0006:D38

**Amends:** 0006:D38

**Decision:** The CLI marks an instance's record with the local-provenance marker whenever the rendered bytes are not wholly reproducible from a registry artifact at the recorded coordinate plus the recorded values. That covers a module applied from a directory, any local replacement in effect for the render, and a module package resolved from inside the instance's own module rather than from a registry dependency. A render that is wholly registry-resolved carries no marker, and a registry re-apply removes one left by an earlier local apply. What survives of 0006:D38: the marker's key and value, that it only ever blocks, and that the strict-registry digest gate stays the authority. What changes: 0006:D38 named two triggers; this decision names the property, so the instance-file path stops marking only when a replacement file is present.

The marker does not cover inputs that are registry bytes from the wrong place or the wrong time: a registry mapping only the CLI uses, a tag republished with other bytes, or a stale module cache. Those are not local renders; gate 11 (D2) and the operator's adoption check (D4) refuse them.

**Requirements:**

- R1: An instance whose rendered bytes include any content not reproducible from its recorded coordinate and values carries the local-provenance marker after the apply.
- R2: An apply whose render resolved wholly from registries leaves the instance without the marker, removing one an earlier apply wrote.
- R3: The marker is conservative: when the CLI cannot tell whether an input was local, it marks the render local.
- R4: A module the CLI resolved from anything other than a registry dependency marks the render local, including a module package that lives inside the instance's own module and claims a published coordinate.

**Alternatives considered:**

- **Keep 0006:D38's two named triggers (the delivered rule).** Experiment 01 case iv copied the module into the instance's own package, kept the published coordinate in its metadata, and applied it: no marker, and the record named the published coordinate. Only the digest gate refused it, and a hand flip made the operator swap in the registry bytes. Not chosen.
- **Drop the marker and rely on the digest checks alone.** 0006:D38 rejected this for the CLI: the refusal would arrive late, as a digest mismatch with no recorded reason. Not chosen: the marker is what lets both the CLI and the operator say why.
- **Mark a render local when it used a non-cluster Platform, a CLI-only registry mapping, or a warm cache.** None of these puts non-registry bytes into the render, and the digest checks refuse each of them where it matters. Not chosen: the marker would refuse transfers the digest gates pass.

**Rationale:** A marker that misses a local path misleads, because a reader takes its absence as a registry render. Naming the property instead of the triggers makes every new render path answer one question. Over-marking costs one re-apply from the registry before a transfer; under-marking costs a refusal that arrives late with no reason. The marker is no longer the operator's only check (D4), so its job is the early, explained refusal, not the proof.

**Source:** User decision 2026-10-04 (AskUserQuestion, "Shape of the redesigned handoff?": "CLI gates + operator backstop (Recommended)"). The instance-file trigger read from `cli/internal/workflow/render/` at cli release 1.0.0-beta.7. Experiment outcome: `experiments/01-provenance-digest-reachability/` (gate verdicts per case, case iv).

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

---

### D8: The CLI gives up its field ownership when the transfer succeeds

**Kind:** contract

**Depends:** 0006:D40

**Decision:** After the operator's first reconcile passes the transfer's verdict (D2), the transfer releases every field the CLI's field manager owns on every object in the instance's inventory, deleting nothing. It never releases before that verdict, and a transfer that fails leaves the CLI's ownership in place. From then on the operator is the only manager of those fields, so a field a later module version stops setting is removed by the operator's next apply.

**Requirements:**

- R1: After a successful transfer, the CLI's field manager owns no field of any object in the instance's inventory.
- R2: After a successful transfer, a field the operator's render stops setting is removed from the live object by the operator's next apply.
- R3: The release deletes no field and no object, and runs only after the operator's verdict passed.

**Alternatives considered:**

- **Keep 0006:D40's verdict and document the residue (this draft's OQ4, option a).** Experiment 02 case 3c showed the residue is not cosmetic. After the flip, the CLI co-owned every field of all six objects. A later values change dropped a field from the operator's render; the field stayed, and the operator reported Ready with nothing updated. Not chosen.
- **Report CLI-owned fields in the verdict without releasing them (option c).** It names the trap but leaves it armed for the next module upgrade. Not chosen.
- **Release in the transfer's own write, before the operator applies (option b as first drafted).** Before the operator's first apply, the CLI is the only owner of every field, so releasing then deletes them. Not chosen: R3.
- **The operator migrates field ownership on its first apply.** It would also cover a transfer that ended before its verdict (OQ11). Not chosen as the primary path: the CLI is the manager that must let go, and the release needs no new operator behaviour.

**Rationale:** A transfer that leaves the CLI as co-owner of every field has transferred the record, not the objects. Experiment 02 demonstrated the remedy: one identity-only apply as the CLI's field manager, after the first operator reconcile, left the operator as sole manager, and its next apply removed the dropped field.

**Source:** Experiment outcome `experiments/02-applier-identity-and-field-transfer/` (case 3c, field ownership after transfer). Experiment `experiments/01-provenance-digest-reachability/` observed the same co-ownership on a local render (case i, hello-ma).

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
