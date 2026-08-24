// Copy of experiment 09's #Component (D20 ceiling + D21 propagation), with
// ONE addition needed to model a trait spec: `spec` is the union of every
// attached trait's spec, the way core's _allFields builds it
// (core/src/component.cue). Nothing else changed.
package e0019x10

#Trait: {
	kind: "Trait"
	metadata: name!: #NameType
	#nameConstraint: _
	spec?: {...}
	...
}

#Resource: {
	kind: "Resource"
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
		resourceName: *("\(#instance.name)-\(name)" & #ObjectNameType) | #ObjectNameType
	}
	#resources: [string]: #Resource
	#traits?: [string]:   #Trait

	for _, r in #resources {
		metadata: resourceName: r.#nameConstraint
	}
	if #traits != _|_ {
		for _, t in #traits {
			metadata: resourceName: t.#nameConstraint
		}
	}

	// ADDED: the trait specs land on the component, as in core's _allFields.
	spec: {
		if #traits != _|_ {
			for _, t in #traits if t.spec != _|_ {t.spec}
		}
	}

	#instance: #InstanceIdentity
	#names: {
		resourceName: metadata.resourceName
		dns: {
			short: resourceName
			local: "\(resourceName).\(#instance.namespace)"
			fqdn:  "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
		}
	}
}

#ContainerResource: #Resource & {metadata: name: "container"}
