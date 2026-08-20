# Graduation Criteria — Documentation Architecture

What must be true before this entry moves between statuses. Each gate is stated so that it can be checked rather than judged.

## draft → accepted

- Every Open Question (OQ1 through OQ6) is resolved by a decision, deferred to a named enhancement, or answered in place.
- The eight-section taxonomy is ratified, including the two placements that are deliberate: Diagnostics as a top-level entry point, and Concepts sized in proportion to the concept surface rather than treated as an appendix.
- The enforcement badge vocabulary is closed and compiles in `contracts/contracts.cue`, and each of the four values has at least one worked example drawn from a real constraint.
- The generated-versus-authored field classification covers every field a reference entry will carry, so that no field's provenance is decided during implementation.
- `plan.yaml` exists with one slice per repo landing, an explicit dependency order, and no slice whose concern spans two repos.
- The retirement path for `opm/docs` is decided (OQ4), including whether the area vocabulary changes.
- `task vet:one ID=0018` passes and `task check ID=0018` passes or its warnings are documented in the PR body.

## accepted → implemented

Content:

- All eight sections exist on the published site and every section's index links at least the pages its slice defines.
- Concepts covers, at minimum, the four concepts ranked highest for reader harm: the four version-shaped axes, `fqn == modulePath` for artifacts, `matchLabels` versus `metadata.labels`, and the component derivation rule.
- Diagnostics distinguishes, with a worked cause and fix for each: an unresolved resource demand, an unhandled trait at each posture, an identity mismatch at acquire, an identity mismatch at materialize, a named catalog build that is not published, and a component that pairs nothing.
- The boundaries page (D3) exists and names every absent system.
- The deletion and prune page (D4) exists and states the current behaviour of both the CLI-owned and operator-owned paths.
- No page describes secrets (D5), and the section that would carry them says so and links enhancement 0013.

Generation:

- `task generate` succeeds on a clean checkout. The `generate:cli` step, which fails today, is fixed.
- The catalog reference is generated from evaluated CUE, and every one of the 70 members carries a description in the generated output.
- The reference is split by family (D6), with the raw `k8s-*` family behind a single index page.
- Worked examples in the reference are sourced from the transformers' embedded golden tests rather than hand-copied.

Source quality:

- Doc-comment coverage in `catalog_opm` reaches 100 percent on blueprints, abstraction resources and traits. Current state is 0 of 5, 1 of 11 and 6 of 27.
- A CI gate in `catalog_opm` fails the build when a new member ships without a doc comment.
- The roughly 35 `core` definitions with no `SPEC.md` section carry doc comments sufficient for a generated entry, `types.cue` foremost.
- `library/docs/getting-started.md` includes the Materialize step and can be followed end to end to working code.

Retirement:

- `opm/docs`'s stale content is removed or redirected, per the OQ4 decision, and no document in the workspace links to it as current guidance.
- `cli/docs/STYLE.md` no longer cites commands that do not exist, and its glossary reference no longer uses a workspace-relative path.

Verification:

- A reader following the Start here section from a clean machine reaches a rendered module without consulting any other source. Verified by walking it, not by assertion.
