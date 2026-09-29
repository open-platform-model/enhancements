package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
)

// WHY: Modelled as a TRAIT on the workload rather than a standalone resource, and
// that is forced by how selectors work: a NetworkPolicy's `podSelector` has to
// match the workload's rendered pod labels, which only a transformer knows
// (#context.componentLabels). A standalone resource would have to be told the
// selector by hand, and any drift between it and the workload's actual labels
// produces a policy that silently selects nothing — i.e. no protection, with no
// error anywhere.
//
// Ported from catalog_opm_experimental, where it could not be used. A trait
// defined in a foreign CUE module cannot be attached to a component built from
// a blueprint that lives here: the blueprint's `spec: close({_allFields})`
// rejects the contributed field outright ("field not allowed"). Cross-catalog
// matching is fine — it is CUE closedness, not OPM, that refuses. The general
// rule this establishes: a standalone RESOURCE may incubate in the experimental
// catalog, but a TRAIT that has to ride a stable blueprint must live here.

// #NetworkPolicyTrait attaches an ingress/egress policy to a workload.
#NetworkPolicyTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "network-policy"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/network-policy@v1beta1"
		description:    "Ingress and egress network policy for a workload's pods"
		labels: {
			"trait.opmodel.dev/category": "network"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	spec: networkPolicy: #NetworkPolicySchema
}

#NetworkPolicy: c.#Component & {
	#traits: (#NetworkPolicyTrait.metadata.fqn): #NetworkPolicyTrait
}

#NetworkPolicySchema: {
	// Which directions this policy governs. Naming a direction with no matching
	// rule DENIES all traffic in that direction — "Egress" with no `egress`
	// entries is a deny-all-egress policy, not a no-op.
	policyTypes: [...("Ingress" | "Egress")] | *["Ingress"]

	ingress?: [...#NetworkPolicyIngressRule]
	egress?: [...#NetworkPolicyEgressRule]
}

// An empty rule (`{}`) means "allow all in this direction" — the idiom istiod
// uses for egress, because features like JWKS resolution need to reach
// user-defined endpoints.
#NetworkPolicyIngressRule: {
	ports?: [...#NetworkPolicyPort]
	from?: [...#NetworkPolicyPeer]
}

#NetworkPolicyEgressRule: {
	ports?: [...#NetworkPolicyPort]
	to?: [...#NetworkPolicyPeer]
}

#NetworkPolicyPort: {
	protocol?: "TCP" | "UDP" | "SCTP"
	port?:     int & >=1 & <=65535
	endPort?:  int & >=1 & <=65535
}

#NetworkPolicyPeer: {
	podSelector?: {...}
	namespaceSelector?: {...}
	ipBlock?: {
		cidr!: string
		except?: [...string]
	}
}
