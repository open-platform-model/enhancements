# Enhancement 0013 — Attribute-Declared Secret Fields

OPM currently makes a sensitive field carry its own routing — `$opm`, `$secretName`, `$dataKey` — inside the value, forcing every module to state that routing a second time by hand. This enhancement moves the routing to an inert CUE field attribute on the declaring field, keeps a narrowed `#Secret` type as the deployer's fulfilment slot, and moves discovery and resolution into the library kernel.

See [`config.yaml`](config.yaml) for the metadata contract — it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

The design rests on one split. The **attribute** carries routing — which Kubernetes object a key belongs in — which is metadata, written by the module author, identical in every environment. The **type** carries fulfilment — the data itself, or where it already lives — which is data, written by the deployer, different per environment, and type-checked by CUE rather than by OPM tooling.

```cue
// author, once, in the published module
#config: db: password: #Secret @opm(secret, group=db-creds, key=password)

// deployer, per environment
values: db: password: {value: "hunter2"}                           // supplied
values: db: password: {ref: "existing-db-creds", key: "password"}  // referenced
```

`#Secret` narrows to `#SecretLiteral | #SecretRef` — six lines in `core`, replacing 455 dead lines there and 439 duplicated ones in `catalog_opm`, along with a 240-line hand-unrolled discovery comprehension.

The kernel then does two things. It **discovers** every marked field by walking the module's `#config`, which works with no values present, has no depth ceiling, and covers lists and pattern-constrained maps. It **resolves in place**: it groups the declarations, names each Kubernetes object exactly once, sends the plaintext out of band, and rewrites every marked path to a `#SecretRef`. A literal becomes a reference to the object the kernel just decided to create; a deployer-written reference passes through as itself.

After that rewrite the two arms are indistinguishable, so a transformer reads `.ref` and `.key` from one branch — no variant dispatch, no name computation, no side lookup. Because the object name lives inside the value, there is exactly one such string and every consumer reads it, which makes today's live env-vs-volume name mismatch unrepresentable rather than merely fixed. And because `#SecretRef` is closed with no `value` field, the absence of plaintext in the render is structural.

Two properties fall out that the first draft of this design did not have: **instance files for supplied secrets do not change at all**, since `{value: "…"}` is already what people write; and a secret interpolated into a rendered config file fails at plain `cue vet` against `debugValues`, at authoring time, before the kernel is involved.

*How* a supplied secret is materialised — plain Secret, SealedSecret, ESO — is a platform choice resolved through catalog subscription, not an author decision. That mechanism also answers enhancement [0010](../0010/)'s still-open OQ9, by supplying the secrets resource FQN from the platform rather than from a literal in `core`.

## Documents

1. [01-problem.md](01-problem.md) — Routing stated twice with nothing checking it, three disagreeing name derivations, an unused discovery pyramid, and plaintext in the render
2. [02-design.md](02-design.md) — Routing in an inert `@opm(secret, …)` attribute, fulfilment in a narrowed `#Secret` disjunction, and a kernel that resolves both arms in place
3. [03-decisions.md](03-decisions.md) — Append-only decision log (D1–D12; D10 supersedes D1, D11 supersedes D4) + Open Questions
4. [04-graduation.md](04-graduation.md) — Per-status gates (draft → accepted → implemented)
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)

Pure-CUE definitions live in [`schemas/`](schemas/): [`target.cue`](schemas/target.cue) holds the contract, [`examples.cue`](schemas/examples.cue) holds worked values covering the whole marker grammar plus a before/after of the one affected fleet module. Both compile, and the examples pin their derived values with `_assert*` fields, so a wrong example is a build failure rather than a documentation bug.

The design is measurement-driven; [`experiments/`](experiments/) holds the runnable proofs the decisions cite.

## Scope

### In scope

- The `@opm(secret, …)` marker grammar and its parsed contract (`#SecretMarker`).
- Narrowing `#Secret` to `#SecretLiteral | #SecretRef` and making `core` its only definition.
- The kernel's secret pass — Discover and Resolve — in `library/opm/secret`.
- Resolve-in-place: rewriting every marked path to a `#SecretRef` before the component graph is built.
- Kernel-owned Secret object naming, delivered inside the resolved value.
- Two fulfilment arms: supplied (`{value}`) and referenced (`{ref, key}`).
- The extension mechanism by which a catalog supplies an alternative materialisation backend.
- Deleting the `$opm` / `$secretName` / `$dataKey` vocabulary, the `#AutoSecrets` / `#DiscoverSecrets` / `#GroupSecrets` pyramid, and its duplicate in `catalog_opm`; correcting `core/SPEC.md` §1's claim that `#Secret` is a Primitive.
- Migrating `modules/metallb`, the only fleet module carrying a secret, including its RBAC `resourceNames` scoping.
- An `opm module inspect` secrets section.

### Out of scope

- **Encryption at rest of instance values.** Resolution keeps plaintext out of the render; it does not protect the input the deployer supplies. This design makes out-of-band supply possible but does not implement it.
- **Shipping an ESO / Vault / SealedSecrets / CSI backend.** The extension mechanism is in scope; additional backends are follow-on catalogs.
- **Secret rotation, leasing, or dynamic secrets.** A secret is resolved once per render.
- **Retiring the hand-authored `#SecretSchema` path.** A module that computes a whole file and stores it as Secret data keeps writing it by hand.
- **A general-purpose `@opm(...)` marker framework.** This entry defines the `secret` marker and reuses the existing namespace. Whether enhancement [0009](../0009/)'s `@op(...)` should fold into the same namespace is a question for 0009.
- **Redacting secrets from CLI or operator logs generally.** The design removes plaintext from the *render*; log hygiene elsewhere is a separate concern.

## Experiments

| # | Concept | Status |
| - | ------- | ------ |
| 01 | [attribute-propagation](experiments/01-attribute-propagation/) — does a CUE field attribute survive everything the OPM artifact shape does to it, and can a Go walk find it? | Concluded |
| 02 | [resolve-in-place](experiments/02-resolve-in-place/) — a working prototype of the proposed `library/opm/secret` kernel pass: discover, resolve both arms to `#SecretRef`, materialise | Concluded |

Experiment 02 is a runnable prototype rather than a probe: `experiments/02-resolve-in-place/secret/` implements the proposed `Discover` / `Resolve` API against real `cue.Value` inputs and mirrors `schemas/target.cue` type for type, so the design can be judged on running code. `go run .` in either experiment reproduces its outcome.

One measurement is still outstanding before acceptance — it is **OQ2**, the sole blocker (see [04-graduation.md](04-graduation.md)): experiment 02 performs the arm rewrite by decode → mutate → encode, which sidesteps unification, and that has not been measured against the real `library/opm/kernel` build path.

## Deviations from Design

None at this stage. Update this section when implementation lands.

## Cross-References

Every path below exists today.

| Document | Purpose |
| -------- | ------- |
| `core/CONSTITUTION.md`, `library/CONSTITUTION.md`, `cli/CONSTITUTION.md` | Design principles governing changes in the touched repos |
| `core/.claude/skills/core-schema-edit/SKILL.md` | Binding protocol for the `core/src/*.cue` slice; also carries a stale helper list this enhancement corrects |
| `core/src/schemas.cue` | The dead secret block deleted by D9 |
| `core/src/transformer.cue` | `#ComponentTransformer` and `#TransformerContext` — gains the `secrets` field |
| `core/src/module_instance.cue` | Carries the comments describing the removed `opm-secrets` synthesis |
| `core/SPEC.md` | §1 misdescribes `#Secret` as a Primitive; §513/§521 record the synthesis removal |
| `core/.tasks/spec-tracked.txt` | Tracked-construct list; `#Secret` is absent from it despite SPEC.md §1 |
| `catalog_opm/src/resources/secret.cue` | The duplicated contract type and discovery pyramid deleted by D9 |
| `catalog_opm/src/resources/container.cue` | `#EnvVarSchema.from` narrows from `#Secret` to `string` |
| `catalog_opm/src/transformers/container_helpers.cue` | Both consumption sites — env (`:52-89`) and volume (`:368-388`) — move onto `#context.secrets` |
| `catalog_opm/src/transformers/secret_transformer.cue` | Loses the `opm-secrets` branch and all name computation |
| `library/opm/schema/paths.go` | `Config` is the discovery root; gains the `#context.secrets` path constant |
| `library/opm/schema/context.go` | `BuildTransformerContext` — unchanged by this design; listed because the first draft would have touched it |
| `library/opm/kernel/phases.go` | Where Discover / Resolve are wired; `Validate` keeps using supplied values (OQ2) |
| `library/opm/kernel/synth.go` | Synthesises the secrets component with a platform-supplied FQN |
| `library/opm/compile/execute.go` | Gains the `.value`-on-a-resolved-secret diagnostic |
| `modules/metallb/module.cue`, `modules/metallb/components.cue` | The only fleet module carrying a secret; RBAC `resourceNames` moves with the object name |
| `modules/DESIGN_PATTERNS.md` | `schemas.#Secret` pattern section (`:84-110`) and summary row (`:630`) |
| `cli/tests/fixtures/valid/secrets-module/module.cue` | Fixture ported to the attribute form |
| `cli/openspec/specs/auto-secrets-injection/spec.md` | Already Superseded; retired by this enhancement |
| `cli/docs/rfc/0002-sensitive-data-model.md` | The original sensitive-data RFC whose redaction goal this design finally delivers |
| `enhancements/0009/research/cue-attribute-longevity.md` | Evidence that depending on CUE attributes is safe |
| `enhancements/0010/03-decisions.md` | OQ9 — whose candidate (b) D8 resolves |
| `enhancements/0011/02-design.md` | The `@opm(identity, owner=publish)` precedent D2 follows |
