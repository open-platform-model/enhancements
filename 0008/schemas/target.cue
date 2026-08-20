// Core-schema delta for enhancement 0008 — CUE-Native CRD Schemas.
//
// Delta manifest (vs core@v2 — core/src/ has no CRD-shaped definitions today):
//
//	#CRD               NEW — the CRD envelope: group + names + scope + versions; one per custom resource (proposed core/src/crd.cue)
//	#CRDVersion        NEW — per-version served/storage flags, OpenAPIv3-compatible schema body, subresources, printer columns, CEL validations
//	#CRDNames          NEW — kind/plural/singular/listKind/shortNames block of the envelope
//	#Scope             NEW — "Namespaced" | "Cluster"
//	#PrinterColumn     NEW — direct, lossless model of +kubebuilder:printcolumn (D4)
//	#CELValidation     NEW — direct model of +kubebuilder:validation:XValidation; `rule` carried verbatim, never parsed (D4, D6)
//	#Subresources      NEW — status-subresource toggle (field ownership gated by OQ2)
//	#ModuleInstanceCRD NEW — worked #CRD instance for ModuleInstance (in examples.cue; genuine codegen input, proposed for core/src/module_instance.cue)
//	#PlatformCRD       NEW — worked #CRD instance for Platform (in examples.cue; genuine codegen input, proposed for core/src/platform.cue)
//
// The #CRD envelope pairs the Kubernetes object-metadata of a CRD
// (group/names/scope/versions) with the OpenAPIv3-compatible schema body
// (reused from the existing core domain definitions) and the non-schema facets
// controller-gen expresses as kubebuilder markers today (status subresource,
// printer columns, CEL rules) — here modelled as plain CUE DATA (D4), so a
// downstream Go assembler can emit both the CRD YAML and the Go API types from
// one source (D1, D2, D3).
//
// The spec/status BODIES are not re-authored here — in core/ they are the
// existing #ModuleInstance / #Platform definitions. examples.cue carries
// illustrative local mirrors of those shapes (so the package compiles
// standalone), the two worked #CRD instances, and the concrete test values.
//
// Open questions tracked in ../03-decisions.md are marked `// OQn:` inline.
package schema

// ---------------------------------------------------------------------------
// The #CRD envelope (new in core/src/crd.cue)
// ---------------------------------------------------------------------------

#Scope: "Namespaced" | "Cluster"

#CRDNames: {
	kind!:     string
	plural!:   string
	singular?: string
	listKind?: string
	shortNames?: [...string]
}

// Direct, lossless model of +kubebuilder:printcolumn (D4).
#PrinterColumn: {
	name!:        string
	type!:        "string" | "integer" | "number" | "boolean" | "date"
	jsonPath!:    string
	priority?:    int
	description?: string
}

// Direct model of +kubebuilder:validation:XValidation (D4). `rule` is a CEL
// expression carried VERBATIM into x-kubernetes-validations — never parsed,
// never translated to/from CUE (D6).
#CELValidation: {
	rule!:              string
	message?:           string
	messageExpression?: string
	reason?:            "FieldValueInvalid" | "FieldValueForbidden" | "FieldValueRequired" | "FieldValueDuplicate"
	fieldPath?:         string
	optionalOldSelf?:   bool
}

#Subresources: {
	// OQ2: status field ownership (core-defined vs operator-owned) is unresolved;
	// the toggle here only says "this version has a /status subresource".
	status?: bool | *true
}

#CRDVersion: {
	name!:   string // e.g. "v1alpha1"
	served:  bool | *true
	storage: bool | *true

	// OpenAPIv3-compatible body. In core/ these reference the domain
	// definitions (#ModuleInstance, #Platform); the encoder turns them into the
	// structural openAPIV3Schema (D3).
	schema!: {
		spec!: {...}
		status?: {...}
	}

	subresources: #Subresources
	additionalPrinterColumns?: [...#PrinterColumn]
	validations?: [...#CELValidation]
}

#CRD: {
	group!: string // e.g. "opmodel.dev"
	names!: #CRDNames
	scope!: #Scope
	versions!: [#CRDVersion, ...#CRDVersion]
}
