# Risks, Drawbacks, Alternatives: Self-Service Kinds from Published Modules

Risks describe what could go wrong. Drawbacks describe what definitely costs something. Alternatives describe the high-level paths not taken; per-decision detail lives in `03-decisions.md`.

## Risks and Mitigations

- **Rebinding is a fleet-wide re-render.** Moving a definition's bound release re-renders every instance of it. Under an automatic policy that is a fleet upgrade triggered by one edit; a bad release reaches forty databases at once. **Mitigation:** the update policy is on the definition and its default is decided (OQ3); the projected instances carry the same rollout controls a hand-authored `ModuleInstance` has; the blast radius is the same one 0015 D13 accepts for a registration change and is named in status, never silent.
- **Dynamic CRD lifecycle in the operator.** Serving a CRD per definition means installing, updating and removing CRDs at runtime, with instances that outlive a definition and storage versions that cannot change without conversion. **Mitigation:** one served version per kind by default (OQ4), deletion refused while instances exist naming the count (the finalizer posture 0015 D3 takes), and the CRD regenerated only on rebind, where the additive-within-a-major rule (D7) keeps stored instances valid.
- **The structural-schema rule surprises module authors.** A module whose `#config` uses a comprehension or an open `_` renders fine today and is refused as an offering target under D2. **Mitigation:** the refusal is at definition acceptance and names the module and the reason; plain `ModuleInstance` use is unaffected; the CLI reports whether a module is a valid target before it is bound; a publish-side gate is OQ6.
- **The guardrail is bypassed by a direct `ModuleInstance`.** A tenant that may create `ModuleInstance` objects can name a module directly and skip the offering. **Mitigation:** OQ8's admission rule refuses a direct module reference under a tenant identity; in the kind layer, tenants are granted the served kinds and not `ModuleInstance` at all.
- **Two definitions serve one kind.** Two platform-team definitions naming the same group and kind would fight over one CRD. **Mitigation:** acceptance refuses the second naming the first, the same exactly-one posture 0015 D2 keeps for providers; the CLI pre-flight reports the collision before apply.

## Drawbacks

- **A second way to deploy a module.** Hand-authored `ModuleInstance` and offering-projected instance coexist. Documentation and the CLI must say when each applies; the projection being pure keeps the answer "the same render, different binding".
- **A CRD and a dynamic informer per offering.** An organisation with fifty offerings has fifty served kinds. That is the cost Crossplane and KRO pay for the same benefit; it is accepted, and the binding layer exists for platforms that do not want it.
- **A new noun in OPM's vocabulary.** Whatever OQ1 decides, it is one more thing for a reader to learn beside Module, Instance, Catalog and Platform. The alternative, overloading an existing word, is worse (OQ1 records why).

## Alternatives

- **One generic kind with schema-validating admission instead of a CRD per offering.** A single `Instance` kind whose admission webhook validates `spec` against the referenced definition's `#config`. **Why not:** loses `kubectl explain`, per-kind RBAC and typed clients, which are most of what the kind layer exists to give.
- **Crossplane's XRD plus Composition wrapping `ModuleInstance`.** **Why not:** the XRD schema is hand-authored and drifts from `#config`; the composition re-expresses in patches what `#components` already states; two composition layers to operate.
- **KRO's ResourceGraphDefinition.** Schema-to-CRD plus a resource graph, the closest shape to the kind layer. **Why not:** its graph is CEL over Kubernetes objects; OPM's graph is CUE over a module, already typed and already rendered. Worth comparing at promotion (graduation gate).
- **Kratix's Promise.** A Promise installs a CRD from an API schema and fulfils requests through pipeline containers; the closest prior art to the whole design including the meta-controller. **Why not:** the fulfilment model is imperative pipelines, not typed composition; OPM's projection is a pure function. Worth reading for what it does about definition lifecycle and multi-cluster scheduling, which this entry does not address.
- **Templated `ModuleInstance` objects from GitOps tooling.** **Why not:** text templating over a typed system, no admission validation, and a second home for the platform's knowledge.
