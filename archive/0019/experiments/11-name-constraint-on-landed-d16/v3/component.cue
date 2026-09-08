package e0019x11v3

// Variant 2: constraints are COLLECTED into a hidden slot and ASSERTED on a
// hidden field, never unified into metadata.resourceName. Keeps D16's
// invariant that the default arm is unvalidated (so resourceName is always
// concrete and the guards can run), and names the offending string.
#Resource: {kind: "Resource", metadata: name!: #NameType, #nameConstraint: _, ...}
#Trait: {kind: "Trait", metadata: name!: #NameType, #nameConstraint: _, ...}
#Blueprint: {kind: "Blueprint", metadata: name!: #NameType, #nameConstraint: _, ...}

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

	// The conjunction of every attached primitive's constraint; top when none.
	_nameConstraints: _
	for _, r in #resources {_nameConstraints: r.#nameConstraint}
	if #traits != _|_ {
		for _, t in #traits {_nameConstraints: t.#nameConstraint}
	}
	if #blueprints != _|_ {
		for _, b in #blueprints {_nameConstraints: b.#nameConstraint}
	}

	#instance: #InstanceIdentity

	_resourceNameDefault: "\(#instance.name)-\(metadata.name)"
	if metadata.resourceName == _resourceNameDefault && len(_resourceNameDefault) > 253 {
		_resourceNameDefaultFits: error("default resourceName \"\(_resourceNameDefault)\" is \(len(_resourceNameDefault)) runes, over the 253-rune limit")
	}

	// The assertion. resourceName is concrete here (default arm unvalidated,
	// override validated by #ObjectNameType), so the conjunction is either a
	// concrete string or an error naming the string and the bound.
	_nameFits: metadata.resourceName & _nameConstraints

	#names: {
		resourceName: metadata.resourceName
		dns: {
			short: resourceName
			local: "\(resourceName).\(#instance.namespace)"
			fqdn:  "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
		}
	}
}
