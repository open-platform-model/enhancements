# Enhancement 0013 — Attribute-Declared Secret Fields

> **Mechanism removed 2026-08-22.** This entry was written before decisions carried a `**Kind:**` line, and it recorded construction detail — file names, directory spellings, internal identifiers, per-repo worklists — alongside its contracts. That detail has been removed from `03-decisions.md`, `02-design.md`, `06-operational.md` and this file; `## Integration Points` is now `## Affected Surfaces`, stated at the intent level. **Nothing was reversed and no decision changed its answer.** Measured evidence, `Source:` citations and *Alternatives considered* were kept in full, including their file references — those are provenance, not instructions. The removed text is in git history; construction detail belongs to the implementing repo's own change record.

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
3. [03-decisions.md](03-decisions.md) — Decision log (D1–D17; D10 supersedes D1, D11 supersedes D4, D16 resolves OQ2)
4. [04-graduation.md](04-graduation.md) — Gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md) — Risks and Mitigations, Drawbacks, high-level Alternatives
6. [06-operational.md](06-operational.md) — Operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md) — Open Questions register

Pure-CUE definitions live in [`schemas/`](schemas/): [`target.cue`](schemas/target.cue) holds the contract, [`examples.cue`](schemas/examples.cue) holds worked values covering the whole marker grammar plus a before/after of the one affected fleet module. Both compile, and the examples pin their derived values with `_assert*` fields, so a wrong example is a build failure rather than a documentation bug.

The design is measurement-driven; [`experiments/`](experiments/) holds the runnable proofs the decisions cite.

## Scope

### In scope

- The `@opm(secret, …)` marker grammar and its parsed contract (`#SecretMarker`).
- Narrowing `#Secret` to `#SecretLiteral | #SecretRef` and making `core` its only definition.
- The kernel's secret pass — Discover and Resolve — in `library/opm/secret`. Discovery keys on the type as well as the marker and fails closed: a `#Secret`-typed field without the attribute gets default routing, a marked non-`#Secret` field is an error (D13).
- Resolve-in-place: rewriting every marked path to a `#SecretRef` before the component graph is built.
- Kernel-owned Secret object naming, delivered inside the resolved value.
- Two fulfilment arms: supplied (`{value}`) and referenced (`{ref, key}`).
- The extension mechanism by which a catalog supplies an alternative materialisation backend.
- Deleting the `$opm` / `$secretName` / `$dataKey` vocabulary, the `#AutoSecrets` / `#DiscoverSecrets` / `#GroupSecrets` pyramid, and its duplicate in `catalog_opm`; correcting `core/SPEC.md` §1's claim that `#Secret` is a Primitive.
- Migrating `modules/metallb`, the only fleet module carrying a secret, including its RBAC `resourceNames` scoping.
- An `opm module inspect` secrets section.
- SOPS support at the CLI input seam (D14): accepting SOPS-encrypted values files (decrypted via the sops library before values enter the kernel), the `opm secrets template` skeleton generator, and secrets-aware `opm module vet` messaging for unfulfilled secrets.

### Out of scope

- **Implementing cryptography.** SOPS support (D14) calls the `getsops/sops/v3` library; OPM ships no cipher code, and key management is deployer configuration. Export-side encryption of rendered Secret manifests rides enhancement [0014](../0014/)'s export surface.
- **Protecting supplied-arm values inside a `ModuleInstance` CR.** A literal in a CR is plaintext in etcd — accepted and documented, with the referenced arm as the production posture on the operator path; no `valuesFrom` mechanism (D15).
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
| 03 | [kernel-omission](experiments/03-kernel-omission/) — the OQ2 measurement: the arm rewrite against the real published kernel, as omission, via both candidate mechanisms | Concluded |
| 04 | [rewrite-performance](experiments/04-rewrite-performance/) — prices the two rewrite mechanisms; decode-encode wins 12–39×, settling D17 | Concluded |

Experiment 02 is a runnable prototype rather than a probe: `experiments/02-resolve-in-place/secret/` implements the proposed `Discover` / `Resolve` API against real `cue.Value` inputs and mirrors `schemas/target.cue` type for type, so the design can be judged on running code. `go run .` in either experiment reproduces its outcome.

The last mechanical unknown — **OQ2**, whether the arm rewrite survives the real `library/opm/kernel` build path — was measured by experiment 03 (2026-08-14) against the published kernel: clean omission holds via both candidate mechanisms (fill-style through `ProcessModuleInstance`'s existing seam, bake-style through the loader overlay), override is structurally refuted by the kernel's own fill seam, and one component-graph build suffices. Resolved by **D16**. No open questions remain.

## Deviations from Design

Divergences between the accepted design and what has shipped, recorded as each slice lands. The catalog slice (`catalog_opm` OpenSpec change `catalog-remove-legacy-secrets`, archived 2026-08-30) deviates in three ways:

- **Order: the catalog removal landed before `core`'s slice, not after.** The design sequenced `core` first (the new `#Secret` published, then catalogs import it). `catalog_opm` removed its legacy block (D9, D12) while `core` on `main` still ships the identical legacy mechanism and no release carries the new `#Secret`. The interim `opmodel.dev/catalogs/opm@v3` therefore has no env-secret path at all; the replacement (`from: c.#Secret`, a transformer reading `.ref` / `.key`) is a follow-up change gated on a `core` release.
- **Release mechanics: a major crossing, not a `v1beta2` cascade.** Removing `#EnvVarSchema.from` and narrowing `#SecretSchema.data` break two beta members. Instead of moving them (and the five blueprints and two traits embedding `#ContainerSchema`) to a new `apiVersion` segment, the catalog crossed from `opmodel.dev/catalogs/opm@v2` to `@v3` with the members corrected in place; `@v2` is frozen on GHCR. Member fqns are unchanged.
- **Fleet: removed now, reintroduced under 0013; not migrated.** The seven `modules` on `main` that used the legacy vocabulary are stripped of it (`modules-drop-legacy-secrets`) rather than rewritten onto a not-yet-published replacement, and the `cli` `secrets-module` fixture is deleted (`delete-secrets-test-fixtures`). Both are restored when the kernel-resolved `#Secret` ships.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `core/openspec/config.yaml`, `library/CONSTITUTION.md`, `cli/CONSTITUTION.md` | Design principles governing changes in the touched repos (core carries its constitution in `openspec/config.yaml`) |
| `core/.claude/skills/core-schema-edit/SKILL.md` | Binding protocol for the core schema slice; also carries a stale helper list this enhancement corrects |
| `core/SPEC.md` | Misdescribes `#Secret` as a Primitive, and records the synthesis removal |
| `cli/docs/rfc/0002-sensitive-data-model.md` | The original sensitive-data RFC whose redaction goal this design finally delivers |
| Enhancement [0009](../0009/) | Evidence that depending on CUE attributes is safe (`research/cue-attribute-longevity.md`) |
| Enhancement [0010](../0010/) | OQ9, whose candidate (b) D8 resolves |
| Enhancement [0011](../0011/) | The `@opm(identity, owner=publish)` attribute precedent D2 follows |
