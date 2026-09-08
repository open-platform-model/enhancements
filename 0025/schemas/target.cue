// Core-schema delta for enhancement 0025: Self-Service Kinds from Published
// Modules.
//
// Delta manifest (vs opmodel.dev/core@v2). The file is standalone rather
// than importing opmodel.dev/core, so the entry vets offline; MIRROR marks
// an unchanged core type restated in reduced form for the delta to reference.
//
//   #Offering          NEW      the platform-owned definition binding a module
//                               lineage, major, release, update policy and
//                               bound values, optionally served as a kind.
//                               IDENTIFIER IS A PLACEHOLDER: the kind name is
//                               OQ1 and every #Offering* identifier renames
//                               with the decision.
//   #OfferingAPI       NEW      the served kind's group and kind (kind layer).
//   #UpdatePolicy      NEW      what a rebind does to live instances (OQ3).
//   #OfferingInstance  NEW      an instance of a served kind: apiVersion and
//                               kind derived from the definition, spec = the
//                               consumer's values, status per OQ5.
//   #Project           NEW      the pure projection (D6): definition +
//                               instance + resolved module -> #ModuleInstance.
//   #KindVersion       NEW      the served CRD version derived from the
//                               module major (D7).
//   #Module            MIRROR   reduced: identity fields and #config only.
//   #ModuleInstance    MIRROR   reduced: identity, #module and values only.
//
// Unresolved fields carry `// OQN:` markers pointing at 07-questions.md.
package schema

import "strings"

// ─── MIRROR: core scalar types (reduced) ────────────────────────────────────

// Kubernetes-style DNS label.
#NameType: =~"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" & strings.MaxRunes(63)

// A module's name is its CUE package name (0010 D8).
#SnakeNameType: =~"^[a-z][a-z0-9_]*$"

// A major-free registry path, the module lineage (0010 D41's identity base).
#PackagePathType: =~"^[a-z0-9.-]+(/[a-zA-Z0-9._-]+)*$"

// A complete module path carrying its major (0010 D1).
#ModulePathType: =~"^[a-z0-9.-]+(/[a-zA-Z0-9._-]+)*@v[0-9]+$"

// A full SemVer release.
#VersionType: =~"^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

#MajorType: int & >=0

// ─── MIRROR: #Module (reduced) ──────────────────────────────────────────────

// Only what the projection reads: identity and the value schema. The real
// definition carries #components, #ctx, debugValues and the label stamps;
// none of them change under this entry (D5: #Module gains no authored
// field).
#Module: {
	kind: "Module"
	metadata: {
		name!:        #SnakeNameType
		modulePath!:  #ModulePathType
		version!:     #VersionType
		registryPath: #PackagePathType
		...
	}
	// Value schema. Core already declares it OpenAPIv3-compatible; D2 makes
	// that load-bearing for a module bound as a served kind. Structural-ness
	// is not expressible as a CUE constraint here; it is checked by the
	// encoder at definition acceptance.
	#config: _
	...
}

// ─── MIRROR: #ModuleInstance (reduced) ──────────────────────────────────────

// Only what the projection produces. The real definition derives fqn, uuid,
// labels and the components projection from these same fields.
#ModuleInstance: {
	kind: "ModuleInstance"
	metadata: {
		name!:      #NameType
		namespace!: #NameType
		...
	}
	#module!: #Module
	values:   _
	// values must satisfy the module's #config; the real definition does this
	// by unifying #module & {#config: values}. Mirrored as a check so the
	// examples exercise it.
	_configCheck: #module.#config & values
	...
}

// ─── NEW: the definition (placeholder identifier, OQ1) ──────────────────────

// #Offering: the platform-owned, cluster-scoped binding (D1). The consumer
// never sees spec.module; the platform owns the coordinate.
#Offering: {
	kind: "Offering" // OQ1: placeholder kind name.

	metadata: name!: #NameType

	spec: {
		module: {
			// The lineage (major-free), the bound major and the bound release.
			registryPath!: #PackagePathType
			major!:        #MajorType
			version!:      #VersionType

			// The release must sit inside the bound major (D7). Same shape
			// as core's own hidden checks: a boolean that must be true.
			_agrees: strings.HasPrefix(version, "\(major).")
			_agrees: true
		}

		// What a rebind does to live instances. OQ3: vocabulary and default.
		updatePolicy: #UpdatePolicy

		// Platform-bound values, unified with the consumer's at projection;
		// a conflict is a refusal (D6). OQ10: whether the served schema is
		// #config minus these fields.
		values?: {...}

		// Present only in the kind layer (D4). Absent means binding only.
		api?: #OfferingAPI
	}
}

// OQ3: candidates recorded; default and semantics undecided.
#UpdatePolicy: *"manual" | "automatic"

// The served kind's coordinates (kind layer). The CRD version is derived from
// the module major (D7), never authored here.
#OfferingAPI: {
	group!:  =~"^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$"
	kind!:   =~"^[A-Z][A-Za-z0-9]*$"
	plural?: =~"^[a-z][a-z0-9]*$"
}

// ─── NEW: the served CRD version (D7) ───────────────────────────────────────

#KindVersion: {
	#major: #MajorType
	out:    "v\(#major)"
}

// ─── NEW: an instance of a served kind ──────────────────────────────────────

// #OfferingInstance: what a consumer creates in the kind layer. apiVersion
// and kind derive from the definition; the consumer authors metadata and
// spec only (D9: namespaced, the only consumer-facing object).
#OfferingInstance: {
	// A served-kind instance exists only for a definition that names an API.
	#offering: #Offering & {spec: api: #OfferingAPI}

	apiVersion: "\(#offering.spec.api.group)/\((#KindVersion & {#major: #offering.spec.module.major}).out)"
	kind:       #offering.spec.api.kind

	metadata: {
		name!:      #NameType
		namespace!: #NameType
	}

	// The consumer's values. Validated against the served schema at the API
	// server (D2) and against #config again at projection (the mirror's
	// _configCheck). OQ10: this is #config minus the bound fields.
	spec: {...}

	// OQ5: the status contract. Left open here; the minimum is conditions
	// mirrored from the projected instance plus a reference to it.
	status?: {...}
}

// ─── NEW: the projection (D6) ───────────────────────────────────────────────

// #Project: definition + instance + resolved module -> #ModuleInstance. Pure:
// every frontend computes exactly this. The module is supplied resolved (the
// artifact the definition's coordinate names); the projection asserts it is
// the bound one rather than fetching it.
#Project: {
	#offering: #Offering
	#instance: #OfferingInstance & {#offering: #Project.#offering}
	#module:   #Module & {
		metadata: {
			registryPath: #offering.spec.module.registryPath
			version:      #offering.spec.module.version
		}
	}

	let mod = #module

	out: #ModuleInstance & {
		metadata: {
			name:      #instance.metadata.name
			namespace: #instance.metadata.namespace
		}
		#module: mod

		// Bound values and consumer values unify; a conflict is a refusal,
		// never an override (D6).
		values: #instance.spec
		if #offering.spec.values != _|_ {
			values: #offering.spec.values
		}
	}
}
