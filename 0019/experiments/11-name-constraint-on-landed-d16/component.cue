package e0019x11

// #Component under the LANDED D16 spelling (core/src/component.cue, PR 51)
// with D21's propagation comprehensions added. Differences from 09:
//   - default arm unvalidated, ceiling widened #NameType -> #ObjectNameType,
//     error() arm kept (D16's legible-refusal mechanism);
//   - _resourceNameDefault / _resourceNameDefaultFits copied from core, with
//     the bound raised to 253 (the D20 ceiling of the default branch).
#Resource: {
	kind: "Resource"
	metadata: name!: #NameType
	#nameConstraint: _
	...
}
#Trait: {
	kind: "Trait"
	metadata: name!: #NameType
	#nameConstraint: _
	...
}
#Blueprint: {
	kind: "Blueprint"
	metadata: name!: #NameType
	#nameConstraint: _
	...
}

#InstanceIdentity: {
	name!:         #NameType
	namespace!:    #NameType
	clusterDomain: string | *"cluster.local"
}

#Component: {
	kind: "Component"
	metadata: {
		name!: #NameType
		resourceName: *"\(#instance.name)-\(name)" | #ObjectNameType | error("resourceName \"\(resourceName)\" is not a DNS subdomain (lowercase alphanumerics, hyphens and dots, 1-253 runes)")
	}
	#resources: [string]: #Resource
	#traits?: [string]:   #Trait
	#blueprints?: [string]: #Blueprint

	for _, r in #resources {
		metadata: resourceName: r.#nameConstraint
	}
	if #traits != _|_ {
		for _, t in #traits {
			metadata: resourceName: t.#nameConstraint
		}
	}
	if #blueprints != _|_ {
		for _, b in #blueprints {
			metadata: resourceName: b.#nameConstraint
		}
	}

	#instance: #InstanceIdentity

	_resourceNameDefault: "\(#instance.name)-\(metadata.name)"
	if metadata.resourceName == _resourceNameDefault && len(_resourceNameDefault) > 253 {
		_resourceNameDefaultFits: error("default resourceName \"\(_resourceNameDefault)\" is \(len(_resourceNameDefault)) runes, over the 253-rune limit")
	}

	#names: {
		resourceName: metadata.resourceName
		dns: {
			short: resourceName
			local: "\(resourceName).\(#instance.namespace)"
			fqdn:  "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
		}
	}
}
