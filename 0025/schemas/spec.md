# Specification changes: Self-Service Kinds from Published Modules

<!--
This document pre-drafts the core/SPEC.md co-update that the core slice
will need at implementation time (the `core-schema-edit` skill gates that
co-update via pre-commit hook + CI). It is required, with examples.cue,
from the draft → accepted gate.

Every construct name below is a PLACEHOLDER pending OQ1; the section
headings rename with the decision.
-->

## #Offering (NEW; identifier placeholder, OQ1)

### Definition

The platform-owned binding of a module lineage to something consumers instantiate. It sits beside `#Platform` as a cluster-level, platform-team object: `#Platform` says which catalogs a cluster renders against, and a definition says which module, at which release, the cluster offers under a name. It carries no component, no transformer and no code; it names a published module artifact and states how instances of it are bound.

### Shape

```
#Offering: {
    kind: "Offering"                       // placeholder, OQ1
    metadata: name!: #NameType
    spec: {
        module: {registryPath!, major!, version!}   // version inside major
        updatePolicy: #UpdatePolicy                 // OQ3
        values?: {...}                              // platform-bound values, OQ10
        api?: {group!, kind!, plural?}              // kind layer only
    }
}
```

### Constraints

- `spec.module.version` MUST lie inside `spec.module.major`; a definition whose release is outside its major is refused.
- `spec.module` MUST name a published module artifact; a definition MUST NOT carry transformer code, components or a schema of its own.
- A definition MUST be cluster-scoped and MUST be creatable only by a platform-team identity; where it is rendered output, it reaches the cluster under tenant impersonation and the RBAC gate 0015 D3 rests on applies.
- Where `spec.api` is present, the bound module's `#config` MUST encode to a structural OpenAPI schema; a definition whose module does not is refused, naming the module and the reason.
- Two definitions MUST NOT serve the same `spec.api` group and kind; the second is refused naming the first.
- A rebind (a change to `spec.module.version`) inside the same major MUST keep every existing instance valid; the served schema changes only additively within a major.

### Rationale

- **Why the platform binds the coordinate.** The supported module and release are the platform team's knowledge; giving them one home per cluster per offering is what makes a fleet upgrade one edit and what lets a consumer never learn a module path.
- **Why no schema of its own.** A hand-authored schema drifts from `#config` by construction; the definition names the module and the module's `#config` is the schema.
- **Why cluster-scoped.** A definition is a privilege, not a deployment; a namespaced definition is one a tenant could create.
- **Why the release must sit inside the major.** The served CRD version is the major, and a release from another major would serve a schema under the wrong version.

## #OfferingInstance (NEW; identifier placeholder, OQ1)

### Definition

What a consumer creates in the kind layer: a namespaced object of the served kind, carrying the consumer's values and a status. It is the only consumer-facing object; the projected `#ModuleInstance` behind it is the render's input, not something the consumer authors.

### Shape

```
#OfferingInstance: {
    #offering: #Offering & {spec: api: _}
    apiVersion: "<group>/v<major>"        // derived, D7
    kind:       #offering.spec.api.kind   // derived
    metadata: {name!, namespace!}
    spec:    {...}                        // consumer values; #config minus bound fields, OQ10
    status?: {...}                        // OQ5
}
```

### Constraints

- `apiVersion` MUST be the definition's group followed by `v` and the bound module's major; it is derived and MUST NOT be authored.
- `spec` MUST satisfy the served schema at admission and MUST satisfy the module's `#config` (with bound values unified) at projection; a value that passes admission and fails projection is a render diagnostic on this object.
- An instance MUST be namespaced; there is no cluster-scoped composite behind it.
- `status` MUST at minimum carry conditions mirrored from the projected instance and a reference to it (shape per OQ5).

### Rationale

- **Why the version is the major.** Identity distinguishes majors and nothing finer (0010 D1), `#config` is additive inside a major (0021 D2), and instance identity survives a major bump (0010 D41): the three together are what a CRD version promises.
- **Why one object.** Every object that exists must be explained to a consumer; the composite-and-claim pair has nothing left to hold once `#ModuleInstance` is already namespaced and already owns its resources.

## #Project (NEW; identifier placeholder, OQ1)

### Definition

The pure projection from a definition, an instance and the resolved module to a `#ModuleInstance`. It is the contract every frontend computes: the kernel reads it off a built value, the CLI computes it offline, the operator's controller applies it. No frontend implements the projection in its own language.

### Shape

```
#Project: {
    #offering: #Offering
    #instance: #OfferingInstance
    #module:   #Module & {metadata: {registryPath: <bound>, version: <bound>}}
    out: #ModuleInstance & {
        metadata: {name: #instance.metadata.name, namespace: #instance.metadata.namespace}
        #module: <the resolved module>
        values:  #instance.spec & #offering.spec.values
    }
}
```

### Constraints

- The supplied module MUST be the bound one: its registry path and version MUST equal the definition's; the projection asserts this and never fetches.
- `out.values` MUST be the unification of the definition's bound values with the instance's values; a conflict between the two MUST be a refusal, never an override in either direction.
- `out.metadata.name` and `out.metadata.namespace` MUST be the instance's; the projection MUST NOT rename or relocate.
- The projection MUST be deterministic and side-effect free: the same three inputs yield the same `#ModuleInstance` on every frontend.

### Rationale

- **Why in core.** What is derivable in CUE is derived in CUE, once; three implementations of a small function would drift, and a render that cannot be reproduced offline breaks the reproducibility the platform package already has.
- **Why a conflict refuses.** A bound value is the platform's decision; an override is what the platform bound it to prevent. Unification refusing the conflict is CUE's native answer and needs no policy field.

## #Module, #ModuleInstance (UNCHANGED)

Neither definition changes. `#Module` gains no authored field: the offered module does not know it is offered. `#ModuleInstance` is what the projection produces, unchanged. The operator's `ModuleInstance` CR gains an optional definition reference as an alternative to its module reference; that is operator API surface and lives outside core SPEC.md.
