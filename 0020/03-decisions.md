# Design Decisions: Contract Promotion and Retirement

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they
are made. **Numbers are permanent**: never reused, never renumbered, because
other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** How that stays true depends on the entry's `status`:

- While the entry is **`draft`**, decisions are living text: a changed choice is an **in-place edit** to the existing `DN`, and the log never contains two conflicting decisions. If the replaced position was backed by real evidence (an experiment outcome, an explicit user decision), fold it into *Alternatives considered* (marked as previously adopted) before overwriting; a mere sketch may be replaced outright. A decision retracted outright keeps its number as a one-line tombstone (`### DN: (retracted, YYYY-MM-DD)`).
- Once **`accepted`**, decision bodies are **protected**. A change lands as a *new* `DN` with `**Amends:**` / `**Supersedes:**` relation fields. Existing bodies are edited only through the `enhancement-compaction` skill, which weaves stacked reversals into the decisions they reverse (lower number survives, vacated number keeps a tombstone), at latest in the mandatory pass immediately before the `implemented` flip.
- **`implemented`** entries are frozen; **`superseded`** entries are stubbed via compaction.

Either way the log stays safe to read linearly: a reader who stops halfway should never come away believing something a later entry already killed.

Each decision carries a `**Kind:**` line plus the same four-field shape: Decision, Alternatives considered, Rationale, Source. The Source field is specific: `"User decision YYYY-MM-DD"`, a URL, or a file path, so the provenance of a choice never gets lost. A decision revised in place or by a merge keeps its original `Source:` and gains a `Revised: YYYY-MM-DD` line; *Alternatives considered* always survives revision and compaction, because it is what stops a rejected option being re-litigated later.

**The Kind gate.** A decision belongs in this log only if it passes the admission test: *if every affected repo were rewritten from scratch, would this decision still bind the result?* Three kinds pass it:

- `contract`: changes what a consumer can observe or rely on: a schema shape, a command's semantics, a compatibility or refusal rule, a naming guarantee.
- `policy`: a posture OPM commits to ("publish never invents a version").
- `scope`: a boundary decision: what this entry defers, what a successor owns, what a supersession keeps.

A *mechanism* decision (how a repo achieves the contract: algorithm choice, code placement, internal wiring) fails the test and belongs in the implementing slice's OpenSpec change in the target repo, decided when the code in front of the implementer is current. Measured evidence that *constrains* a contract (an experiment proving a primitive cannot express a rule) stays here, attached to the contract decision it constrains; the winning implementation design does not.

---

## Decisions

### D1: A contract reaches a higher level by promotion, and a promotion is declared

**Kind:** contract

**Decision:** A contract-bearing primitive may be published at a higher level than the one it was born at. The promoted member carries `metadata.promotedFrom`, an `#APIVersionType` naming the level it came from. The field is absent on a contract born at its level and present on one that arrived by promotion, and it stays on the member permanently rather than being consumed by the gate and dropped.

Promotion is a movement along enhancement 0010 D34's ladder in the direction the ladder implies: alpha to beta, beta to GA. It is not a break, and D27 is not what triggers it.

**Alternatives considered:**

- **Infer the promotion from the name.** A member at `container@v1` with no `promotedFrom` could be compared against any lower-level `container` the history carries. Rejected on two counts. It makes every new GA contract look like a promotion of something, so an author who deliberately starts a fresh contract at a level gets an unexpected comparison against an unrelated predecessor. It also leaves the published artifact with no statement of lineage, so a consumer reading the contract cannot tell where it came from.
- **Record the promotion only in the tombstone.** The retirement record already carries `replacedBy`, so the edge exists in one direction. Rejected because the two events are separated by an arbitrary number of builds: between the promotion and the retirement the artifact would carry two related contracts with nothing connecting them, which is the state a consumer is most likely to be reading.

**Rationale:** The ladder is a claim about maturity, and a claim that can only ever be made once, at birth, is not a claim a contract can earn. Declaring the origin is what turns promotion from an unverifiable rename into something the gate in D2 can check and a reader can follow.

**Source:** User decision 2026-08-22 ("declaring").

### D2: A promotion is refused unless it is compatible with the level it promotes from

**Kind:** contract

**Decision:** When a build publishes a member carrying `promotedFrom`, the compatibility gate resolves the newest published build carrying that member's `name` at the `promotedFrom` level and applies enhancement 0010 D27's additive-only comparison between them. An incompatible promotion is refused, naming both keys and the offending path.

This closes a hole rather than adding a rule. 0011 D9 keys its predecessor lookup on `name` plus `apiVersion`, so a member at a level never published before finds no predecessor and passes trivially: measured against the shipped gate, `container@v1` may today drop a required field relative to `container@v1beta1` and publish green.

The comparison is the existing one. `0011/experiments/03` measured that `cue.Value.Subsume` cannot express D27 in either direction (10/14 and 8/14 on disjoint failure sets, with changed defaults invisible to both) and that a three-rule field-wise walk expresses it at 14/14. That walk is the comparator; what this decision changes is which predecessor it is handed.

**Alternatives considered:**

- **Leave promotion ungated.** Rejected on the standing argument that 0010 D13 made against D4 and 0010 D17 repeated: a promise nothing checks is a convention. It is worse here than elsewhere, because a promotion is precisely the moment a catalog tells consumers the contract is *more* trustworthy.
- **Require a promotion to be byte-identical to its origin.** Simpler to check and wrong: a contract may legitimately accumulate additive changes at beta and then be promoted. Forbidding that would force an author to promote first and improve second, inverting the order the ladder implies.
- **Compare against every published build at the origin level rather than the newest.** Rejected as redundant under 0011 D23: the origin level's own history is already secured by the within-level gate, so the newest build at that level transitively represents it.

**Rationale:** A promotion that breaks its origin is not a promotion. It is a new contract wearing a familiar name, published at the moment consumers are being told to trust it more. The comparator already exists and the traversal already exists; this is a predecessor-selection change, which is why it is affordable.

**Source:** User decision 2026-08-22 ("Yes we should implement a promotion gate"). Comparator feasibility inherited from `enhancements/0011/experiments/03-d27-compat-gate/`.

### D3: A build may promote a contract or change its shape, never both

**Kind:** contract

**Decision:** A member carrying `promotedFrom` must be structurally identical to the predecessor D2 resolves. A build that moves a contract to a new level and changes its shape in the same release is refused, and the author is told to publish the additive change at the origin level first and promote in a later build.

**Alternatives considered:**

- **Allow an additive change to ride the promotion**, since D2's comparison would accept it anyway. Rejected on legibility: the refusal message for a *broken* promotion and the acceptance of a *changed* one would come from the same comparison, so an author who intended a pure promotion and accidentally changed a default would be told nothing. Splitting the two makes each release state one intent.
- **Forbid it only at GA.** Rejected as an arbitrary line: the argument is about a release stating one intent, and that applies equally at beta.

**Rationale:** Two independent movements in one release make the diff unreadable and the refusal message ambiguous. Separating them costs one extra build and makes every promotion trivially reviewable: the shapes match or they do not.

**Source:** User decision 2026-08-22 ("Yes agreed").

### D4: Levels coexist by aliasing, and dual-shipping is the sanctioned promotion mechanism

**Kind:** policy

**Decision:** A promoting catalog publishes both levels in the same build, with the outgoing level **defined as** the incoming one rather than restated. One value backs two keys; both land in the match index; every consumer of the old key keeps matching untouched and migrates when it chooses. The old key is withdrawn later under D6's retirement rules, never as part of the promotion.

Coexistence itself is not new. Enhancement 0010 D27 already permits a new `apiVersion` to "ship alongside the old one in the same catalog build", and D34 repeats it for level bumps. What this decision adds is that the compatible case uses the same permission, and that the two levels are one definition rather than two, so they cannot drift.

**Alternatives considered:**

- **A supersession edge the matcher follows on a lookup miss.** The promoted contract declares what it supersedes and the matcher falls back. Rejected for now, not on principle: enhancement 0010 D34 records that "the match path is exact-key, so no comparator ever decides what matches". While an authored edge is not the implicit ordering D34 rejected, following it makes a lookup miss ambiguous between "absent" and "present under another name". It stays available as a later accelerant if flag days prove too slow, and it costs nothing to defer because the tombstone's `replacedBy` already records the edge as data.
- **A flag day per contract**, the status quo. Rejected as the mechanism: 0015 OQ5 already calls this "a recurring cost rather than a one-off", and against 41 beta members it scales with adoption in the wrong direction.
- **Let a module demand a bare name and resolve the level at match time.** Rejected outright, and recorded because it is the intuitive answer. This is the version join enhancement 0010 D4 removed, reintroduced on the consumer side: what a module receives would depend on what the platform happens to carry, which is the ambiguity the identity reshape exists to eliminate.
- **Restate the outgoing level as its own definition** rather than aliasing it. Rejected: two independently authored definitions of one shape can drift, and D3's identity check would then be enforcing by comparison what aliasing gives structurally.

**Rationale:** This is the cheapest correct mechanism available, and its cost is almost entirely authoring. It needs no change to the matcher, no change to the key model, and no new concept: enhancement 0010 D49's `<kind>/<apiVersion>/` filing already gives two levels two directories, and D27 already blesses two levels in one build. Promotion becomes the compatible case of something the design already does.

**Source:** User decision 2026-08-22, confirming the mechanism as the intended reading of enhancement 0010 D27 and D34.

### D5: Skipping a rung is permitted and discouraged

**Kind:** policy

**Decision:** A contract may be promoted from alpha directly to GA. The gate does not refuse it, and D2's comparison applies against whatever level `promotedFrom` names. The guidance against it lives in `core/SPEC.md` and in the catalog authoring documentation, not in a check.

**Alternatives considered:**

- **Refuse rung-skipping.** Rejected: alpha promises nothing under 0010 D34, so there is no promise for the intermediate rung to protect. A refusal would be ceremony enforcing a preference.
- **Warn at publish.** Rejected on 0011 D9's own reasoning about warnings: a warning in a CI log is not a gate, and the artifact it warns about is immutable once pushed. Either it is a rule or it is guidance; making it guidance and putting it where authors read guidance is the honest form.

**Rationale:** The reason to walk the ladder is that beta exposure surfaces design problems while there is still a cheap way to fix them. That is an argument to an author, not a constraint on a build.

**Source:** User decision 2026-08-22 ("Avoid it but nothing should stop").

### D6: A published beta or GA member that stops shipping must be tombstoned

**Kind:** contract

**Decision:** A build is refused if it omits a member that a previous build published at beta or GA, unless the same build carries a tombstone for that key. Present, or tombstoned, or refused.

The tombstone is a published record carrying the `fqn` that went, the `since` build it went in, a required `reason`, and an optional `replacedBy`. Removal is never blocked: an author who wants a contract gone writes one record and publishes.

**Alternatives considered:**

- **Refuse removal outright while consumers exist.** Rejected because a publish gate cannot know who consumes a catalog. The knowledge lives in the cluster, which is where enhancement 0015 D3's finalizer and D16's shrink refusal already put the equivalent rule, and 0015 D16 fixes the constraint any such refusal must satisfy: it must land while the previous claim is still effective. A publish-side version would be arbitrary if it blocked always and useless if it blocked never.
- **Leave removal unrefused**, the status quo recorded in 0011 OQ10. Rejected on the evidence that question already gathered: the hermetic remove-then-readd test's removing build passes the full gate set on its way to seeding the case, so the gap is demonstrated rather than hypothetical. D23 closed the readd half; this closes the removal half.
- **Infer the tombstone at publish** from the predecessor diff, writing it automatically. Rejected: `reason` and `replacedBy` are judgements only the author can make, and a generated record would say a member is gone without saying anything a consumer can act on.

**Rationale:** The thing that hurts a consumer is not that a contract was removed; it is that it vanished without a trace, so the failure surfaces as a missing key at render with nothing naming when or why. A tombstone converts a silent removal into a deliberate one at a cost of one record, which is why it can be required without becoming a headache.

**Source:** Drafted 2026-08-22 from the contract-lifecycle analysis, answering 0011 OQ10. Open to revision while this entry is `draft`.

### D7: The tombstone record is cumulative and append-only across builds

**Kind:** contract

**Decision:** Every build carries the catalog's complete tombstone history, not the delta since the previous build. A build that drops a tombstone its predecessor carried is refused by the same walk that enforces D6.

**Alternatives considered:**

- **Carry only newly-removed keys per build.** Rejected on both readers. A consumer asking what happened to a key would have to walk every published build to find the answer, which puts registry I/O on a diagnostic path; and the gate would have to reconstruct the same history to know whether a key was ever tombstoned.
- **Allow pruning after some age.** Deferred rather than rejected; see OQ3. The record is small and its value is concentrated in the long tail, which is exactly the part pruning would remove.

**Rationale:** A consumer holding one build should be able to answer "where did this key go" from the bytes in front of it, with no network and no history walk. Cumulative is what makes that true, and making the map append-only is what stops the record being quietly laundered away by the next release.

**Source:** Drafted 2026-08-22 from the contract-lifecycle analysis. Open to revision while this entry is `draft`.

### D8: The tombstone map lives on `#Catalog`, beside the contract member maps

**Kind:** contract

**Decision:** `#Catalog` gains `#removed`, a map keyed by `#ContractFQNType` whose values are `#Tombstone`, stamping the key onto each value the way `#transformers` already stamps provenance onto its members. It sits beside enhancement 0015 D1's `#resources`, `#traits` and `#blueprints` as a fourth member map.

**Alternatives considered:**

- **On the contract itself, as a `deprecated` marker.** Not available: the contract is what is gone. A marker on a member that still ships describes a *deprecation*, which is a different and weaker statement than a removal, and it disappears with the member at the moment the record is needed.
- **In the catalog's identity package.** Rejected: identity states what the artifact *is* (enhancement 0010 D5), and a tombstone states what it no longer carries. Putting history in the identity package would also make it a dependency of every member that sources identity.
- **A separate published artifact per catalog.** Rejected: it introduces a second thing to version, pull and keep in step with the catalog build, for a record that is a property of that build.

**Rationale:** The tombstone is a statement by the catalog about its own membership, so it belongs where membership is declared. Keying it by FQN with the value re-declaring its own `fqn` reuses enhancement 0010 D49's discipline that filing and key cannot drift, and folding it beside 0015 D1's maps means one traversal reads the whole membership picture: what is here, and what used to be.

**Source:** Drafted 2026-08-22, answering the user's question of where the record lives. Open to revision while this entry is `draft`.

### D9: `replacedBy` is optional; `reason` is required

**Kind:** policy

**Decision:** A tombstone must state why the key went. It need not name a successor, because a contract removed as a mistake has none. A tombstone without `replacedBy` is legal and is not warned about.

**Alternatives considered:**

- **Require `replacedBy`.** Rejected: it would force an author retiring a genuine mistake to invent a successor or point at an unrelated contract, which makes the field's presence meaningless everywhere else.
- **Make `reason` optional too.** Rejected: `reason` is the entire consumer-facing value of the record in the case where there is no successor. A tombstone that says only "gone" is barely better than absence.

**Rationale:** The two fields answer different questions and only one of them always has an answer. Requiring the one that always does, and leaving the other free, keeps `replacedBy`'s presence informative: when it is there, it means something.

**Source:** Drafted 2026-08-22 from the contract-lifecycle analysis. Open to revision while this entry is `draft`.

### D10: A key may not be withdrawn until its replacement has been published for a minimum seasoning

**Kind:** policy

**Decision:** A tombstone naming a `replacedBy` is refused unless that replacement has been present in the published history for at least a minimum seasoning. The unit and the value are OQ1 and OQ2; the rule is that there is a floor and that the gate enforces it.

**This is a floor on the producer, not a deadline on the consumer.** Nothing expires a module, a pin, or a platform subscription. What is constrained is how fast a catalog may withdraw a key after offering its successor.

**Alternatives considered:**

- **A Kubernetes-style deprecation window.** Rejected, and enhancement 0010 D34 already rejected it with the reason that governs here: Kubernetes needs one because cluster upgrades force version moves on a support lifecycle. Under 0010 D14, a platform moves only when someone edits `version:` in its own source, so a window that expired a consumer's pin would be arbitrary. That reasoning is about forcing consumers to move, and this rule does not force anyone to move, which is why D34's rejection does not reach it and is not reopened by it.
- **A promotion deadline instead**: a contract must leave beta within some period. Rejected as the primary mechanism for the same reason D34 gave: it is a deadline pointing at an author with no consumer-side event to anchor it. Its failure mode is either a missed deadline nobody enforces or a forced promotion of a contract that is not ready. The seasoning floor reaches the same outcome from the other end, because a permanent beta is only harmful once someone wants to withdraw it.
- **No floor at all**, relying on D6's tombstone to make the withdrawal visible. Rejected: visibility is not the same as time. A build could promote and tombstone the origin in the same release, which is a flag day wearing a tombstone.

**Rationale:** This is the enforceable form of "a level must mean something". It does not require anyone to predict when a contract will be ready, and it binds exactly at the moment a withdrawal would hurt. It is also computable from data the gate already reads: 0011 D23's backward scan enumerates published versions, and "when did this key first appear" is that same walk run to its end.

**Source:** Drafted 2026-08-22, reframing the deprecation-clock question so that enhancement 0010 D34's rejection is preserved rather than reopened. Open to revision while this entry is `draft`.

### D11: Alpha members are never tombstoned, and transformers cannot be

**Kind:** scope

**Decision:** D6, D7 and D10 apply at beta and GA only. An alpha member may be removed from a build with no record and no refusal. `#ComponentTransformer` is outside the whole of this entry.

**Alternatives considered:**

- **Tombstone alpha members too**, for the diagnostic value. Rejected on enhancement 0010 D34's own argument for the alpha carve-out: requiring ceremony at a level whose definition is that it promises nothing empties the label. An alpha contract that vanishes is alpha behaving as documented.

**Rationale:** Both exclusions are inherited rather than chosen. The alpha carve-out is D34's, and applying it here keeps one rule about what alpha means rather than two. The transformer exclusion is structural: enhancement 0010 D44 removed `apiVersion` from `#ComponentTransformer`, so there is no contract level to move along and no key to tombstone. 0011 D9's own transformer carve-out records why applying contract rules to adapter bodies refuses ordinary catalog releases.

**Source:** Inherited from enhancement 0010 D34 (alpha) and D44 (transformers); recorded here because an implementer reading D6 would otherwise apply it to every member.

### D12: Blocking a withdrawal that would strand live instances is out of scope and belongs to the operator

**Kind:** scope

**Decision:** This entry stops at the published artifact. Refusing a provider change that would take a contract away from instances currently depending on it needs a live dependency graph, which no publish gate holds, and it lands in `opm-operator` beside enhancement 0015 D3's finalizer and D16's shrink refusal.

**Alternatives considered:**

- **Extend D6's refusal with a dependent check.** Not available at the publish surface: a catalog author publishes to a registry with no knowledge of any cluster, and inventing one would mean the gate consulting deployments it has no relationship with.

**Rationale:** The two halves of "do not abandon your dependents" live at different layers because only one layer has the knowledge. Enhancement 0015 D16 already states the cluster-side rule and the constraint it must satisfy; what it lacks is the dependent-side data, which is a separate investigation in the operator repo. Keeping the boundary explicit stops this entry from promising a protection it structurally cannot deliver.

**Source:** User decision 2026-08-22, directing the dependent-side investigation to the operator repo.

Open Questions live in [`07-questions.md`](07-questions.md): the entry's question register.
