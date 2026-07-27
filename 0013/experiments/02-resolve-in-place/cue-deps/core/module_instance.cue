package core

import (
	cue_uuid "uuid"
)

// #ModuleInstance: The concrete deployment instance
// Contains: Reference to Module, values, target namespace
// Users/deployment systems create this to deploy a specific version
//
// Was: #ModuleRelease (renamed in enhancement 0002)
#ModuleInstance: {
	kind: "ModuleInstance"

	metadata: {
		name!:      #NameType
		namespace!: #NameType // Required for instances (target environment)

		// Cluster DNS domain. Defaults to "cluster.local"; override per instance
		// when the target cluster runs a non-standard domain. Surfaced into
		// every component's #names.dns.fqdn via #module.#ctx.instance.
		clusterDomain: string | *"cluster.local"

		// Generate a stable UUID for this instance based on the module's UUID, name, and namespace
		uuid: #UUIDType & cue_uuid.SHA1(OPMNamespace, "\(#moduleMetadata.uuid):\(name):\(namespace)")

		labels?: #LabelsAnnotationsType
		labels?: {if #moduleMetadata.labels != _|_ {#moduleMetadata.labels}}
		labels: {
			// Standard labels for module instance identification
			"module-instance.opmodel.dev/name": "\(name)"
			"module-instance.opmodel.dev/uuid": "\(uuid)"
		}

		annotations?: #LabelsAnnotationsType
		annotations?: {if #moduleMetadata.annotations != _|_ {#moduleMetadata.annotations}}

	}

	// Reference to the Module to deploy. The #ctx.instance wiring sets the
	// module's runtime context from this instance's metadata — every #Component
	// in #module receives this instance identity via the module's #components
	// pattern constraint, so #names + DNS variants flow through automatically.
	// Introduced by enhancement 0001 (D1, D4).
	#module!: #Module & {
		#ctx: instance: {
			name:          metadata.name
			namespace:     metadata.namespace
			uuid:          metadata.uuid
			clusterDomain: metadata.clusterDomain
		}
	}
	#moduleMetadata: #module.metadata

	let unifiedModule = #module & {#config: values}

	// components are the module's own components, verbatim.
	//
	// Core no longer injects an `opm-secrets` component for configs carrying
	// #Secret fields. Transformer matching is by exact resource FQN, and a
	// catalog's FQN embeds that catalog's version — a value core cannot know
	// and must not hardcode, so the injected component matched no transformer
	// on the v1 line and failed the render outright. A module with secrets
	// declares a secrets component against its own catalog's #Secrets resource
	// (catalogs re-export #AutoSecrets for the discovery half).
	components: {
		for name, comp in unifiedModule.#components {
			(name): comp
		}
	}

	// Concrete values (everything closed/concrete)
	// Must satisfy the #config from #module
	values: _
}

// Was: #ModuleReleaseMap (renamed in enhancement 0002)
#ModuleInstanceMap: [string]: #ModuleInstance
