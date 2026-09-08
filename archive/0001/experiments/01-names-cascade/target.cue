// Target schema for enhancement 0001 — #Platform Redesign Umbrella.
//
// This file is the canonical home for the CUE definitions the umbrella
// introduces or modifies. It compiles standalone (`cue vet ./...` from
// this directory) so experiments and reviewers can validate the shape
// without pulling the real core repo.
//
// Fields flagged `// OQN:` reference the corresponding Open Question in
// ../03-decisions.md and will tighten as those decisions resolve.
package schema

import "strings"

// ---- Identity primitives ----

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" &
	strings.MinRunes(1) & strings.MaxRunes(63)

#ModulePathType: string & =~"^[a-z0-9.-]+(/[a-z0-9.-]+)*$" &
	strings.MinRunes(1) & strings.MaxRunes(254)

// SemVer 2.0
#VersionType: string &
	=~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// SemVer-suffixed primitive FQN. Replaces today's MAJOR-only regex
// (=~ "…@v[0-9]+$"). See 02-design.md "Catalogs drop #defines; FQNs gain
// SemVer; publish stamps identity" and OQ13.
#FQNType: string &
	=~"^[a-z0-9.-]+(/[a-z0-9.-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#UUIDType: string &
	=~"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

#LabelsAnnotationsType: [string]: string | int | bool | [string | int | bool]

// ---- Primitive metadata (Resource / Trait / Blueprint / Transformer) ----
//
// All four primitives share this metadata shape. Today's #MajorVersionType
// at `version` is replaced by #VersionType. See 02-design.md and OQ8 / OQ16.
#PrimitiveMetadata: {
	name!:        #NameType
	modulePath!:  #ModulePathType
	version!:     #VersionType
	fqn:          #FQNType & "\(modulePath)/\(name)@\(version)"
	description?: string
	labels?:      #LabelsAnnotationsType
	annotations?: #LabelsAnnotationsType
}

#Resource: {
	kind:     "Resource"
	metadata: #PrimitiveMetadata
	spec!:    _
}

#Trait: {
	kind:     "Trait"
	metadata: #PrimitiveMetadata
	spec!:    _
}

#Blueprint: {
	kind:     "Blueprint"
	metadata: #PrimitiveMetadata
	spec!:    _
}

#ComponentTransformer: {
	kind:               "ComponentTransformer"
	metadata:           #PrimitiveMetadata & {description!: string}
	requiredLabels?:    #LabelsAnnotationsType
	optionalLabels?:    #LabelsAnnotationsType
	requiredResources?: [#FQNType]: #Resource
	optionalResources?: [#FQNType]: #Resource
	requiredTraits?:    [#FQNType]: #Trait
	optionalTraits?:    [#FQNType]: #Trait
	readsContext?:      [...string]
	producesKinds?:     [...string]
	#transform: {
		#moduleRelease: _
		#component:     _
		#context:       _
		output: {...} | [...{...}]
	}
}

#TransformerMap: [#FQNType]: #ComponentTransformer

// ---- Catalog identity stamp ----
//
// Every catalog declares this constant at the root of its CUE package.
// Source-tree default keeps `cue vet` cheap; the publish task overwrites
// `Version` with the concrete SemVer in a temp build dir before
// `cue mod publish`. See OQ8 / OQ9 / OQ10 / OQ11 / OQ12.
#CatalogIdentity: {
	Version:    #VersionType | *"0.0.0-dev"
	ModulePath: #ModulePathType
}

// ---- Platform + subscription ----

#SubscriptionFilter: {
	range?: string             // SemVer constraint, e.g. ">=1.0.0 <2.0.0". OQ2 / OQ3.
	allow?: [...#VersionType]  // force-include
	deny?:  [...#VersionType]  // force-exclude
}

#Subscription: {
	path!:   #ModulePathType   // e.g. "opmodel.dev/modules/opm"
	enable:  bool | *true
	filter?: #SubscriptionFilter
}

#Platform: {
	kind: "Platform"
	metadata: {
		name!:        #NameType
		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}
	type!: string

	// Path-keyed by Id (kebab-case). OQ1.
	#registry: [Id=#NameType]: #Subscription

	// Kernel-filled after Materialize. Both optional because the CUE-level
	// #Platform value is a spec; the kernel populates these on the materialized
	// twin. OQ4.
	#composedTransformers?: #TransformerMap
	#matchers?: {
		resources: [#FQNType]: [...#ComponentTransformer]
		traits:    [#FQNType]: [...#ComponentTransformer]
	}
}

// ---- Release + component identity ----

// Release identity carries the deployment-scoped facts that compute
// per-component DNS variants. clusterDomain lives here (single overridable
// home; OQ18 resolved by D4) instead of buried inside a runtime context.
#ReleaseIdentity: {
	name!:         #NameType
	namespace!:    #NameType
	uuid!:         #UUIDType
	clusterDomain: string | *"cluster.local"
}

// Per-component computed names. Single source of truth lives on each
// #Component.#names — see below. This struct also keys #ctx.components.
#ComponentNames: {
	resourceName!: #NameType
	dns: {
		short!: string   // "<resourceName>"
		local!: string   // "<resourceName>.<namespace>"
		fqdn!:  string   // "<resourceName>.<namespace>.svc.<clusterDomain>"
	}
}

// ---- Module + component ----

#Module: {
	kind: "Module"
	metadata: {
		name!:        #NameType
		modulePath!:  #ModulePathType
		version!:     #VersionType
		fqn:          string & "\(modulePath)/\(name):\(version)"
		uuid:         #UUIDType
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// #defines REMOVED — catalogs are plain CUE packages exporting
	// primitives at top level; #Module is the consumer artifact only.
	#components: [Id=#NameType]: #Component & {
		metadata: name: string | *Id
		// Wire the module-level release into every component so each
		// component computes its own #names from a shared release. D3.
		#release: #ctx.release
	}
	#config:     _
	debugValues: _

	// Runtime channel. Open at the top level (`...`) so future enhancements
	// can add `platform` / `environment` siblings without breaking module
	// bodies. OQ17.
	#ctx: {
		// Release identity — set by #ModuleRelease. D1.
		release: #ReleaseIdentity

		// Projection of every component's #names. Pure CUE comprehension
		// over #components — no separate computation, no risk of drift.
		// Components are the source of truth. D2.
		components: {
			for id, c in #components {
				(id): c.#names
			}
		}

		...
	}
}

#Component: {
	kind: "Component"
	metadata: {
		name!: #NameType
		// Per-component resource-name override. Defaults to metadata.name
		// when the author omits it; any explicit value wins via the
		// disjunction-default cascade. D2 / OQ20.
		resourceName: *name | #NameType
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}
	#resources:   [string]: #Resource
	#traits?:     [string]: #Trait
	#blueprints?: [string]: #Blueprint

	// Release context injected by the parent #Module. Hidden definition
	// slot; module authors never set this directly. D3.
	#release: #ReleaseIdentity

	// Single source of truth for this component's computed names.
	// resourceName reads straight from metadata (cascade lives there);
	// DNS variants derive deterministically from resourceName +
	// #release.namespace + #release.clusterDomain.
	#names: {
		resourceName: metadata.resourceName
		dns: {
			short: resourceName
			local: "\(resourceName).\(#release.namespace)"
			fqdn:  "\(resourceName).\(#release.namespace).svc.\(#release.clusterDomain)"
		}
	}

	spec: _
}

// ---- #ModuleRelease (slim) ----
//
// No #ContextBuilder. #ModuleRelease just sets #module.#ctx.release; the
// per-component #names compute themselves, and #ctx.components projects
// automatically via the comprehension above. D1.
#ModuleRelease: {
	kind: "ModuleRelease"
	metadata: {
		name!:         #NameType
		namespace!:    #NameType
		uuid:          #UUIDType
		clusterDomain: string | *"cluster.local"
	}
	#module: #Module & {
		#ctx: release: {
			name:          metadata.name
			namespace:     metadata.namespace
			uuid:          metadata.uuid
			clusterDomain: metadata.clusterDomain
		}
	}
	values: _
}
