# Risks, Drawbacks, Alternatives — OPM Module Publishing Workflow

> **Stub.** This entry is superseded; its narrative documents were collapsed on 2026-07-29. The risk and alternatives narrative below was written against a design that later decisions retired, so it is summarised rather than reproduced. **The Blast Radius audit is kept in full** — it was measured site by site against real code rather than inferred, and nothing in the successors reproduces the per-site table. The full prior text is in git history.

## What the risk narrative covered

Six risks, of which two outlived the entry and were carried into the successors:

- **The acquire-time check will refuse modules that already exist.** Nothing had ever verified `metadata.version` against a release tag, so any already-published module whose stamp drifted becomes unfetchable the moment the check lands — including modules that appear to work today. The failure arrives at fetch time rather than at upgrade time.
- **The owner-scoped namespace move is a full-fleet identity change that compounds daily.** `modulePath` feeds `fqn` → `module.uuid` → `instance.uuid` → the label stamped on every rendered resource, so it is a new identity for every module and every live instance, not a path redirect with a shim available. The cost is proportional to how much is published when it lands, which makes it the one item where delay is strictly more expensive.

The remaining four — migration breaking pinned consumers, bare-import binding (retired by D5), the convention holding only for OPM-published modules, and a placeholder catalog version producing an unattributable `no matching transformer` — are either retired or restated in the successors.

Drawbacks and alternatives are omitted: they weigh a design that no longer exists. The one alternative worth carrying forward is recorded in the successors — leaving addressing free-form and documenting a best practice was rejected because documentation without enforcement is exactly the state that produced the drift.


## Blast Radius — removing `metadata.version` (D13)

Audited 2026-07-26 across `core`, `library`, `cli`, `opm-operator`, `modules`, and the deployment repositories. Every site below was located by reading the code at the cited line, not inferred. Scope note: `version!` also appears on `#Resource`, `#Trait`, `#Blueprint`, `#ComponentTransformer`, and `#Catalog` — those are *primitive* and *catalog* versions and are **out of scope for D13**, which touches `#Module` only.

### Sites that must change

| Site | Current use | Under D13 |
| --- | --- | --- |
| `core/src/module.cue:22` | `version!: #VersionType` | deleted |
| `core/src/module.cue:23` | `fqn: "\(modulePath)/\(name):\(version)"` | redesigned — shape is **OQ15** |
| `core/src/module.cue:26` | `uuid: SHA1(OPMNamespace, fqn)` | unchanged formula, new input via `fqn` (OQ15) |
| `core/src/module.cue:36` | label `module.opmodel.dev/version: "\(version)"` | **no source in CUE** — drop it, or have the renderer stamp the resolved coordinate from outside the module value |
| `core/src/types.cue:26-28` | `#ModuleFQNType` regex requires a `:semver` tail | rewritten with `fqn` (OQ15) |
| `core/SPEC.md:255, 291-292, 304, 306-307` | §Module Shape, Constraints, and four Rationale paragraphs — including the semver-with-colon rationale and the `SHA1(fqn)` determinism argument | co-update required; **load `core-schema-edit` first**, the pre-commit hook and CI gate enforce it |
| `library/opm/helper/loader/internal/shape/shape.go:66` | `RequiredConcreteFields` includes `metadata.version` | remove from the list |
| `library/opm/helper/synth/instance.go:152` | precondition `Metadata.Version == ""` → error | drop the version clause |
| `library/opm/helper/synth/render.go:62` | `moduleImportPath(m) + "@" + major(m.Metadata.Version)` | read the major from the module's own `cue.mod` path — **a simplification**, see below |
| `library/opm/schema/metadata.go:18,22` | `ModuleMetadata.Version`, `.FQN` | `Version` removed or repurposed to carry the resolved coordinate; `FQN` doc comment updated |
| `library/opm/schema/context.go:17` | `FQN` in the rendered context | follows `fqn` (OQ15) |
| `cli/pkg/module/module.go:35-36` | `ModuleMetadata.Version` | sourced from the resolved coordinate, not metadata |
| `cli/pkg/module/module.go:69-108` | `CanonicalModuleRef()` + `majorVersionTag()` / `ensureVPrefix()` derive path and version from `m.Version` | major comes from the module path; the version half comes from what was resolved |
| `cli/internal/workflow/apply/apply.go:273`, `thineditor.go:112` | `CanonicalModuleRef()` → `spec.module.{path,version}` | writes the coordinate it actually fetched — **this is the fix** for the silent-downgrade defect in `01-problem.md` |
| `cli/internal/workflow/render/log_output.go:40` | logs `result.Module.Version` | cosmetic; logs the resolved coordinate |
| `modules/*/module.cue` ×5 | authored `version:` line in `jellyfin`, `seerr`, `web_app`, `cert_manager`, `metallb` | delete one line each |
| `library/testdata/modules/web_app/`, `cli/tests/e2e/testdata/` | fixtures declaring a module version | regenerate |

`render.go:62` is worth calling out as a *reduction* rather than a cost. It currently parses a semver string to recover a major that CUE already states literally one file away — `modules/jellyfin/cue.mod/module.cue` says `opmodel.dev/modules/jellyfin@v2`. Removing `metadata.version` forces it to read the major from the module path, deleting a parse and a drift vector.

### Sites that do NOT change — verified, not assumed

- **The operator needs no code change.** `opm-operator/api/v1alpha1/common_types.go:36-45` types `ModuleReference` as `{Path, Version}` where `Path` already carries the major (`opmodel.dev/modules/cert_manager@v0`) and `Version` is the pinned tag (`v0.2.1`). `internal/reconcile/moduleinstance.go:249,257,279` consume only those spec fields. **The operator never reads `metadata.version`** — it already works in CUE's model and only needs the CLI to write the coordinate it resolved by.
- **No user-authored CUE breaks.** `core/src/module_context.cue:13-18`'s `#InstanceIdentity` carries `name`, `namespace`, `uuid`, `clusterDomain` — no version. Module authors have never been able to reference the module version from a component, so no template, trait, or resource in any module refers to it.
- **The deployment repositories are clean.** No authored module version in any `.cue` file under them.
- **Primitives are untouched.** `#Resource` / `#Trait` / `#Blueprint` / `#ComponentTransformer` keep their own `version!` and `@semver` FQNs; the matcher keys off those, not off module FQN. Nothing in `library` parses a *module* FQN — `library/opm/module/instance.go:103` returns it as an opaque string.
- **The catalog side is unaffected by D13** and remains governed by OQ13.

### Migration consequences

- **Every module identity changes once.** `fqn` changes shape, so `module.uuid` changes, so `instance.uuid` changes, so the `module-instance.opmodel.dev/uuid` label on every deployed resource changes. This is the same migration D9 already forces by rewriting `modulePath`, so the two should land in one window rather than two — see OQ9, which now owns both.
- **Live instances need an adoption path.** `opm-operator/internal/apply/prune.go:107` skips a delete when the live label disagrees with `Status.InstanceUUID`; it tolerates an *empty* live label but not a *disagreeing* one. So relabeled-in-place instances are safe, and un-migrated ones will silently stop pruning. Either the migration relabels live resources or the operator gains a one-release tolerance for a recorded prior UUID. **This is the one item that makes `opm-operator` an `affects` repo** — no feature code changes, but the adoption path does.
- **Removing a required field from a published schema is a breaking `core` change.** `opmodel.dev/core` is consumed as a published dependency by every module and both catalogs; this is a major-version event for `core`, not an additive one.
- **The `module.opmodel.dev/version` label disappearing is user-visible.** Anyone selecting resources by deployed module version loses that selector unless the renderer re-adds it from the resolved coordinate. Worth deciding explicitly rather than by omission.

### Additional sites from D16 (`modulePath` becomes the full CUE module path)

D16 lands in the same window as D13 — both change `#Module.metadata` and both force the identity migration, so they are one change, not two.

| Site | Current | Under D16 |
| --- | --- | --- |
| `core/src/types.cue:20` | `#ModulePathType` rejects `@` | accepts an optional `@vN` suffix |
| `core/src/types.cue:26-28` | `#ModuleFQNType` requires a `:semver` tail | retired, or redefined as `#ModulePathType` |
| `core/src/module.cue:21` | `modulePath!: #ModulePathType` — value is `opmodel.dev/modules` | value becomes `opmodel.dev/modules/jellyfin@v2` |
| `core/src/module.cue:23` | `fqn` interpolates three fields | `fqn: modulePath` |
| `cli/pkg/module/module.go:74` | `fmt.Sprintf("%s/%s@%s", ModulePath, leaf, majorVersionTag(Version))` | reads `ModulePath` directly; `majorVersionTag` / `ensureVPrefix` lose their caller |
| `modules/*/module.cue` ×5 | `modulePath: "opmodel.dev/modules"` | full path per module, matching that module's own `cue.mod` |
| `library/testdata/`, `cli/tests/e2e/testdata/` | fixture module paths | regenerate |

Two of these are reductions rather than costs. The address composition in `cli/pkg/module/module.go:74` disappears — the declared path *is* the address. And D1's constraint ("the registry path leaf equals `nameSnakeCase`") stops being a relationship between two independently-authored fields and becomes a statement about one, so it is checkable locally; `schemas/target.cue` now expresses it as `leafMatchesName: strings.HasSuffix(registryPath, "/" + nameSnakeCase)`, verified to fail on a mismatched leaf.

The authored path still duplicates `cue.mod/module.cue`'s `module:` line. That duplication is not removed by D16 — it is made *comparable*, since both sides are now the same complete string rather than a fragment reassembled from parts. Checking it is the surviving job of D6's path half.

### Additional sites from D17 (`#Catalog` follows D13 + D16)

| Site | Current | Under D17 |
| --- | --- | --- |
| `core/src/catalog.cue:63` | `version!: #VersionType \| *"0.0.0-dev"` | **kept, default removed** — `version!` stays as the compatibility signal (D19 reversed D17's deletion here); only the `*"0.0.0-dev"` default goes |
| `core/src/catalog.cue:64` | `fqn: "\(modulePath)@\(version)"` | `fqn: modulePath` — the version leaves the key but not the metadata |
| `core/src/catalog.cue:10` | `#CatalogFQNType` requires an `@semver` tail | retired or redefined as `#ModulePathType` |
| `core/src/catalog.cue:70-76` | pattern constraint stamps `modulePath` by concatenation and `version: M.version` onto every `#transformers` entry | stamps the major instead; `modulePath` must **split the major out and re-append it**, since `@v1` now sits mid-string |
| `core/src/transformer.cue:22,26` | `version!` + `@semver` FQN | major-keyed FQN, version supplied by the catalog's major |
| `core/src/types.cue:37-46` | `#FQNType` requires `@semver` | must accept `@vN` for transformers — see **OQ16** for whether resources/traits follow |
| `core/src/types.cue:22-24` | `#MajorVersionType` declared, **used nowhere** | becomes the type its doc comment already claims |
| `catalog_opm/src/identity/identity.cue`, `catalog_kubernetes/`, `catalog_opm_experimental/` | `Version` sentinel + generated `version_override.cue` | `Version` **kept** but becomes a committed concrete SemVer (exp 02 variant B); `ModulePath` gains the `@vN` suffix; the stamping generator and the override file are retired. Post-D19 this is a two-line change per catalog, not a deletion. |
| catalog-internal import lines (`import id "opmodel.dev/catalogs/opm/identity"`) | — | **unchanged.** Intra-module imports omit the major suffix, so `modulePath` gaining `@v1` does not churn any import statement inside a catalog (verified: `catalog_opm/cue.mod/module.cue` is already `opmodel.dev/catalogs/opm@v1` while its own imports carry no suffix). |
| `library/opm/materialize` | the catalog acquire point where D7 placed a version check | nothing to check; the pull records the resolved tag |

- **Every catalog leaf file hard-codes the catalog's module path in an import.** `resources/*.cue` and `transformers/*.cue` each carry `import id "<catalog module path>/identity"`, and CUE offers no relative or short form (measured 2026-07-26: `"identity"` is *builtin package undefined*, `"./identity"` is *relative import paths not allowed*). So D9's owner-scoped migration, or any other path change, rewrites every leaf file in every catalog — not just the identity package. Modules avoid this entirely under D25, which generates into the module's own package and needs no import.

### The largest operational consequence in this entry

Catalog-version skew stops being routine. Today `#Catalog`'s pattern constraint puts the catalog's full version into every transformer FQN, so a module built against `catalog@1.0.0-alpha.2` and a platform subscribed to `catalog@1.1.0` share **no** matcher keys, and the symptom is `no matching transformer` — a message naming neither the catalog nor the version at fault. This has already been observed in the workspace (opm-operator e2e, fixtures at `@v1-alpha` against a platform range at `@v0`).

Under D17 only a **major** bump changes the key space. Patch and minor catalog releases become non-events for matching. `schemas/target.cue` pins the resulting key shape as `_transformerFQNExample` — `opmodel.dev/catalogs/opm/transformers/deployment@v1`, identical across every 1.x release of that catalog.

### What the removal retires

The audit's most useful finding is how much of this enhancement D13 deletes rather than changes. D3's invariant, D6's version half, D11's fleet migration, and D12's `version set` for modules all exist to keep two values equal; with one value they have nothing to do. The publish-side work that survives is the *addressing* half (D1, D4, D8, D9, D10) — which was never the part that failed silently.

## Where it went

- **[0010 — Module and Catalog Identity](../0010/)** — owns the identity change the audit below measures.
- **[0011 — Module and Catalog Publishing](../0011/)** — owns the publish-side and fleet-migration risks.

