# Enhancement 0025: Self-Service Kinds from Published Modules

A platform team binds a published `#Module` to something an application team can instantiate without ever naming a module path or version. The consumer-facing schema is the module's `#config`; every instance is a projected `#ModuleInstance` and renders through the pipeline that already exists. This is the step from OPM as a platform-team tool to OPM as the way an organisation publishes its own platform offerings internally.

See [`config.yaml`](config.yaml) for the metadata contract: it is the sole source of metadata; no parallel metadata table lives in this README.

## Summary

**The platform binds the module; the consumer supplies values.** Today a deployment names its module path and version in the instance. Under this entry a cluster-scoped, platform-owned definition object carries that binding, plus an update policy and optionally platform-bound values, and the consumer's object carries values alone (D1). Instances of the definition are projected to `#ModuleInstance` by a pure CUE function in core (D3, D6), so the kernel, the CLI and the operator compute the same projection and nothing renders twice.

**The consumer-facing schema is `#config`, enforced at the API server.** In the second layer the definition names an API group and kind, and the operator serves a CRD whose schema is the module's `#config` encoded as a structural OpenAPI schema (D2). A module whose `#config` cannot be encoded that way is refused as a definition target. The CRD's version is the module's major (D7), which is what makes "additive within a major" a promise the API server can hold.

**Two layers, the second a projection onto the first** (D4). Binding alone gives platform-owned versioning and a tenancy guardrail with no dynamic CRDs and no new controller. Kinds add typed API objects, `kubectl explain`, admission validation and per-kind RBAC, at the cost of a data-driven controller that owns dynamic kinds. That controller is the first concrete instance of the meta-controller north star 0009 carries as an open question.

**What this does not replace.** Managed-resource controllers (Crossplane providers, ACK, ASO) stay external and appear as leaf resources the render emits (D8). The composition layer, Crossplane's XRD plus Composition plus Claim, is what OPM's typed CUE replaces, and it does so with one namespaced consumer-facing object rather than a composite-and-claim pair (D9).

**The definition's kind name is deliberately undecided** (OQ1). Five candidates are recorded; the draft uses "offering" in lower case as a placeholder noun, never as a kind.

<!--
Do NOT add an implementation-status block here. Whether this design has been
delivered is DERIVED from this entry's `delivery.yaml` log: run `task delivery ID=0025`. A
status block written here is a snapshot that goes stale the moment another change
lands, which is exactly the drift the implementation axis was removed to stop.
-->

## Documents

1. [01-problem.md](01-problem.md): the consumer binds the module coordinate, `#config` has no presence at the API server, and tenancy is all-or-nothing
2. [02-design.md](02-design.md): a platform-owned binding object, a pure projection to `#ModuleInstance`, and a second layer that serves the binding as a typed kind
3. [03-decisions.md](03-decisions.md): D1..D10
4. [04-graduation.md](04-graduation.md): gates that must hold before `draft → accepted`
5. [05-risks.md](05-risks.md): risks, drawbacks, and the composition-layer alternatives not taken
6. [06-operational.md](06-operational.md): operational concerns (PRR-lite)
7. [07-questions.md](07-questions.md): Open Questions OQ1..OQ12

Pure-CUE definitions live in [`schemas/`](schemas/) as compilable files: the core-schema delta (the definition shape, the instance shape and the projection), never as fenced blocks inside markdown.

## Scope

### In scope

**Binding layer (D1, D3, D5, D6)**

- A cluster-scoped, platform-owned definition that binds a module lineage, a major, a release and an update policy, and may carry platform-bound values.
- A way for a `ModuleInstance` to reference a definition instead of naming a module, with the module coordinate resolved from the definition.
- The projection from definition plus instance to `#ModuleInstance` as a core CUE function, readable by the kernel and computable offline by the CLI.
- The self-hosting authoring shape: a definition rendered from a resource contract by a transformer, on the same pattern as transformer registration, beside hand-authored definitions.

**Kind layer (D2, D4, D7, D9)**

- The definition naming an API group and kind, and the operator serving a CRD whose schema is the bound module's `#config` in structural form, versioned by the module's major.
- The refusal of a definition whose module `#config` does not encode to a structural schema.
- One data-driven controller that projects instances of every served kind to `ModuleInstance` and mirrors status back.
- Deletion of a definition refused while instances exist, naming the count.

### Out of scope

- Not a replacement for managed-resource providers, not a second render path, and not a change to what a module author writes.
- **Managed-resource controllers.** Crossplane providers, ACK and ASO stay external; OPM renders their objects as leaf resources (D8). Rebuilding them on the execution half of the kernel is not this entry and not a successor of it.
- **A general meta-controller toolkit.** The projection controller is one bounded instance of the north star 0009 carries as an open question. Extracting a toolkit waits for a second dynamic-kind controller to exist.
- **Composite-and-claim topology.** No cluster-scoped composite object behind a namespaced claim (D9).
- **Routing between several definitions of one kind, or several modules behind one kind.** One definition binds one module lineage. Classes, channels and capability routing are successor material, as they are in 0015.
- **Changing `#Module`.** No authored field is added; the offered module does not know it is offered (D5). A module-declared status schema is OQ5 and may add one later.

## Deviations from Design

None at this stage. Update when implementation lands.

## Cross-References

| Document | Purpose |
| -------- | ------- |
| `enhancements/0015/` | The registration CR pattern this entry's authoring surface reuses (D3, D9), the platform-package regeneration posture on rebinding (D13) |
| `enhancements/0008/` | The CUE-to-CRD encoder in structural mode (D3) the kind layer's CRD generation relies on |
| `enhancements/0010/` | Identity: majors are the only artifact distinction (D1) and instance identity survives a major bump (D41), which is what makes rebinding safe |
| `enhancements/0021/` | `#config` as a module's compatibility surface (D2), the premise under "CRD version equals module major" |
| `enhancements/0009/` | The execution half; its open question on a meta-controller toolkit names the north star the kind layer's controller is the first instance of |
| `enhancements/0016/` | Instance package scaffolding; the consumer-side experience this entry's binding layer removes the module coordinate from |
| `enhancements/0014/` | GitOps export of a live instance; the interaction with projected instances is OQ7 |
| `core/src/module.cue` | `#config` and the comment declaring it OpenAPIv3-compatible, the constraint the kind layer makes load-bearing |
| `core/src/module_instance.cue` | The `#ModuleInstance` shape the projection produces |
| `opm-operator/api/v1alpha1/moduleinstance_types.go` | The operator CR whose module reference the binding layer makes optional |
| https://docs.kratix.io/ | Closest prior art: a Promise installs a CRD from an API schema and fulfils requests through pipelines |
| https://kro.run/ | ResourceGraphDefinition: schema-to-CRD plus a CEL resource graph; the CEL half is what OPM's typed CUE replaces |
| `CONSTITUTION.md` (per target repo) | Core design principles governing changes in each touched repo |

<!--
## Agent Instructions

To create a new enhancement from this template:

1. Pick the next available four-digit id by scanning `enhancements/` for the
   highest existing NNNN directory and incrementing by one. Ids are
   never reused: supersession is recorded via `supersedes` / `superseded_by`
   in `config.yaml`, not by renumbering.
2. Copy the entire `0000/` directory to `enhancements/NNNN/`.
3. Overwrite every `{Capitalised}` placeholder string across the README and
   the seven split documents.
4. Fill `config.yaml` with real values: id matches the directory name, slug
   is short kebab-case, title is human-readable, category names the one
   dominant type of work, affects lists every repo that ships changes,
   created + updated set to today's date.
5. Write `01-problem.md` and `02-design.md` first: full prose. Decisions
   accrete iteratively in `03-decisions.md` as design choices emerge.
6. `05-risks.md` and `06-operational.md` start as scaffolds
   and mature alongside the decision log.
7. If the enhancement adds or changes opmodel.dev/core definitions
   (`config.yaml.core_schema: true`), sketch the delta in
   `schemas/target.cue` (scaffolded by `task new CORE_SCHEMA=true`;
   `examples.cue` + `spec.md` are required before draft → accepted).
   Otherwise there is no `schemas/`; put non-core compilable CUE in
   `contracts/` via `task new:contracts ID=NNNN` if needed.
8. Do not strip these HTML-comment Agent Instructions when copying. They
   are the in-template guidance for the next author/agent.

### Status lifecycle

- **draft**: initial design, actively being written
- **accepted**: design agreed upon, ready for implementation; the resting
  state (delivery is derived from `delivery.yaml`, never stored as a status)
- **rejected**: the idea was not accepted; the entry moves to
  `archive/NNNN/` with `rejected_reason` (`task reject`)
- **superseded**: replaced by a newer enhancement (paired with
  `superseded_by` on this entry and `supersedes` on the replacement); the
  entry moves to `archive/NNNN/` (`task supersede`)

Both terminal states are always archived. A terminal entry never stays in
place, and `task vet` fails one that does.

### Compaction

These documents state what is true *now*. Provenance lives in git and in `config.yaml.history`, the one strictly append-only structure. `DN` and `OQN` numbers are never reused or renumbered (other repos cite them); a number vacated by a merge or retraction keeps a one-line tombstone.

- **draft**: decisions are revised **in place** as part of ordinary editing (fold evidence-backed old positions into *Alternatives considered*); compaction is only the repair path for legacy stacked reversals. Leave Open Question prose alone, it is the active work surface.
- **accepted**: decision bodies are protected: changes append a new `DN` with `**Amends:**`/`**Supersedes:**` relation fields, and the compaction skill is the only body-edit path, weaving those reversals in, collapsing resolved Open Questions to a one-line `Status: resolved-by-DN`. Available at latest until the design is delivered.
- **implemented** (derived from `delivery.yaml`, not a status): closed. Nothing changes, ever.
- **superseded**: narrative documents collapse to pointers at the successor;
  the decision log keeps its numbers and its *Alternatives considered*.
  The pass runs on the archived entry (`archive/NNNN/`).
  `experiments/` and `research/` are never touched.

Run `task compact:plan ID=NNNN` for the candidate list and load the
`enhancement-compaction` skill to act on it. Compaction lands in its own
commit, never folded into a content change.

### Cross-refs to legacy library enhancements

The seven three-digit entries under `library/enhancements/` (001..007) are
frozen historical predecessors. To reference one from a new enhancement, use
the `legacy:NNN` form in `supersedes` / `superseded_by` / `revives`; `depends_on`
cannot target one, because a dependency resolves to a decision heading and the
legacy entries have none, so cite them in prose instead. Once those entries are
deleted, the references become dangling and the validator (future) will flag
them: fix or remove at that point.
-->
