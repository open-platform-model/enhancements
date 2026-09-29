package core

import (
	"strings"

	cue_uuid "uuid"
)

// #Module: The portable application blueprint created by developers and/or platform teams
#Module: {
	kind: "Module"

	metadata: {
		// name: snake_case, and the leaf of modulePath (enhancement 0010 D8).
		// A module name has ONE spelling: it is the CUE package name, the
		// registry-path leaf and the value in the module.opmodel.dev/name
		// label, and package names cannot contain hyphens. The kebab-case
		// #NameType stays on #Resource / #Trait / #Blueprint, which are not
		// CUE packages.
		name!: #SnakeNameType // Example: "example_module"

		modulePath!: #ModulePathType // Example: "example.com/modules/example_module@v1" (author-supplied in module.cue)
		version!:    #VersionType    // Example: "0.1.0" (author-supplied in module.cue)

		// The one decomposition of modulePath. registryPath is the OCI
		// repository (major stripped); major is read from the path.
		_ref: #ArtifactRef & {"modulePath": modulePath}

		// fqn IS the module path (D1) — nothing is recombined, and neither
		// `name` nor `version` is interpolated into it. Artifact identity
		// therefore distinguishes majors and nothing finer: @v2 and @v3 are
		// distinct modules under both CUE and Go semantics, while every
		// release inside a major shares one fqn.
		fqn: #ModulePathType & modulePath // Example: "example.com/modules/example_module@v1"

		// registryPath: the major-free identity of the module lineage (D41).
		// #ModuleInstance derives its own fqn from THIS rather than from fqn,
		// so instance identity survives a major bump; it is also the OCI
		// repository every address-composition site in `cli` and `library`
		// collapses into.
		registryPath: _ref.registryPath // Example: "example.com/modules/example_module"

		// The path's leaf MUST be the module's name (D8). Hidden, because it
		// is a check rather than a value a consumer reads. Only the LEAF is
		// constrained: CUE accepts hyphens in path segments, and narrowing the
		// whole path would make OPM unable to express its own organisation
		// (github.com/open-platform-model/...).
		_leaf: strings.HasSuffix(_ref.registryPath, "/"+name)
		_leaf: true

		// NO versionMajor field and NO assertion that `version`'s major equals
		// the path's — deliberately, per D45 (transposing D43 from #Catalog).
		// Its absence is specified, not forgotten. `identity/identity.cue`
		// asserts VersionMajor == Major at the point both values are WRITTEN,
		// so a failure names the file the author has open; `core` re-deriving
		// it one hop downstream tests the same relation over the same two
		// values. `core` cannot read id.VersionMajor directly — it cannot
		// import a consumer's identity package.
		//
		// ACCEPTED EXPOSURE: a module whose identity package is absent or
		// non-conformant carries no consumer-runnable major check. Bounded by
		// enhancement 0011 D8/D12/D21 at publish.

		// Unique identifier for the module, computed as a UUID v5 (SHA1) of the FQN using the OPM namespace UUID.
		// The formula is unchanged; its input is the module path, so a uuid
		// moves on a major bump and on nothing else.
		uuid: #UUIDType & cue_uuid.SHA1(OPMNamespace, fqn)

		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType

		labels: {
			// Standard labels for module identification
			"module.opmodel.dev/name":    "\(name)"
			"module.opmodel.dev/version": "\(version)"
			"module.opmodel.dev/uuid":    "\(uuid)"
		}
		annotations: {
			// Standard annotations for module metadata
			"module.opmodel.dev/default-namespace"?: string
		}
	}

	// Components defined in this module (developer-defined, required. May be added
	// to by the platform-team). The pattern constraint wires the module-level
	// instance into every component so each component computes its own #names
	// from a shared instance identity (enhancement 0001 D3).
	#components: [Id=#NameType]: #Component & {
		metadata: {
			name: string | *Id
			labels: "component.opmodel.dev/name": name
		}
		// Was: #release: #ctx.release (renamed in enhancement 0002)
		#instance: #ctx.instance
	}

	// Value schema - constraints and defaults.
	// Developers define the configuration contract and reference it in their components.
	// MUST be OpenAPIv3 compliant (no CUE templating - for/if statements)
	#config: _

	// debugValues: Example values for testing and debugging.
	// It is unified and validated in the runtime
	debugValues: _

	// Inline runtime context channel. Open at the top level (`...`) so future
	// enhancements can add `platform` / `environment` siblings without breaking
	// module bodies. Introduced by enhancement 0001 (D1).
	//
	// `instance` is set by #ModuleInstance from its own metadata. `components`
	// is a pure CUE projection over every component's #names — components are
	// the single source of truth for their own identity; #ctx.components only
	// mirrors them (D2).
	#ctx: {
		// Was: release: #ReleaseIdentity (renamed in enhancement 0002)
		instance: #InstanceIdentity

		components: {
			for id, c in #components {
				(id): c.#names
			}
		}

		...
	}
}

#ModuleMap: [string]: #Module
