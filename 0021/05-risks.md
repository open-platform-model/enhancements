# Risks, Drawbacks, Alternatives: OPM Versioning Policy

Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **Authors route around the major.** Once a `#config` break costs a major, and a major is an import rewrite plus a new module path (U5), the pressure is to disguise the break: keep the old field, add the new one, and quietly stop reading the old one. The instance still unifies and the module silently ignores its input. **Mitigation:** this is the case the gate cannot see and the policy must name: a field that is accepted and ignored is a break in behaviour, and the policy states it as breaking regardless of what unification says. Beyond that, keeping the major cheap is the real mitigation, and 0010 D41 already did the expensive part by making instance identity survive it.
- **The `#config` rule reads as the whole rule.** An author who learns "breaking `#config` means major" ships a volume rename as a patch with a clear conscience. **Mitigation:** OQ1 is blocking for exactly this reason; whichever way it resolves, the policy's module section leads with both surfaces and says which changes fall on each.
- **Subsumption disagrees with intent.** CUE subsumption is precise and occasionally surprising: a default added to a previously required field changes the accepted set in a direction an author reads as a fix. A gate that refuses on subsumption alone will refuse changes the author considers compatible, and the refusal message decides whether the author trusts the tool or bypasses it. **Mitigation:** the design table in `02-design.md` is written in the author's vocabulary and is what the published policy shows; the gate's refusal names the field and the direction, never just "incompatible". The gate is scaffolded (OQ5, OQ6) rather than decided so the comparison can be measured against the workspace fleet before it refuses anything.
- **Bypassed publishes.** `cue mod publish` keeps working (0010 D11), so a module published without the CLI carries no verified promise, exactly as 0010 D35 accepts for catalogs. **Mitigation:** inherited exposure, stated in the policy in the same words 0010 D35 uses; the policy is honest that a gate binds the tool's users and the convention binds everyone.
- **The policy page drifts from the entries it cites.** D3 makes the citations normative and the page a paraphrase; a paraphrase can go stale when an entry is compacted. **Mitigation:** the page cites decision numbers, which are immutable; a compaction that changes a rule's substance is by definition a new decision, which is a visible event to re-read the page against.

## Drawbacks

- **Module majors become more frequent.** A break that ships as a minor today will ship as a major tomorrow, with a new module path and an import edit for every instance. This is the point, and it is still a cost the fleet pays.
- **A second document to keep true.** The policy is a page plus a CUE matrix that must agree with three entries and four `CLAUDE.md` files. D3 limits what it restates; it does not remove the maintenance.
- **Convention-layer classes get a stated non-promise.** Writing "the CLI's surface is enforced by convention" is more honest than silence and less comfortable; someone will read it as a gap and it is one.

## Alternatives

- **Do nothing for modules; let conventional commits carry the claim.** The current state. **Why not:** Gap 1 in `01-problem.md`: the claim is unverified and the failure lands on the operator, and 0010 D27 already rejected the equivalent for catalogs.
- **A maturity ladder for modules, mirroring catalog contracts.** Give each module an `apiVersion`-style rung beside its SemVer. **Why not (provisionally, OQ2 decides):** a module is one unit released as a whole and already has a major in its path plus `0.x` and prerelease forms; a catalog needs the ladder because it is a bag of independently evolving contracts under one build number, and a module is not.
- **Per-class enhancements.** One entry for module versioning, one for CLI compatibility, one for CRD versioning. **Why not:** the cross-class relations (OQ7, the core-major cascade) and the uneven enforcement are what nobody can see from inside one class; the matrix is the deliverable.
- **Read-side enforcement, checking compatibility when an instance resolves a new module version.** **Why not:** 0010 D35 settled the posture for catalogs on the render path being offline and deterministic, and the same argument holds for modules; the check belongs at publish, where both builds are nameable.
