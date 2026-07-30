# Operational Concerns — Module and Catalog Identity

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one, even briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Three new diagnostics, all errors rather than metrics, and all of them replacements for something that currently fails opaquely.

- **Address mismatch at read (D11).** A typed error naming both the declared `modulePath` and the coordinate the artifact was fetched by. Emitted from `library/opm/helper/loader/registry/module.go` on the acquire path, from `library/opm/materialize` on the catalog pull, and from the platform-subscription check. The CLI and the operator inherit it from one implementation. Today the equivalent condition surfaces downstream as `module not found` or not at all.
- **No provider for a contract (D24, D28).** An error naming the contract demanded and stating that no catalog subscribed by this platform implements it at any API version. Emitted from the match path, and it is a statement about the **platform** rather than the module — the actor who can fix it is the one who chose the subscriptions. Computed by splitting the API version off the demanded FQN and collecting supplied keys sharing that path-and-name; an empty result is what distinguishes it. Under D28 it fails the render rather than being collected.
- **Wrong API version at match (D24).** The same computation with a non-empty result: the contract is implemented, at an API version this module does not speak. Kept distinct because the remedy differs — migrate the module, versus install a provider.
- **Incompatible contract bodies at match (D27).** The always-unify rung's failure, naming the field the module set and the build the provider was compiled against: "this platform's provider predates that field". This diagnostic has no predecessor — under D13 the condition could not arise, because the keys never met.
- **Missing identity.** Not an OPM error at all: an unfilled identity field surfaces as CUE's own `incomplete value string`, naming the file and line of the declaration. That is deliberate (D6) — absence propagates as absence rather than being translated into an OPM-flavoured message that could be confused with a value.

The `module.opmodel.dev/version` label becomes a real signal for the first time (D9): it now carries the version of the artifact that was actually fetched, so selecting deployed resources by module version starts returning correct results.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Breaking, and a `core` major-version event. `#Module.metadata.version` is removed, `metadata.modulePath` changes both shape and value, `metadata.name` is retyped, `nameSnakeCase` and `#KebabToSnake` are deleted, and `#SubscriptionFilter` grows a field. `opmodel.dev/core` is consumed as a published dependency by every module and every catalog, so nothing built against the current major keeps working.

`#FQNType` **splits** under D24 into `#ContractFQNType` (`@vN`) and `#ImplFQNType` (`@SemVer`). Every FQN value changes and, for the three demand-side kinds, so does the shape: a consumer matching on a SemVer tail must be updated. This is the largest single break in the entry after the module path itself.

There is no compatibility shim and none is proposed: the identity of every artifact changes, so a shim would have to maintain two identities for one artifact, which is the condition this entry exists to remove. The plan is a coordinated window rather than a transition period — see Cross-Repo Coordination.

Downstream impact is uneven and worth stating separately. `opm-operator` needs **no feature code change**: `api/v1alpha1/common_types.go:36-45` already types `ModuleReference` as `{Path with major, Version tag}` and reconcile reads only spec fields, never a module's metadata. No user-authored CUE breaks either — `core/src/module_context.cue:13-18`'s `#InstanceIdentity` carries `name`, `namespace`, `uuid`, `clusterDomain` and never exposed a version, so no module template, trait, or resource can reference one.

## Deprecation

**What gets removed and when? What replaces it?**

Removed in the same release, with no transition window:

| Removed | Replaced by |
| --- | --- |
| `#Module.metadata.version` | the artifact's tag, held by the kernel as a coordinate |
| `#Module.metadata.nameSnakeCase`, `#KebabToSnake` | `name`, authored snake_case (D8) |
| `#ModuleFQNType`, `#CatalogFQNType` | `#ModulePathType` — both artifacts' `fqn` is their module path |
| `#Catalog.metadata.version`'s `*"0.0.0-dev"` default | a committed value, or an open field (D6) |
| `filterVersions`' empty-filter default (`highestStable`) | deleted — there is no filterless subscription under D29 |
| `#SubscriptionFilter` entire, including `range`, `deny`, `allow` and Masterminds constraint solving | deleted — `#Subscription` carries a required scalar `version` (D29, D31) |
| `filter.go` as a file | deleted — what D29 left as a validation pass is one major-agreement check under D31 |
| prerelease inclusion inferred from `range` constraint syntax | deleted — a prerelease is selected by being named (D29) |
| `#definitionName` on `#Module` and `#ComponentTransformer` | deleted — neither has a reader (D33); it stays on `#Resource`, `#Trait`, `#Blueprint` |
| `identity/version_override.cue` and the copy-and-stamp publish task in every catalog repo | a committed `identity.cue` OPM writes into (D5) |
| the `module.opmodel.dev/version` label declaration in `core` | the same label, stamped by the kernel (D9) |
| `cli`'s `majorVersionTag()` / `ensureVPrefix()` and the address composition at `cli/pkg/module/module.go:74` | reading `modulePath` directly |

`#MajorVersionType` (`core/src/types.cue:22-24`) is the inverse case: declared today, used nowhere, and this is the design its doc comment describes.

No deprecation aliases are kept. An artifact published under the old shape is not readable under the new one, which is the point of the coordinated window.

## Rollback

**If this lands and proves bad, what's the rollback story?**

Code rollback is clean; data-plane rollback is not, and that asymmetry is the thing to plan around.

Reverting `core` to the previous major and re-pinning `library`, `cli`, the catalogs, and the module fleet restores the previous behaviour, and previously-published artifacts remain consumable because they were never modified — the migration republishes rather than rewrites. Both majors can coexist in the registry indefinitely.

What does not roll back is the identity label on already-deployed resources. Instances applied under the new identity carry the new `module-instance.opmodel.dev/uuid`; rolling the code back makes the operator compute the old UUID again, and `prune.go:107` will then skip deletes for those resources rather than adopting them. So a rollback after any instance has been reconciled under the new identity needs the same adoption path the forward migration needs (OQ4), run in reverse. Treat the migration as one-way in practice and rehearse it on a non-production cluster first.

## Migration Inventory

The full enumeration is [`research/migration-inventory.md`](research/migration-inventory.md), measured 2026-07-30 against the workspace registry (`localhost:5000`) and the live cluster. It exists because D18 rejected an operator-side tolerance window on the ground that the fleet is *enumerable* — so the enumeration is a gate, not a convenience.

Headline counts: **12 live `ModuleInstance`s** across 10 distinct modules (two modules carry two instances each), **1 `Platform` with 3 subscriptions** — the entire D29/D31 rewrite surface in production is three `range` lines — **39 published module repositories**, **4 catalog repositories**, and **17 non-module artifacts sharing the namespace** (the `library/testdata/modules/web-app` fixture with 11 tags, 10 legacy `…/v1alpha1` paths, `kubernetes/v1`, 4 `releases/*` repositories, and one empty repository).

Four findings from the measurement change what the migration has to do, and each is load-bearing:

1. **The live fleet does not resolve against the registry this workspace publishes to.** `opm-operator-controller-manager` carries no `CUE_REGISTRY` env, no registry argument and no mounted config, so it resolves through CUE's default central registry — and six of the twelve live instances name coordinates absent from `localhost:5000` (`radarr`, `sonarr` and `sabnzbd` have no repository there at all; `jellyfin`, `k8up`, `cert_manager`, `istio_ambient` and `seerr` are published at lower versions than the ones deployed). **The migration spans two registries.** The central one was not reachable at measurement time and remains an open collection task — closing it is a prerequisite to scheduling the migration, not a detail of running it.
2. **`opmodel.dev/catalogs/opm_experimental` and `opmodel.dev/catalogs/opm-experimental` both exist**, both holding a `v1.3.0-alpha`. Under D24 a catalog path is the permanent prefix of every contract FQN, so two spellings are two key spaces and a module built against one cannot match a platform subscribed to the other. This is the failure D1 and D8 exist to prevent, already live in the registry. Canonicalise before migrating, not during.
3. **`opmodel.dev/modules/opm-platform` is in module space and is probably not a module** — which defeats 0011 D5's premise that module, catalog and schema space are distinguishable by path alone. It needs classifying before the namespace move.
4. **The source tree and the registry are neither a subset nor a superset of each other.** `modules/` holds 12 module directories; three of them (`radarr`, `sabnzbd`, `sonarr`) are deployed but unpublished on the dev registry, and two (`cdi`, `snapshot_controller`) have source with no artifact measured anywhere. A published artifact with no source cannot be republished under the new identity; a source with no artifact does not need migrating. Both lists reconcile before step 6 below.

Two smaller items the runbook should not rediscover: `default/podinfo` is the only `@v0` module and the only test artifact in the live fleet, making it the cheapest subject for D18's positive check; and `nzb/radarr` + `nzb/radarr-uhd` (likewise `sonarr`) share a module UUID and differ only by instance name, so they are the pair that exercises `SHA1(module-uuid : name : namespace)` rather than the module path alone.

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Strictly ordered, because each step consumes a published artifact from the one before:

1. **`core`** — publish the new major. Nothing else can move until this tag exists.
2. **`library`** — retarget to the new `core` major; land the D11 read-side checks, D29's collapse of `materialize/filter.go` from resolution to validation, D26's provenance exclusion in D30's denylist form and D27's promise in the match rung, D28's hard failure on an unresolved demand, the D24 diagnostics, and the D9 kernel label stamp. Ships the behaviour every frontend inherits. D26 is the one that cannot be deferred: without it every build skew fails on provenance and contract keys deliver nothing.
3. **`catalog_opm`, `catalog_kubernetes`, `catalog_opm_experimental`** — commit `identity/identity.cue` in the D5 shape, delete the stamping task, republish. Modules cannot migrate until a conforming catalog exists to build against.
4. **`cli`** — retarget to the new `library`; delete the address-composition helpers; write the resolved coordinate into `spec.module.{path,version}`.
5. **`opm-operator`** — retarget to the new `library`. No feature change, but this is where the OQ4 adoption path ships if it lands as operator tolerance rather than as a migration script.
6. **`modules`** — add `identity.cue` per module, drop the authored version, rename hyphenated modules, republish the fleet.
7. **`releases`** — re-pin to the republished module coordinates.

Three coordination notes that are easy to miss. Step 3 must complete before step 6 can be *validated*, because a module carries the primitive definitions its own `cue.mod` resolved — so a module republished against a pre-migration catalog demands keys built from the old `modulePath` and no post-migration platform supplies them. Step 2's filter change is load-bearing for step 3 rather than cosmetic: both workspace catalogs publish only prereleases today, so without D15 a platform subscribed to a republished catalog materializes nothing. And the migration in step 6 must land in the same window as enhancement 0011's namespace move, or every module's identity changes twice.

One thing that does **not** need coordinating: catalog releases after the migration are unilateral, and under D24 this extends to a case D13 could not serve — a **provider** catalog and the catalog defining a contract release independently of each other, which is what makes a platform-fulfilled primitive possible at all. What a catalog release does now touch is which transformer bytes run; that is OQ11's subject, not a coordination requirement.
