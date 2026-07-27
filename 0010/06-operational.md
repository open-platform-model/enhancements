# Operational Concerns — Module and Catalog Identity

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts — answer every one, even briefly.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

Three new diagnostics, all errors rather than metrics, and all of them replacements for something that currently fails opaquely.

- **Address mismatch at read (D11).** A typed error naming both the declared `modulePath` and the coordinate the artifact was fetched by. Emitted from `library/opm/helper/loader/registry/module.go` on the acquire path, from `library/opm/materialize` on the catalog pull, and from the platform-subscription check. The CLI and the operator inherit it from one implementation. Today the equivalent condition surfaces downstream as `module not found` or not at all.
- **Uncovered build at match (D13).** An error naming the primitive demanded, the exact build demanded, and the builds the platform actually materialized for that primitive — with the subscription to widen. Emitted from the match path. It replaces `no matching transformer` for the case where a module was authored against a build the platform's subscription does not cover, which under D14's whole-major default means a deliberately narrowed subscription or a build published outside it. Computed by splitting the version off the demanded FQN and collecting supplied keys sharing that path-and-name, so it needs no catalog lookup and cannot misattribute.
- **Absent primitive at match (D13).** The same computation with an empty result: no build supplies that primitive at all — an unsubscribed catalog, a removed primitive, or a typo. Kept distinct from the case above because the remedy differs, and the empty set is what distinguishes them.
- **Missing identity.** Not an OPM error at all: an unfilled identity field surfaces as CUE's own `incomplete value string`, naming the file and line of the declaration. That is deliberate (D6) — absence propagates as absence rather than being translated into an OPM-flavoured message that could be confused with a value.

The `module.opmodel.dev/version` label becomes a real signal for the first time (D9): it now carries the version of the artifact that was actually fetched, so selecting deployed resources by module version starts returning correct results.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Breaking, and a `core` major-version event. `#Module.metadata.version` is removed, `metadata.modulePath` changes both shape and value, `metadata.name` is retyped, `nameSnakeCase` and `#KebabToSnake` are deleted, and `#SubscriptionFilter` grows a field. `opmodel.dev/core` is consumed as a published dependency by every module and every catalog, so nothing built against the current major keeps working.

`#FQNType` is the one type this entry leaves *structurally* alone: D13 keeps its SemVer tail, so only the underscore widening on its path portion applies. Every FQN value still changes, because `modulePath` changes — but the shape a consumer matches against does not.

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
| `filterVersions`' empty-filter default (`highestStable`) | every published build in the subscription key's major (D14) |
| prerelease inclusion inferred from `range` constraint syntax | an explicit `#SubscriptionFilter` flag (D15) |
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

## Cross-Repo Coordination

**Which repos must coordinate, and in what order?**

Strictly ordered, because each step consumes a published artifact from the one before:

1. **`core`** — publish the new major. Nothing else can move until this tag exists.
2. **`library`** — retarget to the new `core` major; land the D11 read-side checks, the D14 selection default and D15 prerelease flag in `materialize/filter.go`, the D13 match diagnostic, and the D9 kernel label stamp. Ships the behaviour every frontend inherits. The filter change is what makes step 3's republished catalogs reachable at all, so it cannot be deferred to a follow-up.
3. **`catalog_opm`, `catalog_kubernetes`, `catalog_opm_experimental`** — commit `identity/identity.cue` in the D5 shape, delete the stamping task, republish. Modules cannot migrate until a conforming catalog exists to build against.
4. **`cli`** — retarget to the new `library`; delete the address-composition helpers; write the resolved coordinate into `spec.module.{path,version}`.
5. **`opm-operator`** — retarget to the new `library`. No feature change, but this is where the OQ4 adoption path ships if it lands as operator tolerance rather than as a migration script.
6. **`modules`** — add `identity.cue` per module, drop the authored version, rename hyphenated modules, republish the fleet.
7. **`releases`** — re-pin to the republished module coordinates.

Three coordination notes that are easy to miss. Step 3 must complete before step 6 can be *validated*, because a module carries the primitive definitions its own `cue.mod` resolved — so a module republished against a pre-migration catalog demands keys built from the old `modulePath` and no post-migration platform supplies them. Step 2's filter change is load-bearing for step 3 rather than cosmetic: both workspace catalogs publish only prereleases today, so without D15 a platform subscribed to a republished catalog materializes nothing. And the migration in step 6 must land in the same window as enhancement 0011's namespace move, or every module's identity changes twice.

One thing that does **not** need coordinating, and is worth stating because the pre-D13 design did need it: catalog releases after the migration are unilateral. Publishing a new build into a subscribed major adds a key space without altering the one any installed module matches, so the fleet does not have to move in step with a catalog release — which is what `01-problem.md`'s second user story asked for.
