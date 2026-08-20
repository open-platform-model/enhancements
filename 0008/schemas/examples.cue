// Worked instances and concrete examples for enhancement 0008 — the test for
// target.cue's #CRD envelope.
//
// Three layers, in order:
//
//  1. Illustrative local bodies — mirrors of the existing core domain shapes
//     (#ModuleInstance / #Platform spec/status), present ONLY so this package
//     compiles standalone for review. In core/ the real definitions are the
//     authoritative bodies; nothing here re-proposes them.
//  2. The two worked #CRD instances (#ModuleInstanceCRD, #PlatformCRD) —
//     genuine codegen input, proposed to land in core/src/ alongside their
//     domain definitions. They are definitions, intentionally non-concrete: a
//     CRD's `schema` field holds a type (the domain schema), not data.
//  3. Concrete values + hidden `_assert*` pins that make `cue vet ./...` a
//     real unification test over every NEW definition in target.cue.
package schema

// ---------------------------------------------------------------------------
// 1. Illustrative local bodies (in core/ these are the real domain definitions).
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
	values?: {...}       // OQ5: must stay an object to match the core contract
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
// 2. Worked instances — the CRDs re-expressed as #CRD values (codegen input).
// ---------------------------------------------------------------------------

// Worked instances are definitions: a CRD's `schema` field holds a type (the
// domain schema), not concrete data, so these are intentionally non-concrete.
#ModuleInstanceCRD: #CRD & {
	group: "opmodel.dev"
	names: {
		kind:     "ModuleInstance"
		plural:   "moduleinstances"
		singular: "moduleinstance"
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
		kind:     "Platform"
		plural:   "platforms"
		singular: "platform"
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

// ---------------------------------------------------------------------------
// 3. Concrete examples + assertions — what makes `cue vet ./...` a real test.
// ---------------------------------------------------------------------------

// A worked value with every facet stated explicitly, exercising every envelope
// shape at once: #CRD, #CRDVersion, #CRDNames, #Scope, #Subresources,
// #PrinterColumn, #CELValidation. Hidden rather than exported because a CRD
// schema body is a type, which `cue vet` would otherwise flag as incomplete;
// hidden fields are still fully evaluated, so the unification test stands.
_exampleWidgetCRD: #CRD & {
	group: "example.opmodel.dev"
	names: {
		kind:     "Widget"
		plural:   "widgets"
		singular: "widget"
		listKind: "WidgetList"
		shortNames: ["wd"]
	}
	scope: "Namespaced"
	versions: [{
		name:    "v1alpha1"
		served:  true
		storage: true
		schema: {
			spec: {size: "small" | "large"}
			status: {ready: bool}
		}
		subresources: status: true
		additionalPrinterColumns: [
			{name: "Size", type: "string", jsonPath: ".spec.size", priority: 1, description: "Declared widget size"},
		]
		validations: [{
			rule:            "self.spec.size == oldSelf.spec.size"
			message:         "size is immutable"
			reason:          "FieldValueInvalid"
			fieldPath:       ".spec.size"
			optionalOldSelf: true
		}]
	}]
}

// Assertions — pin the load-bearing facet values so a shape change in
// target.cue (or a drive-by edit to the worked instances) breaks the build.

// #ModuleInstanceCRD: identity + printer-column facets.
_assertMIKind:     #ModuleInstanceCRD.names.kind & "ModuleInstance"
_assertMIPlural:   #ModuleInstanceCRD.names.plural & "moduleinstances"
_assertMIShort:    #ModuleInstanceCRD.names.shortNames[0] & "mi"
_assertMIScope:    #ModuleInstanceCRD.scope & "Namespaced"
_assertMIVersion:  #ModuleInstanceCRD.versions[0].name & "v1alpha1"
_assertMIStatus:   #ModuleInstanceCRD.versions[0].subresources.status & true
_assertMIColPath:  #ModuleInstanceCRD.versions[0].additionalPrinterColumns[1].jsonPath & ".spec.module.path"
_assertMIColCount: len(#ModuleInstanceCRD.versions[0].additionalPrinterColumns) & 3

// #PlatformCRD: cluster scope + the verbatim CEL singleton rule (D6).
_assertPlatScope:   #PlatformCRD.scope & "Cluster"
_assertPlatCELRule: #PlatformCRD.versions[0].validations[0].rule & "self.metadata.name == 'cluster'"

// _exampleWidgetCRD: served/storage flags stated concretely unify with their
// defaulted declarations in #CRDVersion.
_assertWidgetServed:  _exampleWidgetCRD.versions[0].served & true
_assertWidgetStorage: _exampleWidgetCRD.versions[0].storage & true

// Must-fail cases — re-run by hand by uncommenting. Error text observed with
// `cue vet ./...` (CUE v0.17.1).
//
// A scope outside #Scope's disjunction:
//	_mustFailScope: #CRD & _exampleWidgetCRD & {scope: "Regional"}
//	→ _mustFailScope.scope: 2 errors in empty disjunction:
//	  conflicting values "Cluster" and "Regional"
//	  conflicting values "Namespaced" and "Regional"
//
// A printer-column type outside the CRD-supported set:
//	_mustFailColType: #PrinterColumn & {name: "X", type: "float", jsonPath: ".x"}
//	→ _mustFailColType.type: 5 errors in empty disjunction:
//	  conflicting values "float" with each of "string" | "integer" | "number" | "boolean" | "date"
//
// A #CELValidation missing its required rule. Exported (no leading underscore)
// deliberately: a missing required field surfaces through vet's completeness
// pass, which skips hidden fields — plain `cue vet ./...` then exits nonzero,
// and `cue vet -c ./...` names the error:
//	mustFailNoRule: #CELValidation & {message: "no rule"}
//	→ mustFailNoRule.rule: field is required but not present
