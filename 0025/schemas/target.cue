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
//   #ModuleTrait       NEW      a module-scoped trait, sibling of #Trait: same
//                               identity block, no appliesTo, no name
//                               constraint (D12).
//   #Aspect            NEW      a named bundle of module traits on #Module,
//                               sibling of #Component: derived matchLabels,
//                               closed spec, resourceName cascade (D11).
//   #ModuleTransformer NEW      renders an aspect to resources, sibling of
//                               #ComponentTransformer (D13).
//   #Module            CHANGED  gains #aspects (D11); mirrored reduced:
//                               identity, #config, #aspects, #ctx.
//   #ModuleInstance    MIRROR   reduced: identity, #module and values only;
//                               wires #ctx.instance as core does.
//   #Catalog           CHANGED  gains #moduleTransformers beside
//                               #transformers (D14); mirrored reduced.
//   #Platform          CHANGED  folds module transformers as it folds
//                               component transformers (D14); mirrored
//                               reduced.
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

// A contract key: path/name@vN where vN is the primitive's own apiVersion (0010 D4).
#ContractFQNType: =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+((alpha|beta)[0-9]+)?$"

// An implementation key: path/name@semver, the build the definition shipped in.
#ImplFQNType: =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?$"

// A primitive's contract level.
#APIVersionType: =~"^v[0-9]+((alpha|beta)[0-9]+)?$"

// RFC 1123 DNS subdomain: the override ceiling for a resource name (0019 D20).
#ObjectNameType: =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" & strings.MaxRunes(253)

#LabelsAnnotationsType: [string]: string | int | bool

// The deployment-scoped facts #ModuleInstance injects into every component
// and, under this entry, into every aspect.
#InstanceIdentity: {
	name!:         #NameType
	namespace!:    #NameType
	clusterDomain: string | *"cluster.local"
}

// ─── MIRROR: #Module (reduced) ──────────────────────────────────────────────

// Identity, the value schema, and the one CHANGE this entry makes to
// #Module: the #aspects map (D11). The real definition also carries
// #components, debugValues and the label stamps, unchanged here.
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

	// CHANGED (D11): named, module-scoped bundles of module traits. The
	// pattern constraint is #components' transposed: the key defaults the
	// name, a label stamps it, and the instance identity is injected so an
	// aspect computes its own resourceName. An aspect's spec is authored
	// inside the module and so sees #config and #ctx lexically.
	#aspects?: [Id=#NameType]: #Aspect & {
		metadata: {
			name: string | *Id
			labels: "aspect.opmodel.dev/name": name
		}
		#instance: #ctx.instance

		// An aspect with no trait matches nothing and is dead weight: refused.
		// The field is restated so the reference resolves in this scope.
		#traits:    _
		_hasTraits: len(#traits) > 0
		_hasTraits: true
	}

	// Reduced: the real #ctx also projects #components' names. OQ14: whether
	// it gains an `aspects` projection beside `components`.
	#ctx: {
		instance: #InstanceIdentity
		...
	}
	...
}

// ─── MIRROR: #ModuleInstance (reduced) ──────────────────────────────────────

// Only what the projection produces. The real definition derives fqn, uuid,
// labels and the components projection from these same fields.
#ModuleInstance: {
	kind: "ModuleInstance"
	metadata: {
		name!:         #NameType
		namespace!:    #NameType
		clusterDomain: string | *"cluster.local"
		...
	}
	// Wired as core wires it: the instance identity reaches every component
	// and, under D11, every aspect through #ctx.
	#module!: #Module & {
		#ctx: instance: {
			name:          metadata.name
			namespace:     metadata.namespace
			clusterDomain: metadata.clusterDomain
		}
	}
	values: _
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
	#module: #Module & {
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

// ─── NEW: #ModuleTrait, a module-scoped trait (D12) ─────────────────────────

// #ModuleTrait: what a catalog publishes for a module to say something about
// itself as a whole. The identity block, matchLabels, fulfilment, optional
// and spec are #Trait's, so #TraitOptionalGate and #CatalogMemberFQNGate
// apply unchanged. It has NO appliesTo (a module trait applies to the
// module) and NO #nameConstraint (an aspect renders no Service).
#ModuleTrait: {
	kind: "ModuleTrait"

	metadata: {
		name!:           #NameType
		modulePath!:     #PackagePathType
		apiVersion!:     #APIVersionType
		catalogVersion!: #VersionType
		fqn!:            #ContractFQNType
		description?:    string
		labels?:         #LabelsAnnotationsType
		annotations?:    #LabelsAnnotationsType
	}

	// Matching identity, unified wholesale into the aspect that attaches
	// this trait; the keys a #ModuleTransformer selects on. Never rendered.
	matchLabels?: #LabelsAnnotationsType

	// OQ13: how a declaration-only module trait (consumed outside the render
	// path, such as `offering` or `lifecycle`) states this, given "provider"
	// demands a transformer on the platform.
	fulfilment: *"catalog" | "provider"

	// Stated by the declaring catalog as a default, narrowed at the
	// attachment site, never pinned (the #Trait rule, unchanged).
	optional: bool

	// One key, the camelCase of the trait's name; the real definition
	// computes the key. Reduced to top here: a pattern constraint would
	// reopen the aspect's closed spec.
	spec!: _
}

#ModuleTraitMap: [#ContractFQNType]: #ModuleTrait

// ─── NEW: #Aspect, a named bundle of module traits on #Module (D11) ─────────

// #Aspect: #Component transposed to module scope. What carries over: the
// resourceName cascade, the derived matchLabels and its enforcement, the
// injected instance identity, the closed spec the author makes concrete.
// What is dropped: #resources and #blueprints (a resource is a workload
// demand, 0010 D28), #nameConstraint, and the DNS variants of #names. What
// is required instead: at least one trait.
#Aspect: {
	kind: "Aspect"

	metadata: {
		name!: #NameType

		// Defaults to the instance-qualified name; an explicit value must be
		// a DNS subdomain (the #Component cascade, 0019 D16/D20).
		resourceName: *"\(#instance.name)-\(name)" | #ObjectNameType

		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// The module traits this aspect attaches, keyed by contract FQN. At least
	// one is required; the check sits on #Module's #aspects pattern
	// constraint, because the bare definition has no entries and an
	// unconditional len() check here would refuse #Aspect itself.
	#traits: #ModuleTraitMap

	// The wholesale unification of every attached trait's matchLabels; the
	// provenance of the public field, which IS this value.
	_matchLabelsFromTraits: {
		for _, t in #traits {
			if t.matchLabels != _|_ {t.matchLabels}
		}
	}
	matchLabels: _matchLabelsFromTraits

	// matchLabels is DERIVED: a size difference is exactly "this aspect
	// contributed a key of its own" (the #Component rule, 0010 D36).
	_matchLabelsAreDerived: len(matchLabels) == len(_matchLabelsFromTraits)
	_matchLabelsAreDerived: true

	// Injected by #Module's #aspects pattern constraint; never authored.
	#instance: #InstanceIdentity

	// resourceName only: an aspect renders no Service, so no DNS variants.
	#names: resourceName: metadata.resourceName

	_allFields: {
		for _, t in #traits {
			if t.spec != _|_ {t.spec}
		}
	}

	// The fields the attached traits expose, closed, made concrete by the
	// module author. Authored inside the module, so it may read #config and
	// #ctx.components.
	spec: close({
		_allFields
	})
}

// ─── NEW: #ModuleTransformer, renders an aspect (D13) ───────────────────────

// #ModuleTransformer: #ComponentTransformer transposed. Matching buckets are
// labels and module traits (no resource buckets); the transform takes the
// concrete module instance and ONE aspect; whole-module facts come through
// #moduleInstance.#module. Output is rendered resources and nothing else,
// and the transformer never sees rendered component output: one build.
#ModuleTransformer: {
	kind: "ModuleTransformer"

	metadata: {
		modulePath!:     #PackagePathType
		name!:           #NameType
		catalogVersion!: #VersionType
		fqn!:            #ImplFQNType
		description!:    string
		labels?:         #LabelsAnnotationsType
		annotations?:    #LabelsAnnotationsType
	}

	requiredLabels?: #LabelsAnnotationsType
	optionalLabels?: #LabelsAnnotationsType
	requiredTraits?: [#ContractFQNType]: #ModuleTrait
	optionalTraits?: [#ContractFQNType]: #ModuleTrait

	producesKinds?: [...string]

	#transform: {
		#moduleInstance: _ // fully concrete #ModuleInstance (0019 D3)

		#aspect: _ // validated by matching, not by the signature

		#context: {
			#moduleInstanceMetadata: {
				name:      #moduleInstance.metadata.name
				namespace: #moduleInstance.metadata.namespace
			}
			#aspectMetadata: {
				name: #aspect.metadata.name
				if #aspect.metadata.labels != _|_ {
					labels: #aspect.metadata.labels
				}
			}

			// The labels every rendered object carries: instance plus aspect.
			labels: {
				"module-instance.opmodel.dev/name": #moduleInstanceMetadata.name
				"aspect.opmodel.dev/name":          #aspectMetadata.name
			}
		}

		output: {...} | [...{...}]
	}
}

#ModuleTransformerMap: [#ImplFQNType]: #ModuleTransformer

// ─── CHANGED: #Catalog and #Platform carry module transformers (D14) ────────

// Reduced. The real #Catalog stamps modulePath / catalogVersion on every
// transformer entry; the pattern is the same for both maps.
#Catalog: {
	kind: "Catalog"
	metadata: name!:               #NameType
	#transformers: [#ImplFQNType]: _ // component transformers, unchanged
	#moduleTransformers: #ModuleTransformerMap
	...
}

// Reduced. The real #Platform derives a contract inventory over the folded
// transformers; under D14 that inventory covers module transformers and
// their required module traits too, so an unhandled aspect demand is
// reported or refused exactly as an unhandled component demand is.
#Platform: {
	kind: "Platform"
	#catalogs: [string]: {
		#catalog: #Catalog
		enabled:  bool | *true
	}
	#composedTransformers: {
		for _, e in #catalogs if e.enabled {
			for fqn, tf in e.#catalog.#transformers {(fqn): tf}
		}
	}
	#composedModuleTransformers: {
		for _, e in #catalogs if e.enabled {
			for fqn, tf in e.#catalog.#moduleTransformers {(fqn): tf}
		}
	}
	...
}
