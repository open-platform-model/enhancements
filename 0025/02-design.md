# Design: Self-Service Kinds from Published Modules

One platform-owned object binds a module lineage, a release and an update policy. Instances of it carry values alone and are projected to `#ModuleInstance` by a pure CUE function. A second layer serves the same binding as a typed Kubernetes kind whose schema is the module's `#config`. Trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- **The platform binds the module; the consumer never names a module path or version.** The module coordinate has exactly one home per cluster per offering, and the fleet upgrade is one edit there.
- **The consumer-facing schema is the module's `#config`, and nothing else.** No second schema is authored by hand; drift between what the module accepts and what the consumer is offered is structurally impossible.
- **One render path.** An instance of an offering is a `#ModuleInstance` and renders exactly as one authored by hand would. Nothing is composed twice.
- **The projection is pure and offline-computable.** Kernel, CLI and operator derive the same `#ModuleInstance` from the same two inputs, so a render can be reproduced with no cluster.
- **Validation and authorisation move to the API server where a kind exists.** Admission refuses a bad instance before it is stored; RBAC distinguishes offerings by kind.
- **Rebinding is a deliberate act with a stated policy.** Changing the bound release re-renders every instance; the definition says whether that happens automatically or on request, and the blast radius is named, never silent.
- **The offered module does not know it is offered.** `#Module` gains no authored field. The same published artifact serves hand-written instances and offering-projected ones.

## Non-Goals

- **Managed-resource controllers.** Crossplane providers, ACK, ASO and their kind stay external. OPM renders their objects as leaf resources; it does not reconcile external APIs (D8).
- **A composite-and-claim topology.** No cluster-scoped composite behind a namespaced claim (D9).
- **A general meta-controller toolkit.** The controller this entry needs is one bounded, data-driven projection loop. It is the first concrete instance of the north star 0009 records as an open question, not the toolkit.
- **Routing.** One definition binds one module lineage; several definitions may bind the same lineage under different names. Classes, channels and capability routing wait for a real instance, as they do in 0015.
- **Module-hosted or CR-hosted transformer code.** The definition names a published module artifact; code never rides the CR. Same posture as 0015 D10.
- **Changing what a module author writes.** `#config` was already declared OpenAPIv3-compatible; this entry enforces the declaration only for modules bound as offerings.

## High-Level Approach

Two layers. The first is a binding; the second serves the binding as a kind and is a pure projection onto the first (D4).

```
  layer 2: kinds                  layer 1: binding                      render (unchanged)

  PostgresDatabase orders-db      definition postgres-database          #ModuleInstance
    spec: {storage, replicas}       module: postgres, major 1, 1.4.2      metadata: orders-db / team-orders
          |                         values: {storageClass: fast-ssd}      #module: postgres 1.4.2
          | project (pure CUE)      updatePolicy: manual                  values: bound & consumer
          v                         api: platform.example.com/PostgresDatabase   |
  ModuleInstance orders-db  ------> offeringRef: postgres-database  ----------->  components -> transformers -> resources
    values: {storage, replicas}
```

**Layer 1: binding (D1, D3, D5, D6).** A cluster-scoped, platform-owned definition carries the module's major-free registry path, its major, the bound release, an update policy, and optionally values the platform fixes. A `ModuleInstance` may reference a definition instead of naming a module; the operator resolves the coordinate from the definition and renders as usual. The projection from definition plus instance to `#ModuleInstance` is a CUE function in core: bound values and consumer values unify, so a consumer cannot override a bound value, and the result is a complete `#ModuleInstance` the kernel already knows how to render. A tenant guardrail refuses instances that name a module directly (OQ8); with the guardrail, "may create ModuleInstance objects" becomes "may instantiate offerings".

The definition is authored by the platform, never by the offered module (D5). Two authoring shapes are equally valid: a hand-written CR, or a resource contract in catalog_opm rendered by a transformer, so a platform product module can ship a bundle of definitions among its rendered resources under the RBAC gate 0015 D3 already enforces. A module that emitted its own definition would have to be deployed before anyone could instantiate it, which inverts the lifecycle: a provider runs once per cluster, an offered module runs N times.

**Layer 2: kinds (D2, D7, D9).** The definition additionally names an API group and kind. The operator encodes the bound module's `#config` as a structural OpenAPI schema and serves a CRD whose version is the module's major (D7). One data-driven controller watches every served kind, projects each instance to a `ModuleInstance` carrying the definition reference, and mirrors status back. The consumer-facing object is namespaced and is the only one the consumer sees (D9); the projected `ModuleInstance` is the render's input and the operator's existing reconcile surface, unchanged.

A definition whose module `#config` cannot be encoded as a structural schema is refused (D2). This is the one place a module author's choice is enforced: core has always said `#config` is OpenAPIv3-compatible, and offering the module as a kind is where the promise starts to matter.

**Why the layers are ordered this way.** Layer 1 delivers platform-owned versioning and the tenancy guardrail with no dynamic CRDs and no new controller: a CR, a field, an admission rule. Layer 2 is where dynamic-kind cost lives (CRD lifecycle, dynamic informers, status mirroring) and is exactly the meta-controller shape 0009 leaves open. Making layer 2 a projection onto layer 1 means the projection function is written once, the render path never learns about kinds, and the controller has one job.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue). The definition kind's name is undecided (OQ1); the CUE identifiers below are placeholders that rename with the decision.

- **The definition** (placeholder `#Offering`): `spec.module` binds `registryPath`, `major` and `version`, with the version's major asserted equal to the bound major. `spec.updatePolicy` states what a rebinding does to live instances (vocabulary and default per OQ3). `spec.values` carries platform-bound values (OQ10). `spec.api` names the group and kind for the second layer and is absent in a binding-only definition.
- **An instance of a served kind** (placeholder `#OfferingInstance`): `apiVersion` derives as the definition's group plus `v` plus the module major; `kind` is the definition's; `spec` is the consumer's values; `status` is OQ5.
- **The projection** (placeholder `#Project`): definition plus instance plus the resolved `#Module` yields a `#ModuleInstance` whose name and namespace are the instance's and whose values are the unification of bound and consumer values. A conflict between the two is a refusal, not an override.
- **`#Module` and `#ModuleInstance`**: unchanged in core. The operator's `ModuleInstance` CR gains an optional definition reference as an alternative to its module reference; that CR field is operator surface, not core.

## Affected Surfaces

**core.** Three new definitions: the definition shape, the served-instance shape and the projection. The projection is the contract every frontend computes; a consumer may rely on the same inputs producing the same `#ModuleInstance` everywhere. `#Module` and `#ModuleInstance` do not change. SPEC.md gains the three constructs; a `core-schema-edit` co-update.

**library.** The kernel reads the projection off a built value and renders the result through the existing render path. It gains the ability to answer "does this module's `#config` encode to a structural schema" so the refusal in D2 has one implementation the CLI and the operator share. Kernel neutrality holds: no Kubernetes client, no CRD install; the encoder is a pure function over CUE.

**opm-operator.** A cluster-scoped definition CRD, accepted or rejected by a reconciler on the pattern 0015 D3 establishes (claim, verify, activate, refuse deletion while dependents exist). The `ModuleInstance` CR's module reference becomes an alternative to a definition reference. In the second layer: CRD generation from the bound module's `#config`, a data-driven controller over every served kind, and the tenant guardrail (OQ8). The platform's RBAC vocabulary gains "may create instances of kind X".

**catalog (catalog_opm).** A resource contract for the definition and the transformer that renders it, so a platform product module can ship definitions as rendered output (D5). Same self-hosting shape as 0015 D9's registration pair.

**cli.** Compute the projection offline for a definition and an instance and render the result with no cluster, the same reproducibility 0015 D6 gives for the platform package. Report whether a module's `#config` is a valid offering target before it is bound. A pre-flight over a cluster's definitions: bound release not found, `#config` not structural, kind collision across definitions.

## Before / After

**Rolling a patch release.** Before: forty instances carry `version: 1.3.9`; the platform team files forty edits or waits. After: the definition's bound release moves from 1.3.9 to 1.4.2 and every instance re-renders under the update policy the definition states (automatic) or when each instance is next touched (manual, OQ3).

**Creating a database.** Before: copy an instance package, learn `example.com/modules/postgres`, guess `storageClass`, apply, read the render diagnostic. After: `kubectl explain postgresdatabases.platform.example.com.spec` lists `storage`, `replicas` with its default and nothing about storage class, because the platform bound it. A misspelt field is refused at admission.

**Granting self-service.** Before: a Role on `moduleinstances` admits every module in the registry. After: a Role on `postgresdatabases` in the team's namespace, and the guardrail refuses a `ModuleInstance` that names a module directly under a tenant identity.

**Reproducing a render offline.** Before and after: the same. The projection is a CUE function; the CLI computes it from the definition and the instance and renders the `#ModuleInstance` it yields, byte-identical to the operator's.
