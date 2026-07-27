# Risks, Drawbacks, Alternatives — Module and Catalog Publishing

This document records the honest costs of the proposed design. Risks describe what could go wrong; Drawbacks describe what definitely costs something; Alternatives describe the high-level paths not taken (per-decision detail lives in `03-decisions.md`).

## Risks and Mitigations

- **The namespace move rewrites every published coordinate, and it is an identity change rather than a redirect.** A module's declared path is also its identity, so moving `opmodel.dev/modules/<name>` to `opmodel.dev/m/<owner>/<name>` changes its UUID and the owner label on every resource deployed from it. Blast radius: every published artifact, every live instance, every pin in `releases/`. **Mitigation:** OQ6 must be resolved before `accepted`, and the migration must land in the same window as enhancement 0010's identity change. The cost is proportional to how much is published when it lands, so delay is strictly more expensive here than anywhere else in this design.

- **Publish cannot authenticate, and nothing in the CLI does today.** D5 makes the central registry the write target while the CLI has no `opm login`, no credential-helper handling, and no token storage — it inherits whatever the ambient environment offers. Blast radius: the command cannot ship. **Mitigation:** OQ2 is a promotion blocker, not a follow-up. Even the minimal answer ("inherit `cue login`, document it") has to be stated and tested, because the failure mode of an unauthenticated push against a real registry is a partially-completed release.

- **A mutable tag makes every downstream guarantee conditional.** If a tag can be overwritten under a consumer who already resolved it, a pinned version stops naming fixed bytes and every digest comparison silently checks a moving target. Blast radius: reproducibility across the whole ecosystem, plus a time-of-check-to-time-of-use vector. **Mitigation:** OQ3, resolved two-sided — a stated registry-side immutability requirement plus a client-side refusal to overwrite an existing tag. Note the client-side half alone is not sufficient, since `cue mod publish` bypasses it.

- **Retiring the checksum-driven bump removes the fleet's publish trigger before a replacement exists.** `publish:smart` currently decides both *whether* to publish and *at what version*; deleting it without an answer means the modules repo has no release process. Blast radius: the fleet stops being publishable, which is a soft failure that will be discovered late. **Mitigation:** OQ4 is a promotion blocker and its answer must have published a real module before the old task is deleted.

- **A refusal that fires too easily gets routed around.** Every gate here is a refusal, and `cue mod publish` remains available as an escape hatch that skips all of them. A gate that blocks a legitimate publish teaches publishers to bypass OPM's tooling entirely, which removes every other gate at the same time. Blast radius: the design's producer-side half becomes decorative. **Mitigation:** each refusal names the offending value, its file, and the action that clears it; the identity-completeness gate is on concreteness rather than on a broader notion of well-formedness; and the catalog override gate — the only unconditional one — is scoped to the presence of a single file that has no reason to exist in a release tree.

- **A refusal in CI reads as a broken pipeline rather than a caught defect.** The local-override gate and the identity gate will first fire inside someone's release workflow, where the default interpretation of a non-zero exit is "the tooling is broken." Blast radius: pressure to add a bypass flag for the wrong reason. **Mitigation:** the message must distinguish itself from a tool failure — state what was found, what would have been published, and what a consumer would have resolved instead.

## Drawbacks

- **Releasing gains a step.** `version set` → review → commit → `publish` is four operations where `task publish VERSION=…` was one. Accepted: the added operation is the commit, and it is the thing that makes an artifact traceable to a source state. The cost falls hardest on the ephemeral-CI case, where the tree is discarded either way, and OQ1 decides whether that case keeps a one-command path.

- **A local development tree cannot be published without an explicit act.** An author who has been working against local replacements must remove or bypass them before a release. Accepted: that is the point, and the alternative is an artifact that resolves against dependencies nobody validated.

- **Catalog authors lose an escape hatch that module authors keep.** The asymmetry is deliberate (D6) but it is still an asymmetry someone will hit and have to be told about, and "why can I force this for a module but not a catalog" is not self-evident from the error alone. Accepted: the message must carry the reason, not just the rule.

- **`opm` becomes the required path to a correct publish.** `cue mod publish` still works and still bypasses every gate, so the design's producer-side guarantees hold only for people who use OPM's tooling. Accepted, and bounded by design: the guarantees consumers actually rely on live on the read paths in enhancement 0010, which no publisher can bypass. This entry makes conformance the default; it does not make it inevitable.

- **The reserved-segment namespace is a one-way decision.** Once artifacts are published under `opmodel.dev/m/<owner>/<name>`, changing the segment or the scoping scheme means migrating the fleet again. Accepted: the specific spelling is cheap to have chosen differently, but the owner-scoping itself is what supplies uniqueness and is not worth deferring.

## Alternatives

- **Keep publishing in repo-local Taskfiles and fix them individually.** **Why not:** it is the current state, and it produced three different answers to "what version is this artifact" plus a catalog flow that publishes bytes that never existed in git. Each Taskfile is correct on its own terms and none of them can enforce anything on the others.

- **Publish by wrapping `cue mod publish` with pre-flight checks only, adding no commands.** **Why not:** it leaves version authoring unowned, which is where the drift originates. A wrapper can refuse a bad publish but cannot make a good one easy, so the pressure to bypass it stays.

- **An index-only central registry, with authors publishing under their own domains.** **Why not:** CUE resolves a module path to a host through the `CUE_REGISTRY` prefix mapping with no per-domain autodiscovery, so a self-hosted path is unresolvable for every consumer who has not first edited their own configuration. Zero-setup consumption and publish-anywhere are not simultaneously available.

- **Let release automation write identity files directly** — release-please can rewrite a version in an arbitrary file through an `x-release-please-version` comment annotation, so a `.cue` file would work. **Why not:** it creates a second writer of the same field, operating outside the command that owns it, which is the exact shape of drift this design removes. Automation should call the command instead.
