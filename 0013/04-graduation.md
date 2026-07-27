# Graduation Criteria — Attribute-Declared Secret Fields

This document records the gates that must hold before the enhancement advances along the design lifecycle. Treat these as design acceptance criteria, not implementation milestones — implementation progress lives in `config.yaml.implementation` and the `history` list.

## draft → accepted

The enhancement is ready to be implemented when:

- **OQ2 is resolved.** Whether replacing a user-supplied `#SecretLiteral` with the kernel-resolved `#SecretRef` is a clean value replacement is the single open question. It is answered by a measurement against the real `library/opm/kernel` path — not a synthetic one — and it determines whether the kernel needs two builds (one to validate against supplied values, one to render against resolved values) or can do both in one. An experiment for this must reach `Status: Concluded`.
- OQ1 stays `resolved-by-D10` and `schemas/target.cue` carries no `OQ` marker comments.
- `cue vet ./...` passes from `schemas/`, and `schemas/examples.cue`'s `_assert*` fields still unify.
- Decisions D1..D12 are locked, each carrying the four-field format, with the supersession chain intact (D10 supersedes D1; D11 supersedes D4; D12 amends D9).
- Goals and Non-Goals in `02-design.md` are final and reviewed — in particular the Non-Goal boundary around encryption at rest, which this design enables but does not implement.
- `experiments/01-attribute-propagation` and `experiments/02-resolve-in-place` are `Status: Concluded`, and their outcomes are reflected in the decisions that cite them.
- `semver` in `config.yaml` is set. Expected `major`: `core` removes published definitions and narrows `#Secret`'s arms, and `catalog_opm` narrows `#SecretSchema.data` — both breaking for any consumer using them.
- `affects` is final; `area` appears in `affects`.
- `README.md ## Scope` carries `### In scope` and `### Out of scope`.
- The Cross-References table in `README.md` lists every file path the implementation will touch, and every path in it exists today.
- No `{Capitalised}` placeholder strings remain in any markdown file.

## accepted → implemented

The enhancement is shipped when:

- **`core`** carries `#Secret` narrowed to `#SecretLiteral | #SecretRef`, and `src/schemas.cue` no longer contains `#SecretType`, `#SecretK8sRef`, `#SecretSchema`, `#SecretContentHash`, `#SecretImmutableName`, `#AutoSecrets`, `#DiscoverSecrets`, or `#GroupSecrets`. `#TransformerContext` is unchanged. `SPEC.md` §1 no longer describes `#Secret` as a Primitive. `task check` passes (fmt, vet, INDEX freshness, SPEC inventory).
- **`library`** ships `opm/secret` with `Discover` and `Resolve`, wired into `opm/kernel/phases.go`, with test coverage on: discovery from a bare `#config`; discovery through a cross-CUE-module import; nesting past ten levels; list elements; pattern-constrained maps; resolution leaving unmarked values untouched; a deployer-written `#SecretRef` passing through unprefixed; rejection of a group whose members disagree on `type` or `immutable`; and the OQ2 build shape, whichever it turns out to be.
- **`catalog_opm`** reads `.ref` / `.key` at both consumption sites, computes no Secret object names anywhere, imports `#Secret` from core rather than redeclaring it, and the `opm-secrets` branch is gone. `task check` passes.
- **`modules/metallb`** uses the attribute form, its hand-written `spec.secrets` map is deleted, its instance values are unchanged, and its RBAC `resourceNames` scoping matches the new object name. It renders and deploys against a real cluster at least once.
- **`cli`** ports `tests/fixtures/valid/secrets-module/`, retires the superseded `auto-secrets-injection` spec, and `opm module inspect` lists a module's declared secrets with their groups, keys, and fulfilment state.
- A rendered manifest set for a secret-bearing instance contains **no** plaintext secret value outside the Secret objects meant to hold it. This is the enhancement's headline property; it is verified against real output, not asserted.
- A module that interpolates a secret into a string is confirmed to fail at plain `cue vet`, and a module that reads `.value` of a resolved secret is confirmed to produce the config-path diagnostic rather than a bare CUE field error.
- `config.yaml.implementation.status = complete` with `date` set to the final landing date.
- `history` carries an event per repo landing, with the `slice` field naming the OpenSpec change where the target repo uses one.
- `README.md` carries an `> **Implementation status (YYYY-MM-DD).**` quote block whose date matches `implementation.date`.
- `## Deviations from Design` in `README.md` lists every deliberate divergence, or says "None".
