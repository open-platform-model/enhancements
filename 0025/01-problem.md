# Problem Statement: Self-Service Kinds from Published Modules

A platform team cannot offer a module to the rest of the organisation without handing every consumer the module's coordinate. The consumer names the module path and version, supplies values, and carries the upgrade. Nothing at the API server knows the module's `#config` exists, and permission to deploy one module is permission to deploy any module. This entry is about closing those three gaps with one object the platform owns.

## Current State

**A deployment binds its own module.** Core's `#ModuleInstance` takes the module as a value and supplies `values` against its `#config`. The operator's `ModuleInstance` CR carries the same two facts as `spec.module` and `spec.values`. Whoever writes the instance decides which module and which version render. Enhancement 0016 scaffolds that package from a published module so the coordinate does not have to be typed by hand, and the consumer still owns it.

**Values are validated at render.** The kernel unifies `#module & {#config: values}` and the failure surfaces as a render diagnostic on the instance. Core's module schema declares `#config` as OpenAPIv3-compatible, with no templating, and nothing enforces the declaration: a `#config` carrying a comprehension renders fine and is simply not encodable as a schema.

**Tenancy is per instance, not per module.** The operator applies rendered output under a per-tenant ServiceAccount (the RBAC gate 0015 D3 rests on). A tenant permitted to create `ModuleInstance` objects may reference any module the registry serves. There is no vocabulary for "this team may deploy the platform's PostgreSQL offering and nothing else".

**Registration exists for transformers, not for modules.** Enhancement 0015 lets a provider module ship a cluster-scoped registration CR that the Platform reconciler accepts or rejects, RBAC-gated because the CR is rendered output applied under tenant impersonation. That pattern binds a catalog's transformers into a cluster. Nothing binds a module into a cluster as something others may instantiate.

## Gap / Pain

**Gap 1: the module coordinate is bound by the consumer.** A platform team maintaining PostgreSQL for forty application teams cannot roll a patch release to the fleet. Each team's instance pins `example.com/modules/postgres` at a version, and each team edits it. The platform team's actual knowledge, which module and which release is the supported one, has no home except documentation.

**Gap 2: `#config` has no presence at the API server.** A consumer cannot `kubectl explain` what a PostgreSQL deployment accepts. A typo in a field name is discovered at render, after the object is stored. Admission policy engines cannot key on the kind because there is no kind: every deployment is a `ModuleInstance` with an opaque `values` map. RBAC cannot distinguish deployments by what they are.

**Gap 3: tenancy is all-or-nothing.** The guardrail an organisation wants is "application teams may create databases, caches and web services from the platform's approved set". OPM's guardrail is "this ServiceAccount may create `ModuleInstance` objects", which admits every module the registry can serve.

## Concrete Example

A platform team publishes `example.com/modules/postgres` on the v1 line. Its `#config` declares `storage`, `replicas` with a default of one, and `storageClass`. The team supports release 1.4.2 and wants every internal PostgreSQL on it, on the `fast-ssd` storage class, without any application team knowing either fact.

```
  today                                        wanted

  team-orders                                  team-orders
    ModuleInstance orders-db                     PostgresDatabase orders-db
      spec.module:  example.com/modules/           spec.storage:  20Gi
                    postgres, version 1.4.2        spec.replicas: 2
      spec.values:  storage 20Gi, replicas 2,
                    storageClass fast-ssd        platform (cluster-scoped, one object)
                                                   definition postgres-database
  team-billing                                       module   example.com/modules/postgres
    ModuleInstance billing-db                        major    1, release 1.4.2
      spec.module:  ... version 1.3.9  <- drift      values   storageClass fast-ssd
      spec.values:  ... storageClass gp2 <- drift    api      platform.example.com / PostgresDatabase
```

Three failures in the left column. The version drifts per team because each team carries it. The storage class drifts because the value is consumer-supplied and there is no way to bind it. And the object on the right, `PostgresDatabase`, cannot exist: there is no kind, so no schema at the API server, no RBAC on it, and no way to say "team-orders may create these".

## User Stories

- As a **platform team operator**, I want to bind one supported release of a module to a name the organisation uses, so that upgrading the fleet is one edit on my side. Today: forty instances carry forty copies of the coordinate.
- As an **application team member**, I want to create a database by filling in the fields the platform documented, validated when I apply it, so that a mistake is refused before anything renders. Today: I copy an instance package, learn the module path, and find field errors in render diagnostics.
- As a **platform product owner**, I want to grant a team the right to create databases and web services from the approved set and nothing else, so that self-service does not mean unrestricted deployment. Today: the grant is on `ModuleInstance`, which admits every module.

## Why Existing Workarounds Fail

**Scaffold the instance package for them.** Enhancement 0016 removes the typing, not the binding. The coordinate still lives in the consumer's package, and the fleet upgrade is still a per-team edit.

**Template `ModuleInstance` objects with GitOps tooling.** A Helm chart or Kustomize overlay that stamps out instances with the platform's coordinate and bound values puts text templating back on top of a typed system. The API server still validates nothing, and the template becomes a second place the platform's knowledge lives.

**Put Crossplane or KRO on top.** An XRD or ResourceGraphDefinition can wrap a `ModuleInstance`, but its schema is hand-written and drifts from the module's `#config`, its composition re-expresses in patches or CEL what the module already states in CUE, and there are then two composition layers to operate.

**Restrict modules with admission policy alone.** A ValidatingAdmissionPolicy can refuse a `ModuleInstance` whose module is not on an allowlist. That closes Gap 3 for one identity and does nothing for Gaps 1 and 2: the consumer still binds the coordinate and the API server still has no schema.
