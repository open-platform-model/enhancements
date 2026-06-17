// Target schema for enhancement 0002 — Rename #ModuleRelease to #ModuleInstance.
//
// This is a self-contained SKETCH of the renamed `core` surface. It does not
// import opmodel.dev/core (per the "copy, never reference" rule); the field
// types are simplified stand-ins so the file compiles with `cue vet ./...`.
// The point is to fix the renamed identifier set and the OQ-gated wire
// decisions, not to re-derive the full core constraints.
//
// Mapping captured here (old -> new):
//   #ModuleRelease       -> #ModuleInstance
//   #ModuleReleaseMap    -> #ModuleInstanceMap
//   #ReleaseIdentity     -> #InstanceIdentity
//   #ctx.release         -> #ctx.instance
//   #Component.#release  -> #Component.#instance
//   #moduleRelease*      -> #moduleInstance*   (transformer context)
package schema

// Simplified stand-ins for core primitive types (real ones live in core).
#NameType: string
#UUIDType: string

// #InstanceIdentity — was #ReleaseIdentity. Deployment-scoped facts that drive
// per-component naming and DNS. Field set is unchanged from the original.
#InstanceIdentity: {
	name!:         #NameType
	namespace!:    #NameType
	uuid!:         #UUIDType
	clusterDomain: string | *"cluster.local"
}

// Per-component projection of the instance identity — was #Component.#release.
#Component: {
	metadata: {
		resourceName!: #NameType
	}
	#instance: #InstanceIdentity
	#names: {
		resourceName!: #NameType
		dns: {
			short!: string
			local!: string // "\(resourceName).\(#instance.namespace)"
			fqdn!:  string // "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
		}
	}
}

// Module runtime context slot — was #ctx.release.
#Module: {
	#ctx: {
		instance: #InstanceIdentity
		...
	}
	...
}

// #ModuleInstance — was #ModuleRelease. The concrete deployment instance:
// a #Module + concrete values + target namespace.
#ModuleInstance: {
	// OQ1: does the wire discriminator move to "ModuleInstance"? Default (shown)
	// is yes; the core-isolation alternative keeps "ModuleRelease" here while the
	// definition is named #ModuleInstance (a deliberate split — see 05-risks).
	kind: "ModuleInstance"

	metadata: {
		name!:         #NameType
		namespace!:    #NameType
		clusterDomain: string | *"cluster.local"
		uuid:          #UUIDType // SHA1(OPMNamespace, "\(module.uuid):\(name):\(namespace)") — unchanged

		labels?: {...}
		labels: {
			// OQ2: does the label domain move to module-instance.opmodel.dev?
			// Default (shown) is yes; tied to OQ1's resolution.
			"module-instance.opmodel.dev/name": "\(name)"
			"module-instance.opmodel.dev/uuid": "\(uuid)"
		}
	}

	#module!: #Module & {
		#ctx: instance: {
			name:          metadata.name
			namespace:     metadata.namespace
			uuid:          metadata.uuid
			clusterDomain: metadata.clusterDomain
		}
	}

	values: _
}

// #ModuleInstanceMap — was #ModuleReleaseMap.
#ModuleInstanceMap: [string]: #ModuleInstance

// Transformer context — was #moduleRelease / #moduleReleaseMetadata.
#ComponentTransformer: {
	#moduleInstance: _ // fully concrete #ModuleInstance
	#moduleInstanceMetadata: {
		name?:        #NameType
		labels?:      {...}
		annotations?: {...}
		...
	}
	...
}
