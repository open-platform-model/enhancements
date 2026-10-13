# 0005: Kubernetes-Native Refocus: Generated Mirror and Composed Abstractions

OPM ships two Kubernetes catalogs, and each keeps its own hand-made copy of the Kubernetes type schemas. The copies drift. This entry generates both from the Kubernetes OpenAPI and stamps each kind with the lifecycle facts the controller needs.

## Why

The raw mirror is written by hand, one transformer at a time. The opinionated catalog vendors strict types from another source. A field one knows and the other does not is a silent divergence.

A CRD such as cert-manager's `Certificate` has no typed path. Apply order is a hardcoded list. An author who outgrows a blueprint cannot set one native field. The project now targets Kubernetes only.

## What Changes

- The Kubernetes OpenAPI is the one source of Kubernetes types. Both catalogs consume generated output. Pointed at a CRD bundle, it emits a typed catalog for that controller.
- One source gives two renderings. The strict one closes the types. The open one leaves every field open for the mirror.
- An abstraction keeps an escape hatch to any native field.
- Each generated kind carries lifecycle metadata: scope, apply phase, readiness and prune policy. The controller reads it.
- A catalog may build on another catalog in pure CUE. Nothing requires it.

## What this is not

- Not a change to core. The transformation model stays single-pass.
- Not multi-phase lowering. That needs its own entry, and only when a real case needs it.
- Not support for other platforms.
- Not a reconcile engine. The controller consumes the metadata.

## Example

```cue
// A sketch: generate a typed catalog from a CRD bundle.
source: {kind: "crd", refs: ["cert-manager.crds.yaml"]}
projection: "open"
```

A typed `Certificate` resource drops out, with lifecycle metadata.

## Capabilities

- **New:** none. The entry states a posture and no requirement, so it has no delta specs.

## Impact

- **Module authors** keep the blueprint and override any native field. Schemas may tighten or rename.
- **Catalog authors** patch the generator or its inputs, not the generated CUE.
- **Four repos** change: catalog_opm, library, opm-controller and opmodel.dev.

## Open questions

- Blocking: Does the generator emit two modules or one module with both renderings per kind? Does the strict side reuse `cue.dev/x/k8s.io@v0` or is it generated in-house, for consistency with the open side and with CRDs?
- Blocking: Where does the generation tooling live (a new repo, the mirror catalog's repo or library), and in which language (Go, or CUE's own `cue import`)?
- Blocking: How is the Kubernetes version axis represented? An object has an API version (`apps/v1`), and the cluster minor (1.32 or 1.33) adds and removes kinds and fields. Likely: encode the minor in the catalog version and let the platform's subscription filter pin it. Confirm the release cadence and how several minors coexist.
- Not blocking: How is per-kind readiness curated and kept current? The OpenAPI has no readiness. Decide the curated source (a table keyed by kind), the generic fallback (`status.conditions[type=Ready]`) and who owns updates.
- Blocking: How does an override unify with the defaults the sugar sets? The projected fields must be defaults so an override wins, not conflicts. Decide between a patch unified on top (needs defaulted projection) and an explicit `overrides` field merged into the output.
- Not blocking: What first case would trigger the core follow-on for multi-phase lowering? An example: an abstraction whose emitted resource must reference another emitted resource's rendered, prefixed name. A concrete case becomes the problem statement of that entry.
