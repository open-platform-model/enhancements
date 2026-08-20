# Specification changes: CUE-Native CRD Schemas as Single Source of Truth

<!--
Pre-draft of the core/SPEC.md co-update for the core slice of enhancement 0008 (the `core-schema-edit` skill gates that co-update via pre-commit hook + CI). Every construct here is NEW vs core@v2 — core/src/ carries no CRD-shaped definitions today. Content is derived from 01-problem.md, 02-design.md, and 03-decisions.md (D1–D8); aspects still gated by an Open Question say so inline.
-->

The delta adds one new file, `core/src/crd.cue`, carrying a `#CRD` envelope and its sub-shapes, plus one `#CRD` instance per in-scope kind anchored next to its domain definition (`#ModuleInstanceCRD` in `core/src/module_instance.cue`, `#PlatformCRD` in `core/src/platform.cue`). The envelope pairs the Kubernetes object-metadata of a CRD with the OpenAPIv3-compatible schema body — reusing the existing `#ModuleInstance` / `#Platform` definitions, which are not re-authored — and with the non-schema facets controller-gen expresses as kubebuilder markers today, modelled as plain CUE data (D4). A downstream Go assembler consuming the published `opmodel.dev/core` module (D2) emits the CRD YAML and the Go API types from these values (D1, D3).

Whether a `#ModulePackageCRD` instance is part of the delta is gated by OQ4 (does `ModulePackage` get a core domain definition, or is it operator-only?). The semver classification of the whole delta is gated by OQ5: the envelope and instances are additive (minor), but any change forced onto the existing `#ModuleInstance` / `#Platform` field shapes would be breaking.

## #CRD (NEW)

### Definition

`#CRD` is the envelope declaring one Kubernetes CustomResourceDefinition natively in core. It carries the identity of the custom resource — API group, names, scope — and the list of API versions, each of which binds an OpenAPIv3-compatible schema body (an existing core domain definition) together with the version's serving flags and non-schema facets. It is the single authored source from which downstream tooling generates both the CRD manifest and the Go API types; it defines no field shapes of its own beyond the envelope.

### Shape

```cue
#CRD: {
	group!:    string // e.g. "opmodel.dev"
	names!:    #CRDNames
	scope!:    #Scope
	versions!: [#CRDVersion, ...#CRDVersion]
}
```

### Constraints

- `group`, `names`, `scope`, and `versions` MUST all be present; `versions` MUST carry at least one `#CRDVersion`.
- The schema bodies bound through `versions` MUST be existing core domain definitions; a `#CRD` MUST NOT re-author (`fork`) the `spec`/`status` field shapes it envelopes — there is exactly one definition of each field.
- Downstream generators MUST treat the `#CRD` value as the sole source for both the CRD manifest and the corresponding Go API types; the generated artefacts MUST NOT be hand-edited.

### Rationale

- **Why an envelope rather than markers.** The non-schema facets of a CRD live today as kubebuilder marker comments on Go code; markers on generated code are clobbered on regeneration, and splitting the CRD between CUE (schema) and Go comments (everything else) recreates the two-places drift problem this construct removes (D4).
- **Why reference, not restate, the domain bodies.** Restating `spec`/`status` shapes inside the envelope would reintroduce a second authored definition of every field — the exact silent-drift hazard described in the problem statement. Referencing the domain definitions keeps one definition per field (D1).
- **Why in core.** The workspace designates core as the source of truth every downstream consumes, and core SPEC.md already constrains `spec` surfaces to OpenAPIv3 precisely so non-CUE consumers can read them; declaring the CRD here makes the running system match the stated model instead of inverting it (D1).

## #CRDVersion (NEW)

### Definition

`#CRDVersion` describes one served API version of a `#CRD`: its name, whether it is served and used for storage, the OpenAPIv3-compatible `spec`/`status` schema body for that version, and the version-scoped facets — subresources, printer columns, and CEL validation rules.

### Shape

```cue
#CRDVersion: {
	name!:   string // e.g. "v1alpha1"
	served:  bool | *true
	storage: bool | *true

	schema!: {
		spec!:   {...}
		status?: {...}
	}

	subresources:              #Subresources
	additionalPrinterColumns?: [...#PrinterColumn]
	validations?:              [...#CELValidation]
}
```

### Constraints

- `name` and `schema` MUST be present; `schema.spec` MUST be present, `schema.status` MAY be omitted.
- `served` and `storage` default to `true`; authors MAY override either.
- The `schema` bodies MUST be OpenAPIv3-compatible (no CUE templating inside them), so `cuelang.org/go/encoding/openapi` in structural mode (`ExpandReferences: true`) can emit the version's `openAPIV3Schema` (D3).
- Entries in `validations` MUST be injected into the assembled manifest verbatim; the generator MUST NOT parse or rewrite them (D6).

### Rationale

- **Why per-version facets.** Printer columns, subresources, and CEL rules are version-scoped in the CRD API itself; modelling them anywhere else would force lossy flattening at assembly time.
- **Why structural-OpenAPI emission is a constraint here.** Kubernetes CRDs require the structural schema form; core's existing OpenAPIv3 mandate on `spec` surfaces is what makes clean emission possible, so the version body inherits that mandate explicitly (D3).
- **Why defaults for `served`/`storage`.** The single-version common case (one served storage version) should need no boilerplate; multi-version CRDs override per version.

## #CRDNames (NEW)

### Definition

`#CRDNames` is the naming block of the envelope: the resource kind and its plural/singular/listKind forms plus short names, mirroring the `names` stanza of a CustomResourceDefinition.

### Shape

```cue
#CRDNames: {
	kind!:       string
	plural!:     string
	singular?:   string
	listKind?:   string
	shortNames?: [...string]
}
```

### Constraints

- `kind` and `plural` MUST be present; `singular`, `listKind`, and `shortNames` MAY be omitted, in which case the assembler falls back to Kubernetes' own defaulting.

### Rationale

- **Why a dedicated block.** Short names and plural forms are authored today as `+kubebuilder:resource:scope=…,shortName=…` markers; carrying them as data beside the schema keeps the whole CRD definition in one CUE value (D4).

## #Scope (NEW)

### Definition

`#Scope` is the two-valued scope of a custom resource, matching the CRD API's `scope` field.

### Shape

```cue
#Scope: "Namespaced" | "Cluster"
```

### Constraints

- A `#CRD.scope` MUST be exactly one of `"Namespaced"` or `"Cluster"`; no other value unifies.

### Rationale

- **Why a closed disjunction.** The API server accepts exactly these two values; rejecting anything else at CUE evaluation time keeps an invalid scope from surviving until manifest assembly.

## #PrinterColumn (NEW)

### Definition

`#PrinterColumn` is a direct, lossless model of one `+kubebuilder:printcolumn` marker: an additional printer column on a CRD version, described by name, column type, and the JSONPath that feeds it.

### Shape

```cue
#PrinterColumn: {
	name!:        string
	type!:        "string" | "integer" | "number" | "boolean" | "date"
	jsonPath!:    string
	priority?:    int
	description?: string
}
```

### Constraints

- `name`, `type`, and `jsonPath` MUST be present.
- `type` MUST be one of the five column types the CRD API supports.
- The assembler MUST splice these entries into `additionalPrinterColumns` of the generated manifest without transformation.

### Rationale

- **Why lossless.** The construct exists to replace a marker one-for-one; any abstraction over the marker's fields would make round-tripping the existing CRDs impossible to verify.

## #CELValidation (NEW)

### Definition

`#CELValidation` is a direct model of one `+kubebuilder:validation:XValidation` marker: a CEL rule attached to a CRD version, carried as an opaque string together with its message and metadata fields. Core stores the rule; it never evaluates or interprets it.

### Shape

```cue
#CELValidation: {
	rule!:              string
	message?:           string
	messageExpression?: string
	reason?:            "FieldValueInvalid" | "FieldValueForbidden" | "FieldValueRequired" | "FieldValueDuplicate"
	fieldPath?:         string
	optionalOldSelf?:   bool
}
```

### Constraints

- `rule` MUST be present and MUST be carried verbatim into the generated `x-kubernetes-validations`; no CEL↔CUE translation is attempted in either direction (D6).
- `reason`, when present, MUST be one of the four values the CRD API defines.

### Rationale

- **Why verbatim passthrough.** CEL↔CUE translation is unbounded work with correctness hazards — the CUE maintainers call it "a big lift," and CEL's `oldSelf` transition rules are unrepresentable in stateless CUE. Passthrough is lossless and zero-risk (D6).
- **Why store CEL in core at all.** Without it, the one existing CEL rule (the Platform singleton guard) would have to stay as a Go marker, splitting the CRD definition across two artefacts again (D4).

## #Subresources (NEW)

### Definition

`#Subresources` toggles the subresources of a CRD version. Today it carries only the `/status` subresource flag.

### Shape

```cue
#Subresources: {
	status?: bool | *true
}
```

### Constraints

- `status` defaults to `true`; a version MAY disable it.
- The toggle only declares that the version has a `/status` subresource. Which fields the status body carries, and whether their ownership splits between core and operator-owned CUE, is unresolved — gated by OQ2.

### Rationale

- **Why a struct rather than a bare bool.** The CRD API's `subresources` stanza also admits `scale`; a struct leaves room for it without a shape change if it is ever needed.

## #ModuleInstanceCRD, #PlatformCRD (NEW)

### Definition

The worked `#CRD` instances for the existing kinds: `ModuleInstance` (namespaced, short name `mi`) and `Platform` (cluster-scoped, short name `plat`, cluster singleton). Each binds the kind's CRD identity and version facets to the existing core domain definitions as its `v1alpha1` schema body. These are genuine generator input, not illustrations: `cmd/crdgen` reads them to emit `config/crd/bases/*.yaml` and the `api/v1alpha1` Go types. In this enhancement's schemas package they live in `examples.cue` (with local illustrative mirrors of the domain bodies so the package compiles standalone); in core they land beside their domain definitions in `core/src/module_instance.cue` and `core/src/platform.cue`. A third instance for `ModulePackage` is pending OQ4.

### Shape

```cue
#ModuleInstanceCRD: #CRD & {
	group: "opmodel.dev"
	names: {kind: "ModuleInstance", plural: "moduleinstances", singular: "moduleinstance", shortNames: ["mi"]}
	scope: "Namespaced"
	versions: [{name: "v1alpha1", schema: {spec: …, status: …}, subresources: status: true, additionalPrinterColumns: […]}]
}

#PlatformCRD: #CRD & {
	group: "opmodel.dev"
	names: {kind: "Platform", plural: "platforms", singular: "platform", shortNames: ["plat"]}
	scope: "Cluster"
	versions: [{name: "v1alpha1", schema: {spec: …, status: …}, subresources: status: true, additionalPrinterColumns: […], validations: [{rule: "self.metadata.name == 'cluster'", …}]}]
}
```

The full values live in `examples.cue`.

### Constraints

- Both instances MUST serialise to CRDs byte-compatible (modulo formatting) with the previously shipped manifests for unchanged fields — this is an authoring/generation change, not a schema change.
- The schema bodies MUST reference the existing `#ModuleInstance` / `#Platform` definitions; the existing field shapes MUST be reused, not forked. If anchoring forces any change to those shapes, the semver classification escalates from minor to breaking (OQ5).
- `#PlatformCRD` MUST carry the cluster-singleton CEL rule `self.metadata.name == 'cluster'` verbatim (D6).
- The status body of each instance is provisional until OQ2 resolves which status fields core defines versus which the operator owns.

### Rationale

- **Why instances in core, not in the operator.** The instances are the contract; generating from the published core module guarantees the generated types match what the kernel evaluates, and keeps the generator downstream of the published artefact instead of inside core's build (D1, D2).
- **Why byte-compatibility is a constraint.** The enhancement's non-goal is explicit: no field shape, validation, or API version changes ride along. A silent schema change hidden in a generation change would be exactly the class of drift this design exists to eliminate.
