# Research findings — CUE as single source of truth for OPM CRDs

**Snapshot date:** 2026-06-25. Gathered via a `/deep-research` fan-out (web search → source fetch → 3-vote adversarial verification) plus direct inspection of the installed CUE toolchain. Verified toolchain: `cuelang.org/go@v0.17.0-alpha.1` (Go module cache) and the `cue` binary `v0.17.0-alpha.3` (CUE language version v0.17.0) — the same line OPM runs.

Confidence tags: **[verified]** = checked verbatim against a primary source (official CUE docs, the cuelang/go source, Kubernetes apiextensions docs, or the installed binary); **[assessed]** = a defensible inference from verified facts, not itself a direct quote.

This dossier is read-only synthesis. Design recommendations derived from it live in `../02-design.md` and `../03-decisions.md`.

## 1. CUE → CRD schema body

- **[verified]** `cuelang.org/go/encoding/openapi` self-describes as "mapping CUE to and from OpenAPI **v3.0.0** … handles OpenAPI **Schema components only**." No OpenAPI 3.1. Source: `pkg.go.dev/cuelang.org/go/encoding/openapi`, `encoding/openapi/doc.go`.
- **[verified]** The package ships `encoding/openapi/crd.go`: *"This file contains functionality for structural schema, a subset of OpenAPI used for CRDs"* (cites the k8s 2019 structural-schema blog). It implements an unexported core builder (`newCoreBuilder`, `coreSchema`, `buildCore`) that normalises CUE to the structural subset. Verified directly in the installed `@v0.17.0-alpha.1/encoding/openapi/crd.go`.
- **[verified]** `Config.ExpandReferences=true` "enables the 'Structural OpenAPI' form required by CRDs targeting Kubernetes version 1.15 and later." Source: `cuelang.org/docs/concept/how-cue-works-with-openapi/`; corroborated by the `ExpandReferences` doc in `openapi.go` ("replaces references with actual objects when generating OpenAPI Schema").
- **[assessed]** So CUE can emit the **`openAPIV3Schema` body** in structural form near-directly — but only the body. The encoder emits **no** CRD wrapper (apiVersion/kind/metadata/names/scope/versions), **no** status subresource, **no** printer columns/shortNames, and **no** `x-kubernetes-*` vendor extensions or CEL. Those are CRD-manifest-level concerns above the schema body.
- **[verified]** `ExpandReferences` cannot expand self-referential/recursive CUE values; structural schemas forbid `$ref` anyway. Broader OpenAPI support is tracked in cue-lang/cue#3133 ("encoding/openapi: full support for OpenAPI"), still open.

## 2. CUE → Go types

- **[verified]** `cue exp gengotypes` generates Go type definitions (structs with json tags) from exported CUE definitions — the **CUE→Go** direction. Introduced in CUE **v0.12.0** (2025-01-30); still under the experimental `exp` namespace in v0.17 ("WARNING: THIS COMMAND IS EXPERIMENTAL … may be changed or removed at any time"). Output written to `cue_types_${pkgname}_gen.go`; honours `@go(...)` attributes. Sources: `cuelang.org/docs/howto/generate-go-types-from-cue-definitions/`, `cue help exp gengotypes`, and a direct run on the installed binary.
- **[verified]** Direct run: `#Foo:{name:string, age?:int}` emits `type Foo struct { Name string \`json:"name"\`; Age int64 \`json:"age,omitempty"\` }`.
- **[verified]** **Disjunctions collapse:** a CUE field like `string | int` becomes Go `any` (gengotypes help text). Enums-as-string-disjunctions therefore lose their constraint in the Go type (the constraint survives only in the CUE-derived CRD schema).
- **[verified]** `gengotypes` emits **no** deepcopy methods and knows nothing about kubebuilder markers.
- **[verified]** `cuelang.org/go/encoding/gocode` is a different package: it "defines functions for extracting CUE definitions from Go code and generating Go code from CUE values," but the generated Go is **validation/completion functions, not struct definitions** — its Caveats explicitly list "Currently not supported: option to generate Go structs." Not usable for API types.
- **[verified]** `cue get go` is the **reverse** direction (Go→CUE): "converts Go types into CUE definitions," writing `*_go_gen.cue` (e.g. `cue get go k8s.io/api/core/v1`). Used in the wild by `stefanprodan/kubernetes-cue-schema`.

## 3. deepcopy / runtime.Object

- **[verified]** deepcopy (`DeepCopy`, `DeepCopyInto`, `DeepCopyObject`) is produced by **controller-gen's Object generator** (`sigs.k8s.io/controller-tools/pkg/deepcopy`, ported from k8s gengo deepcopy-gen). It is "scoped specifically to runtime.Object." Source: `book.kubebuilder.io/reference/controller-gen.html` + the controller-tools GoDoc.
- **[verified]** controller-gen's deepcopy/object generator consumes **Go source** — there is no CUE input path. `runtime.Object` emission requires the `+kubebuilder:object:root=true` / `+k8s:deepcopy-gen:interfaces` marker on the Go type.
- **[assessed]** Therefore even with CUE as source of truth, the pipeline must **materialise Go structs** and run controller-gen `object` on them to satisfy `runtime.Object`. deepcopy stays controller-gen's job.

## 4. CEL / x-kubernetes-validations

- **[verified]** The CUE maintainers (cue-lang/cue#2691) call CEL↔CUE *"a big lift"* and note "CEL validation will be incompatible with CUE in some cases, because it allows validating an updated Kubernetes object by comparing it to its existing values" — i.e. CEL `oldSelf` transition rules, which a stateless constraint language like CUE cannot express.
- **[assessed]** CEL rules (OPM has one today: the Platform `metadata.name == 'cluster'` singleton rule) must be carried as **verbatim strings** and injected into the CRD, never derived from or translated to CUE.

## 5. The reverse direction is the mature, supported one

- **[verified]** `cue get crd` exists in v0.17: "convert Kubernetes CRDs to packages in the current module" — the **CRD YAML → CUE** direction. Backed by `encoding/jsonschema/crd.go` `ExtractCRDs` and the `VersionKubernetesCRD` / `VersionKubernetesAPI` enum constants. (This closed cue-lang/cue#2691, which had requested a `cue import crd`.) Verified in the installed source (`cmd/cue/cmd/get_crd.go`) and binary (`cue get crd --help`).
- **[verified]** `encoding/jsonschema.Generate` (CUE→JSON Schema) currently supports **only Draft 2020-12** (runtime-enforced: `if cfg.Version != VersionDraft2020_12 { return error }`). The Kubernetes versions are decode-only so far.
- **[verified]** **timoni** `timoni mod vendor crds` reads a CRD bundle and emits CUE under `cue.mod/gen/` by API group, injecting apiVersion/kind — CRD→CUE. **Holos** delegates CRD-to-CUE conversion to timoni — same direction.
- **[verified]** **KubeVela** uses CUE as a runtime templating/abstraction layer that renders Kubernetes resources; it derives only a user-facing *parameter* JSON schema from CUE, **not** a CRD structural schema.
- **[assessed]** Net: **no significant project uses CUE as the source of truth that emits CRD YAML.** The ecosystem momentum and first-class tooling are Go→CRD (controller-gen) and CRD→CUE (`cue get crd` / timoni). OPM's desired direction (CUE→CRD **and** CUE→Go) is viable but upstream of that momentum — the assembly glue is OPM's to own.

## 6. Kubernetes structural-schema rules any generator must satisfy

- **[verified]** Structural core = an OpenAPI v3 subset of `properties, items, additionalProperties, type, nullable, title, description`; in each sub-schema only one of `properties`/`additionalProperties`/`items`; all types non-empty; root `type: object`. Required in `apiextensions.k8s.io/v1`. Source: `kubernetes.io/blog/2019/06/20/crd-structural-schema/`, CRD reference docs.
- **[verified]** Inside `allOf/anyOf/oneOf/not` you may **not** use `additionalProperties, type, nullable, title, description`. `default` is forbidden *inside* junctors but **allowed** at core level (defaulting is a structural-schema feature). `apiVersion`/`kind`/`metadata` cannot be constrained by the schema.
- **[verified]** int-or-string needs `x-kubernetes-int-or-string`; opting out of pruning needs `x-kubernetes-preserve-unknown-fields`.

## 7. Architectural options compared

| | Source of truth | CRD YAML from | Go types from | deepcopy | Verdict |
|---|---|---|---|---|---|
| **A** | CUE (`core/`) | CUE openapi encoder + assembler | `gengotypes`/custom emitter | controller-gen `object` on generated Go | Matches OPM's premise; OPM owns the assembly glue. **Chosen.** |
| **B** | Go (`opm-operator`) | controller-gen (status quo) | hand-authored | controller-gen | Battle-tested but inverts "core is canonical." |
| **C** | CRD YAML | hand-authored once | no first-class CRD→Go path | n/a | Awkward; Go types orphaned. |

**Recommendation the design adopts (Direction A, staged and honest):** CUE owns the schema **shape + validation + CRD metadata-as-data**; a single Go assembler (in `opm-operator`, or a shared codegen tool, consuming the *published* `opmodel.dev/core`) emits both the CRD YAML and the Go structs; controller-gen is retained **only** for deepcopy; CEL rules pass through verbatim. `gengotypes` is treated as optional/replaceable because it is experimental and lossy on disjunctions.

## Primary sources

- CUE OpenAPI encoder: `pkg.go.dev/cuelang.org/go/encoding/openapi`; `encoding/openapi/{doc.go,openapi.go,crd.go}` @v0.17.0-alpha.1.
- CUE OpenAPI concept + structural form: `cuelang.org/docs/concept/how-cue-works-with-openapi/`; full-OpenAPI tracking issue cue-lang/cue#3133.
- CUE→Go: `cuelang.org/docs/howto/generate-go-types-from-cue-definitions/`; `cue help exp gengotypes`; CUE v0.12.0 release notes.
- `encoding/gocode`: `pkg.go.dev/cuelang.org/go/encoding/gocode`; `encoding/gocode/generator.go` @v0.17.0-alpha.1.
- Go→CUE: `cuelang.org/docs/integration/go/`; `cuelang.org/docs/concept/how-cue-works-with-go/`.
- CRD import + CEL: cue-lang/cue#2691; `cmd/cue/cmd/get_crd.go`, `encoding/jsonschema/{crd.go,version.go,generate.go}` @v0.17.0-alpha.1.
- controller-gen: `book.kubebuilder.io/reference/controller-gen.html`; `sigs.k8s.io/controller-tools/pkg/deepcopy`.
- Structural schemas: `kubernetes.io/blog/2019/06/20/crd-structural-schema/`; `kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/`.
- Prior art: timoni (`timoni mod vendor crds`), Holos, KubeVela.
