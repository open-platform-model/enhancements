// Target schema for enhancement 0008 — CUE-Native CRD Schemas.
//
// The #CRD envelope below is the NEW surface this enhancement adds to core/.
// It pairs the Kubernetes object-metadata of a CRD (group/names/scope/versions)
// with the OpenAPIv3-compatible schema body (reused from the existing core
// domain definitions) and the non-schema facets controller-gen expresses as
// kubebuilder markers today (status subresource, printer columns, CEL rules) —
// here modelled as plain CUE DATA (D4), so a downstream Go assembler can emit
// both the CRD YAML and the Go API types from one source (D1, D2, D3).
//
// The spec/status BODIES are not re-authored here — in core/ they are the
// existing #ModuleInstance / #Platform definitions. The mirrored shapes in this
// file are illustrative locals so the file compiles standalone for review
// (same convention as 0006's target.cue); they are not the authoritative
// bodies.
//
// Open questions tracked in ../03-decisions.md are marked `// OQn:` inline.
package schema

// ---------------------------------------------------------------------------
// The #CRD envelope (new in core/src/crd.cue)
// ---------------------------------------------------------------------------

#Scope: "Namespaced" | "Cluster"

#CRDNames: {
	kind!:       string
	plural!:     string
	singular?:   string
	listKind?:   string
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
		spec!:   {...}
		status?: {...}
	}

	subresources:              #Subresources
	additionalPrinterColumns?: [...#PrinterColumn]
	validations?:              [...#CELValidation]
}

#CRD: {
	group!:    string // e.g. "opmodel.dev"
	names!:    #CRDNames
	scope!:    #Scope
	versions!: [#CRDVersion, ...#CRDVersion]
}

// ---------------------------------------------------------------------------
// Illustrative local bodies (in core/ these are the real domain definitions).
// ---------------------------------------------------------------------------

#Condition: {
	type!:    string
	status!:  "True" | "False" | "Unknown"
	reason?:  string
	message?: string
}

#ModuleInstanceSpec: {
	suspend?: bool
	module!: {
		path!:    string
		version!: string
	}
	values?:             {...} // OQ5: must stay an object to match the core contract
	prune?:              bool
	serviceAccountName?: string
	owner?:              "cli" | "operator" // from 0006
}

#ModuleInstanceStatus: {
	observedGeneration?: int
	instanceUUID?:       string
	conditions?: [...#Condition]
	...
}

#PlatformSpec: {
	type!: string
	registry?: [string]: {
		enable?: bool
		filter?: {
			range?: string
			allow?: [...string]
			deny?: [...string]
		}
	}
}

#PlatformStatus: {
	observedGeneration?: int
	conditions?: [...#Condition]
}

// ---------------------------------------------------------------------------
// Worked instances — the three CRDs re-expressed as #CRD values.
// ---------------------------------------------------------------------------

// Worked instances are definitions: a CRD's `schema` field holds a type (the
// domain schema), not concrete data, so these are intentionally non-concrete.
#ModuleInstanceCRD: #CRD & {
	group: "opmodel.dev"
	names: {
		kind:       "ModuleInstance"
		plural:     "moduleinstances"
		singular:   "moduleinstance"
		shortNames: ["mi"]
	}
	scope: "Namespaced"
	versions: [{
		name: "v1alpha1"
		schema: {
			spec:   #ModuleInstanceSpec
			status: #ModuleInstanceStatus
		}
		subresources: status: true
		additionalPrinterColumns: [
			{name: "Ready", type: "string", jsonPath: ".status.conditions[?(@.type=='Ready')].status"},
			{name: "Module", type: "string", jsonPath: ".spec.module.path"},
			{name: "Version", type: "string", jsonPath: ".spec.module.version"},
		]
	}]
}

#PlatformCRD: #CRD & {
	group: "opmodel.dev"
	names: {
		kind:       "Platform"
		plural:     "platforms"
		singular:   "platform"
		shortNames: ["plat"]
	}
	scope: "Cluster"
	versions: [{
		name: "v1alpha1"
		schema: {
			spec:   #PlatformSpec
			status: #PlatformStatus
		}
		subresources: status: true
		additionalPrinterColumns: [
			{name: "Type", type: "string", jsonPath: ".spec.type"},
			{name: "Ready", type: "string", jsonPath: ".status.conditions[?(@.type=='Ready')].status"},
		]
		// CEL rule carried verbatim (D6) — the Platform cluster-singleton guard.
		validations: [{
			rule:    "self.metadata.name == 'cluster'"
			message: "Platform is a cluster singleton; the only permitted name is 'cluster'"
		}]
	}]
}
