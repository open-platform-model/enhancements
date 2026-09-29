package v1alpha1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// Namespaces Resource
/////////////////////////////////////////////////////////////////

#NamespacesResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1alpha1"
		name:           "namespaces"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/namespaces@v1alpha1"
		description:    "Cluster namespaces owned by this module, emitted with exact names"
		labels: {
			"resource.opmodel.dev/category": "cluster"
		}
	}

	// A Namespace name is the second label of every in-cluster FQDN: no dots,
	// 63 runes (0019 D21). The names this resource RENDERS are the map
	// entries below, typed on #NamespaceSchema; this slot additionally holds
	// the owning component's metadata.resourceName to the same rule.
	#nameConstraint: c.#NameType

	// Alias must not be `name` — the inner field would shadow it and the
	// default becomes self-referential (cf. catalog_opm configmap.cue).
	spec: namespaces: [KeyName=string]: #NamespaceSchema & {name: string | *KeyName}
}

#Namespaces: c.#Component & {
	#resources: (#NamespacesResource.metadata.fqn): #NamespacesResource

	// WHY: Typing #NamespaceSchema.name itself is NOT an
	// option (measured, cue v0.17.1): the type unifies into the map default
	// `*KeyName`, a dotted key's default arm drops out, the field is left a
	// bare non-concrete #NameType, and nothing refuses at vet. The
	// interpolation forces the default to a string first, so
	// `string & #NameType` is either that string or an error naming it (the
	// 0019 D21 assertion spelling).

	// The rendered names are asserted here, on the component, because the
	// resource entry only ever holds the schema (values land on the
	// component's spec). `spec` is re-declared for lexical scope;
	// see docs/name-constraints.md.
	spec: _
	_namespaceNamesFit: [for _, ns in spec.namespaces {"\(ns.name)" & c.#NameType}]
}

/////////////////////////////////////////////////////////////////
//// Namespace Schema
/////////////////////////////////////////////////////////////////

// WHY: Namespaces are
// externally-referenced identities (ModuleInstances, RBAC subjects, webhook
// clientConfigs address them by name), so — like the stable catalog's
// #Role/#ServiceAccount/#CRDs — no prefixing is applied.

// Kubernetes Namespace, emitted with its exact name.
// `name` is auto-populated from the map key in the resource spec. It is a
// DNS label (0019 D21), asserted by the #Namespaces wrapper rather than typed
// here: a type on this field would silently kill the key default (see the
// wrapper). A dotted key or an explicit dotted name refuses at vet.
#NamespaceSchema: {
	name: string
	// Merged over context labels (user wins on conflict). This is how
	// Pod-Security labels reach clusters enforcing a baseline PSS, e.g.
	//   labels: "pod-security.kubernetes.io/enforce": "privileged"
	labels?: {[string]: string}
	annotations?: {[string]: string}
}
