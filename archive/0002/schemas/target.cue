// Target schema for enhancement 0002 — Rename the Release artifact family to
// Instance vocabulary (cross-cutting: core, library, opm-operator, cli).
//
// This is a self-contained SKETCH of the renamed surface. It does not import
// opmodel.dev/core (per the "copy, never reference" rule); the field types are
// simplified stand-ins so the file compiles with `cue vet ./...`. The point is
// to fix the renamed identifier set and the resolved wire decisions (D2-D8),
// not to re-derive the full core constraints or the Go/CRD shapes.
//
// Mapping captured here (old -> new):
//   core CUE family
//     #ModuleRelease       -> #ModuleInstance
//     #ModuleReleaseMap    -> #ModuleInstanceMap
//     #ReleaseIdentity     -> #InstanceIdentity
//     #ctx.release         -> #ctx.instance
//     #Component.#release  -> #Component.#instance
//     #moduleRelease*      -> #moduleInstance*   (transformer context)
//   wire (D3, D4)
//     kind "ModuleRelease" -> "ModuleInstance"; "BundleRelease" -> "BundleInstance"
//     label module-release.opmodel.dev/* -> module-instance.opmodel.dev/*
//   operator CRDs (D2, D5)
//     ModuleRelease CRD    -> ModuleInstance     (kind)
//     Release (GitOps) CRD -> ModulePackage      (kind)
//     API group releases.opmodel.dev -> opmodel.dev
//   cli (D6, D7)
//     opm release ...      -> opm instance ...
//     BundleRelease        -> BundleInstance
package schema

// Simplified stand-ins for core primitive types (real ones live in core).
#NameType: string
#UUIDType: string

// The renamed API group (D5). Operator CRDs and the finalizer move here.
#APIGroup:      "opmodel.dev"
#FinalizerName: "opmodel.dev/cleanup"

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
	// D3: the wire discriminator moves to "ModuleInstance".
	kind: "ModuleInstance"

	metadata: {
		name!:         #NameType
		namespace!:    #NameType
		clusterDomain: string | *"cluster.local"
		uuid:          #UUIDType // SHA1(OPMNamespace, "\(module.uuid):\(name):\(namespace)") — unchanged

		labels?: {...}
		labels: {
			// D4: the label domain moves to module-instance.opmodel.dev.
			"module-instance.opmodel.dev/name":      "\(name)"
			"module-instance.opmodel.dev/namespace": "\(namespace)"
			"module-instance.opmodel.dev/uuid":      "\(uuid)"
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

// #BundleInstance — was #BundleRelease (D7). Many instances released together;
// recognized by the CLI kind-detection alongside #ModuleInstance.
#BundleInstance: {
	kind: "BundleInstance"
	metadata: {
		name!:      #NameType
		namespace!: #NameType
	}
	instances: #ModuleInstanceMap
}

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

// --- Operator CRD shape stand-ins (Go types live in opm-operator) ----------

// #ModuleInstanceCR — was the ModuleRelease CRD. Direct module-ref deployable
// reconciled in-cluster. Group moves to opmodel.dev (D5).
#ModuleInstanceCR: {
	apiVersion: "\(#APIGroup)/v1alpha1"
	kind:       "ModuleInstance"
	spec: {...}
	status: {
		instanceUUID?: #UUIDType // was ReleaseUUID
		...
	}
}

// #ModulePackageCR — was the GitOps Release CRD (D2). Points at a Flux source
// artifact; the reconciler renders it into a #ModuleInstance.
#ModulePackageCR: {
	apiVersion: "\(#APIGroup)/v1alpha1"
	kind:       "ModulePackage"
	spec: {
		sourceRef: {...}
		path!:     string
		...
	}
	status: {...}
}
