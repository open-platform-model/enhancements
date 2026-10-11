# Operational Concerns: OPM Versioning Policy

The OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

The policy itself introduces none. If OQ5/OQ6 land the module compatibility gate, `opm module publish` gains a refusal class of the same shape as the catalog gate's: it names the artifact, the predecessor version compared against, the field or constraint that changed, the change class, and the level the authored version would have needed. A refusal is a publish-time error to the author, never a runtime signal. The check command's module mode, if adopted under 0010 D35's aid posture, reports the same comparison without refusing. Where the comparison is emitted today for catalogs is evidence of the shape, not an instruction: the catalog gate's refusals are the `Refusal` findings the check report reuses.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

No schema, command or artifact format changes. `opmodel.dev/core` is untouched (`core_schema: false`). The policy reclassifies what an already-published module version *promises*, which has no effect on any published bytes. It does mean that a module whose history contains a `#config` break inside a major is, under the policy, carrying a promise it has already broken. The policy says what such a module does at its next release (OQ12). A publish gate, when it lands, is additive to the CLI's surface: new refusals, no changed semantics for a publish that would have succeeded under the policy anyway. `config.yaml.semver` is expected to be `none`; the graduation gate records the condition under which it is not.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed. The versioning paragraphs in `core/CLAUDE.md`, `catalog_opm/CLAUDE.md` and `modules/CLAUDE.md` become pointers at the published policy for the rules the policy owns, and keep the repo-local mechanics (which task writes the version, which branch takes which release). The core repo's commit-type table stays as the claim layer for that class; the policy is what defines the surface the table's "breaking" row refers to.

## Rollback

**If this lands and proves bad, what's the rollback story?**

The policy page and the `CLAUDE.md` pointers revert as documentation. A module gate, if landed, is removed from the publish path without affecting any published artifact; a version refused by the gate was never published, and a version that was published stays published. There is no data-plane state. Modules that bumped a major under the policy keep their new module path; a major cannot be un-cut, and that is U5's ordinary cost rather than a rollback hazard.

D10's rulesets can be switched off by an organization owner, an audited edit. A release branch is never deleted, so a rollback leaves the branches in place. Immutable releases cannot be rolled back: a release created while the setting was on stays immutable after it is turned off, which is why the CLI and the operator join only after their draft-first release flow has shipped.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

- The published policy must exist before any repo's `CLAUDE.md` points at it, because a pointer at nothing is worse than the paragraph it replaces.
- OQ1..OQ4 must be resolved before a module gate is built, because the gate compares against the surface those questions complete, and a gate built against D2 alone would enforce half the rule.
- The generalized comparison in `library` must exist before `cli` can refuse on it, in the same producer-consumer order the catalog gate followed.
- OQ7's answer changes how `catalog_opm` releases are cut and must be published before the next catalog release that ships a new contract level or a tombstone, or that release decides the rule by precedent.
- D10's platform rules and tooling land in the order below. Each step's precondition is a state an owner can read from the organization's ruleset and immutable-release settings or from the repositories, not a date.
  1. The tag ruleset refusing update and deletion needs nothing first: no release flow moves or deletes a tag.
  2. Immutable releases for core, the kernel library and `catalog_opm` need nothing first: none of them adds assets to a release after publishing it.
  3. Immutable releases for the CLI and the operator are on only once that repository has shipped a release created as a draft, given every asset while a draft, and published last. While the setting covers either repository before then, its next release fails at the first asset upload, so an owner narrows the setting before that release; a release created while it was on stays immutable.
  4. No ruleset over `docs/*` branches exists in the in-scope repositories or `opm`: D10 retired the `docs/vX.Y` design because such a ruleset freezes every documentation topic branch.
  5. The release-branch ruleset is created only after an owner has removed every `release/*` branch that is not a D10 maintenance branch, such as `catalog_opm`'s `release/opm-stable`: under the ruleset such a branch can never be deleted, and it matches the release workflows' branch trigger. The mention-guard ruleset includes `release/*` from the same point.
  6. The tag-creation ruleset is enabled in a repository only when every release path there runs as the release app, maintenance lines such as `v1` included, because it refuses any other actor's tag. It also needs a sandbox run showing the release app still creates tags under it by both paths release-please uses: an explicit tag ref created before a draft release (the CLI and the operator) and the tag GitHub creates with a published release (core, the library, `catalog_opm`). That run needs three owner settings for the sandbox repository, `release-flow-sandbox`: the release app installed on it, the organization variable `RELEASE_APP_CLIENT_ID` and secret `RELEASE_APP_PRIVATE_KEY` shared with it, and immutable releases on. Without the first two the run cannot mint the app's token. If a release fails on the ruleset anyway, an owner disabling it is the recovery.
  7. The release-branch automation comes last and before any cut (D10 R10) and before GA (D8 R10). Its constraints follow.
- The cut action:
  - picks the newest tag of the minor by SemVer precedence, since a plain version sort ranks `v2.0.0-beta.1` above `v2.0.0`;
  - runs as the release app, which may not change workflow files, so the cut writes release-please settings only, and a caller of a shared cut action passes the app's credentials explicitly, because a secret the caller cannot see leaves the cut without a token;
  - creates the release branch only after everything it pushes first has succeeded, and a re-run continues from a branch found at the cut tag's commit (D10 R12), because the release-branch ruleset makes a stray branch permanent;
  - names its pull request's head branch outside `release/`, so the release-branch ruleset does not pin it, and gives its commit a type that releases nothing;
  - refuses unless D10 R9 holds for that component.
- A release from a branch:
  - happens only when the release workflow at the cut tag can release from the branch. A tag whose workflow would run on the branch but release as if on `main` is refused before the cut creates anything. A tag whose workflow does not run on the branch at all is cut, and the branch releases nothing until a reviewed backport brings a workflow that can; every `opm` tag in `catalog_opm` is such a tag;
  - in `catalog_opm` releases only the branch's own component, because a second configured component would release commits the branch inherited from `main`;
  - never becomes GitHub's Latest release. release-please has no setting for the flag, so the release path either publishes branch releases with Latest off or restores Latest to `main`'s newest release; the operator also skips its `latest` image push there;
  - is matched on `main` by a release path that refuses any `X.Y.*` version once `release/<tag-prefix>vX.Y` exists (D10 R9), and pull requests into the branch run `main`'s required checks (D10 R11).
- The sandbox proves a cut from a tag that predates the automation, a failed and re-run cut, and the case where `main` and a branch would compute the same version, before any in-scope repository adopts the automation.
- The operator's CRD policy (OQ9) constrains any future second CRD version and nothing that exists; it has no ordering dependency on the other repos.
