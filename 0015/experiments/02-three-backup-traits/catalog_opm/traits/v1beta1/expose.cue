package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#ExposeTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "expose"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/expose@v1beta1"
		description:    "A trait to expose a workload via a service"
		labels: {
			"trait.opmodel.dev/category": "network"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	// The Service name is the first label of every FQDN that reaches it, and
	// the API server validates it as DNS-1035 (alphabetic first rune, no dots,
	// 63 runes). Declared here so a metadata.resourceName override that a
	// Service cannot carry refuses at vet (0019 D21).
	#nameConstraint: c.#ServiceNameType

	spec: expose: #ExposeSchema
}

// Component wrapper: attaches the trait and supplies the Service name's
// default, the component's own short DNS name (0019 D22). The default can
// only live here: #ExposeSchema has no path to the owning component, and
// this is the one site where #names is in scope.
#Expose: c.#Component & {
	// Re-declared on purpose. `#names` from the embedded #Component is NOT in
	// lexical scope inside this literal (measured: `reference "#names" not
	// found`), the same rule the catalog's #transform slots follow; declaring
	// the slot makes the reference resolve, and unification makes it the same
	// value core computes.
	#names: _

	#traits: (#ExposeTrait.metadata.fqn): #ExposeTrait

	spec: expose: name: *#names.dns.short | c.#ServiceNameType
}

// Service expose specification.
#ExposeSchema: {
	ports: [portName=string]: res.#PortSchema & {name: portName}
	type: "ClusterIP" | "NodePort" | "LoadBalancer"

	// clusterIP pins the Service's cluster IP. The only supported value is
	// "None", which makes the Service headless: no virtual IP is allocated and
	// DNS resolves directly to the backing pods. This is the idiomatic governing
	// Service for a StatefulSet's stable per-pod network identity. Omit for a
	// normal virtual-IP Service. Only meaningful with type "ClusterIP".
	clusterIP?: "None"

	// WHY: The #Expose wrapper defaults it to the
	// component's `#names.dns.short`, the instance-scoped
	// {instance}-{component} every default-named object already carries, so
	// by default the Service, the workload and the DNS projection agree by
	// construction. Attaching #ExposeTrait without the wrapper leaves it unset
	// and refuses at vet: a Service can never render unnamed.
	//
	// An explicit value renames the Service ONLY: the workload keeps
	// metadata.resourceName and `#names.dns.*` follows the workload, not the
	// Service. Only correct when the name is a contract with something
	// OUTSIDE the module, a well-known in-cluster DNS identity (istiod's
	// `istiod.<ns>.svc`, which its webhook configs, CA clients and proxies all
	// hard-code). Exact names are not instance-safe: two instances of the
	// same module in one namespace would collide, so the default stays
	// prefixed. To give the workload, the Service and the projection one
	// exact name, set metadata.resourceName instead; Expose's #nameConstraint
	// admits it when it is DNS-1035-shaped.

	// The Service's name: the ONE field the Service transformer reads, with
	// no fallback (0019 D22). Required (`!`: a plain typed field would vet
	// clean while unset) and DNS-1035 typed, so a dot or a leading digit
	// refuses at vet. Defaulted by the #Expose wrapper; an explicit value
	// renames the Service only. See docs/name-constraints.md.
	name!: c.#ServiceNameType
}
