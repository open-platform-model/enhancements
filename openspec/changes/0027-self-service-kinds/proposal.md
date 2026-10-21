# 0027: Self-Service Kinds from Published Modules

A platform team binds a published module to a name once, in one object, and serves it as a Kubernetes kind. A consumer supplies values only.

## Why

A team that wants a database types the module path and the exact release into its own instance. Forty teams carry forty copies, so a patch is forty edits. The API server knows nothing of the module's configuration schema, so a typo shows up at render. Permission to create an instance admits every module.

## What Changes

- A platform-owned, cluster-wide definition binds one module lineage, one major, one release and an update policy. It may pin values.
- A consumer instantiates the definition with values alone. Platform and consumer values merge, and a clash is refused.
- A definition may also name an API group and kind. The controller then serves a kind with the module's own configuration schema.
- A module may declare what it is when offered, with a catalog trait. Only the platform writes the definition.
- Every instance projects to an ordinary module instance and renders on today's path.

## What this is not

- Not a replacement for Crossplane providers, ACK or ASO. They stay external, and OPM renders their objects as leaf resources.
- Not a composite-and-claim pair, and not a second render path.
- Not a general meta-controller toolkit, and not routing between definitions.
- Not the module extension point. That is enhancement 0025.

## Example

```text
platform:  definition postgres-database   module postgres, major 1, release 1.4.2, storageClass fast-ssd
consumer:  PostgresDatabase orders-db     storage 20Gi, replicas 2
```

The platform moves the release to 1.4.3, and every instance re-renders under the update policy. The kind name is an example.

## Capabilities

- **New:** `module-binding`, `served-kinds`, `instance-projection`, `definition-authoring`, `offering-declaration`

## Impact

- **Platform teams** write one definition per offered module and grant teams the served kinds.
- **Module authors** keep the configuration schema encodable if the platform serves the module.
- **Five repos** change: core, library, catalog_opm, cli and opm-controller. The change is additive.

## Open questions

- Blocking: What is the kind name of the definition object? Candidates are `Offering`, `Capability`, `Facade`, `Promise` and `Form`. A name with Catalog, Blueprint, Template, Release, Claim, Service, Package or Class in it collides with an OPM word, a Kubernetes kind or a rejected vocabulary. The text says "definition" and uses "offering" as a placeholder.
- Blocking: Does the binding layer ship as a product on its own, or only as a slice of the kind layer? Alone, it gives platform-owned versioning and the tenant guardrail with no dynamic CRDs, at the cost of a documented second way to write an instance. As a slice, the consumer surface is the served kinds only. The answer decides scope and bears on the name.
- Blocking: What is the update-policy vocabulary, its default, and what does each value do to live instances? Candidates are `automatic` and `manual`. A channel model is a successor. A silent re-route is the failure to avoid, which argues for `manual` as the default. The nearest precedent is the regeneration posture of enhancement 0015.
- Blocking: May a definition serve two module majors at once? Two CRD versions with different schemas and no conversion would relabel objects wrongly. The candidate is one served major per definition. A major upgrade is then a new definition, or a rebind that is refused while instances of the old major exist.
- Blocking: What is the status contract of a served-kind instance? The minimum is conditions mirrored from the projected instance and a reference to it. A module may later declare more, such as an endpoint or a credential Secret name, on the offering trait. The candidate is the fixed minimum now and a declared status schema later.
- Not blocking: Is the structural schema also gated at publish time? Refusal at acceptance is the floor. A publish gate cannot be the only check, because older modules and modules never offered must keep publishing. A module that declares an offering and does not encode is worth a refusal. An undeclared one is at most a warning.
- Blocking: Is the projected module instance a real object in the cluster, or in memory only? A real object, owned by the served-kind instance, reuses every reconcile, status and inventory path and gives enhancement 0014 something to export. The cost is one more object and a status in two places. The candidate is the real object. The answer decides ownership, deletion cascade and the CLI-to-controller handoff.
- Blocking: What is the tenant guardrail, and how does tenancy map through the projection? First, a direct module reference under a tenant identity is refused, by an admission policy keyed on the identity or by RBAC that grants served kinds and never module instances. Second, the projected instance renders under the namespace's tenant ServiceAccount, so a served kind grants no new privilege.
- Not blocking: Do config defaults become CRD defaults? The alternative keeps defaulting in the render, where enhancement 0017 places it. Emitting defaults means a default change on rebind rewrites the effective values of stored objects. Answer it against 0017.
- Blocking: May a definition bind values the consumer never sees, and is the served schema the configuration schema minus the bound fields? The candidate is yes. The alternative exposes all fields and refuses overrides at admission, which is simpler to generate and worse to use.
- Not blocking: What happens to instances when a definition is deleted? The candidate is a finalizer that refuses deletion and names the instance count. The alternative orphans the instances as plain module instances, as an explicit migration action.
- Not blocking: Who installs the served CRD, the controller at runtime or rendered output the platform applies? Runtime installation keeps the definition self-contained. Rendered output puts the CRD under GitOps and the RBAC gate, with a two-step apply.
- Not blocking: May the offering trait carry suggested bound values for the definition? The candidate is suggest-only. The CLI copies them into the draft, and the definition carries them explicitly or not at all. It interacts with the question on bound values.
- Not blocking: How do a module and an offering carry presentation, such as title, icon, field labels, help and presets, and which part does this entry own? Candidates are an optional presentation block on the definition, an author card in the module file, form hints as field attributes, and a publisher's index. All are optional and inert. Measured: cards of 471 to 585 bytes survive `cue mod tidy` on 20 of 20 fleet modules, and a CRD that carries a UI extension key is refused by strict decoding, so presentation stays out of the served schema. The measurements are in `evidence/experiments/06-presentation-metadata/`.
- Blocking: Do the served CRD, the CLI pre-flight and every form agree on what is valid, binding-only definitions included? The candidate is one structural encoding of the configuration schema minus the bound fields, reported by digest in the definition status. Offline structural validation agreed with a live API server on 403 of 403 verdicts.
- Blocking: How is a secret field encoded in the served structural schema? Without an answer every module that declares a secret is refused, because the secret type is a struct union. The measured candidate recognises the field by core's hidden tag and serves one fixed object constrained by `oneOf`. It agreed with CUE on 55 of 55 fixtures. A CEL variant has clearer messages but fails admission on unbounded lists of secrets. The value field carries no bound, so the API server never echoes plaintext.
- Blocking: How are struct unions in the configuration schema served, and which are refused? The measured candidate serves discriminated and presence-discriminated unions, reduces struct defaults to their default arm, requires the discriminator in the served schema, and refuses five shapes by name. With defaults reduced, 20 of 20 real modules encode. The fleet has no true struct union today.
- Blocking: Is a defaulted field required in the served schema, and what happens to computed fields? The measured candidate marks a field required only when it is marked required or has no default and is neither concrete nor computed. It accepted every module's own debug values, 20 of 20, where marking computed fields required refused 19 of 20. Serving a computed field as a one-value enum refuses valid values. Two other treatments are unmeasured.
- Blocking: How is the admission promise kept when the structural schema is a lossy subset of the configuration schema? A kubectl or GitOps create can pass admission with values CUE refuses at render. Candidates are a validating webhook that runs CUE through the projection, or a narrower promise: refused at admission where the schema can say so, else at render as a status condition naming the path.
- Not blocking: May a module declare outputs that served-kind status reports, such as endpoints and credential Secret names? The candidate is an optional outputs schema on the offering trait, never secret data. It touches enhancement 0025's trait, so it waits on that entry's fulfilment question.
- Blocking: What may a UI create on a tenant's behalf? The candidate is an instance of a served kind only, created as the user after a server-side dry-run. A module instance that names a module is the bypass the guardrail refuses.
- Blocking: Is a binding-only definition orderable from a UI? A binding-only definition has no served kind, so an order would be a definition-referencing module instance. The candidate is orderable only if the guardrail is an admission policy. It waits on the scope and guardrail questions.
- Blocking: Under which identity does an in-cluster UI write an order? A create under the UI's own ServiceAccount bypasses the user's RBAC and the guardrail. Candidates are token passthrough, export only, or impersonation confined to a separate write component. The candidate is passthrough where the API server trusts the issuer, else export.
- Not blocking: How are order and validation errors reported per field? The candidate keys errors by the configuration path, mapped from CUE's diagnostic path and from the API server's dry-run causes. A disjunction's per-arm errors collapse into one. Values at declared secret paths are always redacted.
- Not blocking: May a platform disable the literal-value secret arm for an offering? A literal in a served-kind instance is plaintext at rest in etcd. The candidate is an optional definition field that makes the served schema drop the literal arm, so kubectl creates are refused too. It interacts with "the served schema is the configuration schema and nothing else".
- Not blocking: What may prefill an order? The candidate order is a preset the platform defines, else the module's initial values with every bound path removed and the rest checked through the projection, else nothing. The author's debug values are never a prefill.
