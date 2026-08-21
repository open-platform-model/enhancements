# Operational Concerns — Attribute-Declared Secret Fields

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one, even briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Four new diagnostics, all from the library kernel:

- **Module reads `.value` of a resolved secret** (`opm/compile/execute.go`). The most important one, because the bare CUE error (`undefined field: value`) does not say why. The kernel knows which paths it rewrote, so it re-reports against the config path: *"module reads `.value` of the secret at `db.password`; secret data is not readable during render."*
- **Unknown `@opm` marker kind** (`opm/secret`). A warning listing the field path and the unrecognised position-0 value — the first defence against a mistyped marker. Surfaced in normal output, not behind a verbose flag.
- **Field typed `#Secret` that discovery did not find** (`opm/secret`). A contradiction, and a hard error: it catches the mistyped-*argument* case the warning above misses.
- **Group disagreement** (`opm/secret`). Two members of one group declaring different `type` or `immutable`, with both config paths named.

Two more diagnostics come free from CUE and need no OPM code:

- **Unfulfilled secret** — both `#Secret` arms carry required fields, so an unsupplied secret is non-concrete and `cue vet -c` names it by path.
- **Secret interpolated into a string** — a struct-in-string error at plain `cue vet` against `debugValues`, at authoring time.

Structured surface: `#SecretsResolution.unfulfilled` and `declarations` are part of the kernel's return, so the CLI and the operator report from the same data rather than re-deriving it.

New CLI output: `opm module inspect` gains a secrets section listing each declared secret's config path, group, key, description, and fulfilment state — readable from a module alone, with no instance, because discovery reads the schema (D3).

Deliberately **not** introduced: any log line, metric label, or error message carrying a secret value. Diagnostics identify a secret by config path and by the object/key it resolved to, never by its data.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

**Breaking.** Expected `semver: major`, to be confirmed at acceptance.

- **`opmodel.dev/core@v1`** — `#Secret` is narrowed (its arms lose `$opm`, `$secretName`, `$dataKey`; `#SecretK8sRef` is replaced by `#SecretRef`), and `#SecretSchema`, `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets`, `#SecretContentHash`, `#SecretImmutableName` are removed. Tightening a published constraint and removing published definitions are both breaking. `#TransformerContext` is **unchanged**. Core ships on the `v1.0.0-alpha.N` prerelease line, so a `feat!:` advances the alpha counter rather than forcing `@v2`.
- **`opmodel.dev/catalogs/opm@v1`** — stops redeclaring `#Secret` and imports core's; `#SecretSchema.data` narrows from `#Secret | string` to `string`. Breaking. Also on a `v1.x.x-alpha.x` prerelease line.
- **`library`** — the kernel's public surface gains `opm/secret`. Breaking for direct callers, which are `cli` and `opm-operator`, both in this workspace.
- **`modules`** — every module using `res.#Secret`'s `$`-field form must migrate. That is exactly one: `metallb`.

**Instance files do not change for supplied secrets.** `{value: "…"}` is already the shape people write, and D10 keeps it. Only a *referenced* secret changes shape, from `{secretName, remoteKey}` to `{ref, key}` — and no module in the fleet uses that arm today.

No compatibility window (D9). The two shapes cannot coexist because the `$`-fields and the narrowed arms are mutually exclusive on the same field. `cli` has no external users, so no deprecation is owed there.

## Deprecation

**What gets removed and when? What replaces it?**

Everything below is removed in the same release that lands the enhancement.

| Removed | Replaced by |
| --- | --- |
| `$opm` / `$secretName` / `$dataKey` on the value | `@opm(secret, group=…, key=…)` on the field |
| `#SecretType`, `#SecretK8sRef` | `#SecretRef` (`{ref, key}`) |
| `catalog_opm`'s duplicate of `#Secret` and friends | import from `core` (D12) |
| `#AutoSecrets`, `#DiscoverSecrets`, `#GroupSecrets` (both copies) | `library/opm/secret.Discover` |
| `#SecretContentHash`, `#SecretImmutableName` (both copies) | kernel-side hashing in Resolve (D5, D11) |
| `core`'s `#SecretSchema` | `catalog_opm`'s `#SecretSchema`, `data` narrowed to `string` |
| `opm-secrets` component-name special case (`secret_transformer.cue:63-66`) | instance-scoped naming (D6) |
| Name computation in `container_helpers.cue:78` and `:374-379` | reading `.ref` from the resolved value (D11) |
| `cli/openspec/specs/auto-secrets-injection/spec.md` | retired; already marked Superseded |
| `core-schema-edit` SKILL.md entries for the removed helpers | updated list |

Retained: `#ContentHash` and `#ImmutableName` (still used by the ConfigMap path), and `catalog_opm`'s `#SecretsResource` / `#Secrets` / `#SecretSchema` for hand-authored Secret data such as a computed config file.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Straightforward at the artifact level, with one cluster-state caveat.

Every affected repo publishes immutable versioned artifacts, so rolling back is pinning the previous version: `core` and `catalogs/opm` to their prior alpha, `library` to its prior tag, `modules/metallb` to its prior published version. Previously published module versions remain consumable because they pin the older `core` and catalog majors — nothing retroactively invalidates an already-published module.

Instance files are unaffected in either direction for supplied secrets, since their shape does not change. That removes what would otherwise be the messiest part of a rollback.

The caveat is **cluster state, which does not roll back with code**. The Secret object name changes under D6 (`metallb-speaker-memberlist` → `metallb-memberlist`). Rolling the code back means workloads look for the old name again, and the old object may have been pruned by the apply layer's inventory reconciliation. Rollback for an already-migrated instance therefore requires either keeping the old object until the migration is confirmed, or re-applying the rolled-back render and letting it recreate the object from the instance values — which still hold the data, unchanged.

Nothing in this design writes state that outlives a render other than the Secret objects themselves.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Strict order — each step consumes a published artifact from the one before.

1. **`core`** — narrow `#Secret`; delete the dead machinery; correct `SPEC.md` §1; regenerate `INDEX.md`. Load `core-schema-edit` first; the SPEC co-update is gated by the pre-commit hook and CI. Publishes a new `v2.0.0-alpha.N`.
2. **`library`** — implement `opm/secret` (Discover, Resolve), wire the phases, add the `.value` diagnostic. Consumes the new core alpha. Publishes a new library tag. The build shape is settled (D16, measured by experiment 03): raw values validate in the existing separate `Validate` evaluation, one component-graph build assembled from resolved values only, rewrite via decode → splice → encode (D17).
3. **`catalog_opm`** — drop the duplicate and import core's `#Secret`; rewrite both consumption sites to read `.ref` / `.key`; strip name computation from `secret_transformer.cue`. Consumes the new core alpha. Publishes a new `v2.x.x-alpha.x`.
4. **`cli`** and **`opm-operator`** — bump to the new library; port the `secrets-module` fixture; add the `opm module inspect` secrets section. These two can land in parallel.
5. **`modules`** — migrate `metallb` onto the new core + catalog pins. **Migration step, not a code change:** the rendered Secret name changes, and `components.cue`'s RBAC `resourceNames` scoping references the rendered object name. Both must change together, and the module must be re-rendered and diffed against the running cluster before apply. Instance values need no edit.
6. **`opmodel.dev`** — regenerate the schema reference; rewrite the secrets section of the authoring docs around the routing/fulfilment split.
7. **`modules/DESIGN_PATTERNS.md`** — rewrite the `schemas.#Secret` pattern section (`:84-110`) and the summary-table row (`:630`).

Steps 2 and 3 both depend only on step 1 and can proceed in parallel, but step 4 needs both. Step 5 is the only one that touches a live cluster.

The order above is encoded structurally in a delivery plan under `plans/`; this prose carries the rationale, the plan carries the state.
