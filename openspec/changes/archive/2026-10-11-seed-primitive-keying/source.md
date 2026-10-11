# Source note: seed-primitive-keying

This is a seed. It records behaviour that ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `primitive-keying`. Full seed (12 requirements). Written 2026-10-11 from `core` at commit `f3b7ecd`.

## Sources

All read at the commit named. The requirement text is rewritten at intent level: no Go symbol, file path or field path. Published CUE definitions are named, as the design allows. Every scenario was also run with `cue` v0.17.1 on a copy of `core` `src/` at `f3b7ecd`, except the classification in requirement 10, which is a statement of the specification and was read in `SPEC.md`.

The repo spec is `core` `openspec/specs/primitive-keying/spec.md` at `f3b7ecd` (12 requirements). The repo spec has one `Source:` line, on the attachment map requirement (owner decision, beta.1 kernel plan walkthrough, 2026-10-03), and no decision tokens. The origin is the decision text of enhancement 0010 (the map names D4, D21, D25, D33, D34 and D44) and the delivery log of the archived change `core-primitive-keying` (named in `explore/T4.1b.md` finding 5; not re-read here).

| Requirement here | Source requirement in the repo's spec | Code read |
| --- | --- | --- |
| A contract key and an implementation key differ | "A contract key and an implementation key are distinct types" | `src/types.cue:205` (contract key), `:222` (implementation key), `:247` (the union) |
| The API version follows the Kubernetes ladder | "A contract key carries an API version following the Kubernetes ladder" | `src/types.cue:122` (the ladder), `:105` (the module major type) |
| The additive-only promise is readable off the level | "The additive-only promise is readable off the API version" | `src/types.cue:140-142` |
| Primitives declare an API version; adapters do not | "The three primitives declare an API version; the adapter does not" | `src/resource.cue:29`, `src/trait.cue:23`, `src/blueprint.cue:37`; the absence on `src/transformer.cue:15-60` and its comment at `:18-33` |
| The catalog version records the build | "The build a definition shipped in is named `catalogVersion`" | `src/resource.cue:37`, `src/trait.cue:29`, `src/blueprint.cue:43`, `src/transformer.cue:52` |
| A member's key is authored, not derived | "A catalog member's FQN is authored, not derived" (first paragraph and first two scenarios) | `src/resource.cue:52`, `src/trait.cue:38`, `src/blueprint.cue:52`, `src/transformer.cue:60`; `SPEC.md:122` |
| The four kinds share no identity shape | "The primitive and adapter identity shapes have no shared parent" | `src/resource.cue:12-52`, `src/trait.cue:11-38`, `src/blueprint.cue:13-52`, `src/transformer.cue:45-60` (four separate shapes); `SPEC.md:221`, `:1189` |
| A primitive's specification is keyed by its name | "`#definitionName` is removed from `#ComponentTransformer`" | `src/resource.cue:169`, `src/trait.cue:124`, `src/blueprint.cue:119`; `src/transformer.cue` holds no such projection |
| A blueprint is classified as a primitive | "`#Blueprint` is classified as a primitive" (first paragraph) | `SPEC.md:28`, `:33`, `:563`; `src/blueprint.cue:37`, `:52` |
| Map keys take the type of their role | "FQN map keys are typed by the role they hold" (first paragraph, first three scenarios) | `src/transformer.cue:94-104`, `:175`; `src/catalog.cue:199` |
| Demand and transformer keys are form-checked | same requirement, last paragraph | `src/transformer.cue:94-104`, `:175`; `SPEC.md:1054` |
| An attachment map key equals its member's key | "An attachment map key equals its member's fqn" | `src/resource.cue:185`, `src/trait.cue:170`, `src/blueprint.cue:127`, `src/component.cue:51-59` |

## Where the repo spec and the code differ

The code wins in each case.

- "The primitive and adapter identity shapes have no shared parent": the repo spec speaks of one shape for the three primitives. The code has none: resource, trait and blueprint each repeat the shape inline, and `SPEC.md:221` says "repeated, not inherited". The seed says each of the four kinds declares its own shape.
- "`#definitionName` is removed from `#ComponentTransformer`": a hidden helper that no consumer reads. The seed states its visible effect: the specification field of a primitive is named by its name, and a transformer has no such field. Run here: `config-maps` accepts `configMaps` and refuses `configmaps` and a second field.
- "A catalog member's FQN is authored, not derived", scenario 3 ("An unset FQN takes its attachment key"): it describes the attachment maps, so it sits in the last requirement here. The same scenario for a catalog's maps is not in this seed.
- "The old field name is gone": the repo spec says the former version field "does not exist". Run here, supplying it is refused with a field-not-allowed error on all four kinds. The seed states the refusal.
- "A primitive without an API version is refused": the repo spec says evaluation reports the field as missing. Run here, `cue vet` without the concrete flag passes (the value is incomplete) and fails with the flag. The seed says incomplete.
- "A contract key and an implementation key are distinct types": the repo spec says no field or map key declared by `core` takes the union. The code differs: the publish gate declares its key field with the union (`src/identity_package.cue:178`), because it checks both kinds of member. The seed limits the sentence to the member, component, transformer and catalog fields and maps. The repo spec is stale here.
- Count: the repo spec has 12 requirements and this seed has 12. The long "FQN map keys" requirement is split in two so that each stays under 500 characters, and the key-segment requirement is left out (below).

## Left out

- The six contract and member maps of `#Catalog`, and the binding of their key to their member's key (repo spec requirements "A catalog member's FQN is authored" second paragraph, "FQN map keys..." second paragraph and its catalog scenario). They belong to the capability `catalog-contracts` (row 14 of the map). The seed here names a catalog's transformer map only, because the repo spec lists it with the implementation keys.
- The publish-time agreement gate between an authored key and the identity package. It belongs to the capability `catalog-member-gate` (row 10). This seed says only that `core` does not check, and that a publish gate does.
- That an authored key carries its kind segment (repo spec "A contract key retains its kind segment"). The seed `catalog-member-gate` states it and its gate enforces it; the key types here do not. Review T4.R11 finding 2.
- That a blueprint declares no fulfilment (second paragraph of "`#Blueprint` is classified as a primitive"). The seed `contract-fulfilment` holds it as "A blueprint declares no fulfilment".
- The primitive's package path and the kind prefix of a catalog. The seed `artifact-identity` holds "A primitive declares a package path" and "One path prefix per catalog member kind".
- The note that a trait's applies-to list stays unchecked against the component's resources (an open question in the repo spec, tracked as `core` issue 99). It is not a behaviour to seed.
- Behaviour a live entry owns. Enhancement 0020 adds promotion between levels (an ordering alpha, beta, bare major, and a field recording the level a contract was promoted from); the sentence that no ordering enters the schema describes the reading of one level only. Enhancement 0021 decides that a transformer serving several levels is declared once per level. Enhancement 0026 changes the count of providers per key to one per resolution. None changes a key form.
- The publish-side additive-only comparison that the API version level gates. It belongs to the capability `catalog-compatibility` (row 29).
- The rationale prose of `core` `SPEC.md` (why the key carries the API version and not the build). The Purpose keeps the one-line reason.

## Where this seed touches the others

- `contract-fulfilment`: both read the resource and the trait, and both state that a blueprint is special. Here a blueprint is a primitive that carries a key; there it carries no fulfilment. No sentence is repeated.
- `artifact-identity`: that seed holds the package path of a primitive, with no major. This seed holds the key. The two meet in the publish gate, which neither holds.
- `platform-registry`: its registry key is a catalog module path with a major, a different key from the contract keys here.
- `single-build-render`: it states the render matches demands by key and refuses a render on colliding keys. This seed states what the key is, not how a render uses it.
- `catalog-contracts`, `catalog-member-gate`, `component-matching` (not written when this seed was): each is a neighbour. The first holds a catalog's contract maps, the second the publish gate, the third the matching labels.

sampled: 2026-10-11 18705155
