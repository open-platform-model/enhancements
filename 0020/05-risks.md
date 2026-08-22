# Risks, Drawbacks, Alternatives — Contract Promotion and Retirement

## Risks and Mitigations

**The seasoning floor is unsatisfiable, or trivially satisfiable, against the fleet as it exists.** Measured 2026-08-22, `catalog_opm` publishes only `1.0.0-alpha.*` builds. A release-counted floor could be cleared in an afternoon by publishing throwaway patches; a time-counted floor cannot be cleared at all by a catalog that has not existed long enough. Either way the rule ships as theatre. *Mitigation:* OQ1 and OQ2 are contract-level gates on `accepted`, and `04-graduation.md` requires the value to be defensible against the actual fleet rather than against a hypothetical one.

**The raw `k8s-*` family cannot obey the promotion rule.** Enhancement 0010 D48 fixes those contracts' `apiVersion` to the upstream Kubernetes API version. A promotion rule that assumes the author owns the level is wrong for roughly a third of the catalog's surface. *Mitigation:* OQ4 is a contract-level gate on `accepted`. The likely answer is exemption from D1 and D2 with D6 still applying, because upstream does remove API versions and consumers still need to hear about it.

**A new metadata field reaches the match comparison and changes matching.** `promotedFrom` sits on primitive metadata, and enhancement 0010 D30 filters provenance out of the match comparison via a fixed denylist before unification. A field that is not on the denylist participates, so two builds that disagree about `promotedFrom` would conflict at unification. *Mitigation:* OQ6's concrete half is a gate on `accepted`. This is the same class of defect enhancement 0010 D26 and D30 exist to prevent, so the precedent and the mechanism both exist.

**Dual-shipping doubles the surface the compatibility gate walks.** Every promoted contract lives at two keys until its origin is retired, and with 41 beta members a broad promotion campaign could double the gated member count for an extended period. *Mitigation:* D4's aliasing means the two keys share one definition, so the comparison at the outgoing key is against a value that is structurally identical by construction. The cost is one extra map entry and one extra lookup per promoted contract, not a second independent shape to maintain.

**The tombstone record becomes noise.** A catalog that churns contracts accumulates a `#removed` map larger than its live membership, and readers stop reading it. *Mitigation:* D11 keeps alpha out, which is where churn actually happens. OQ3 holds the pruning question open rather than assuming never is right.

**The rules are enforced only where the tool is used.** Enhancement 0010 D11 records that `cue mod publish` keeps working, and 0010 D35 accepts the resulting exposure in writing. Every rule here inherits it: a bypassed build can remove without a tombstone and promote without a comparison. *Mitigation:* none available at this layer, and none claimed; OQ7 requires the degradation behaviour to be stated rather than discovered. This entry does not represent its gates as guarantees, following D35's precedent exactly.

## Drawbacks

**It adds a fourth member map and three metadata surfaces to a schema that is a published contract.** Everything is additive, so no consumer breaks, but `#Catalog` grows and every catalog author has one more thing to understand.

**Promotion now costs two builds instead of one.** D3 forbids promoting and changing shape in the same release, so an author who wants both must publish twice. That is the intended trade, and it is a real cost for a solo catalog maintainer.

**The clock binds the well-behaved author and not the careless one.** D10 constrains the author who publishes a replacement and then wants to withdraw the original. An author who never promotes anything is untouched by it. The entry's answer to permanent beta is therefore indirect: it prices withdrawal rather than forcing promotion, which is what makes it compatible with enhancement 0010 D34, and it means a catalog that simply never moves is still not moved by this design.

**It depends on an accepted-but-undelivered entry.** Enhancement 0015 D1 is a hard prerequisite for the parts that iterate contracts. Until it lands, this entry can ship its gates but not a lifecycle report.

## Alternatives

**Do nothing.** The 41 beta members stay, the level stops carrying information, and the promotion cost grows with the fleet. This is the current trajectory and it is not stable: the flag day gets more expensive every month it is deferred.

**A promotion deadline instead of a retirement floor.** Require a contract to leave beta within some window. Rejected as the primary mechanism in D10: it is a deadline pointing at an author with no consumer-side event to anchor it, so it either goes unenforced or forces a contract to GA before it is ready. Enhancement 0010 D34's "any window would be arbitrary" applies to it in a way it does not apply to a floor on withdrawal.

**A matcher-following supersession edge.** Let the match path fall back from a retired key to its successor. Held in reserve by D4 rather than rejected: it would make promotion nearly free for consumers, at the cost of making a lookup miss ambiguous and putting a second lookup on a path enhancement 0010 D34 celebrates as exact-key. The tombstone's `replacedBy` records the edge as data either way, so adopting it later is additive.

**Consumer-side level resolution.** A module demands a bare name; the platform supplies whatever level it has. Rejected outright in D4: this is enhancement 0010 D4's version join reintroduced on the consumer side, and it makes what a module receives depend on what the platform happens to carry.

**Publisher discipline with documentation only.** No gates, just a written policy. Rejected on the standing argument from enhancement 0010 D13 and D17: a promise nothing checks is a convention, and a third-party catalog author has no reason to copy a convention nothing checks.
