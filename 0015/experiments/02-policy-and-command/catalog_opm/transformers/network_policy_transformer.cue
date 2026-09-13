package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// WHY: #context.componentLabels is computed by core per (component, transformer)
// pair, so the value here is the same one the Deployment / DaemonSet /
// StatefulSet transformer used for `spec.selector.matchLabels`. That is the
// whole reason this is a trait: the selector is derived, never authored, so it
// cannot drift from the pods it is meant to protect.

// NetworkPolicyTransformer converts the #NetworkPolicyTrait to a Kubernetes
// NetworkPolicy whose podSelector is the workload's own rendered pod labels.
#NetworkPolicyTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "network-policy-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/network-policy-transformer@\(id.Version)"
		description:    "Converts the NetworkPolicy trait to a Kubernetes NetworkPolicy selecting the workload's pods"

		labels: {
			"core.opmodel.dev/resource-type": "networkpolicy"
		}
	}

	requiredLabels: {}
	requiredResources: {}

	requiredTraits: {
		(tr.#NetworkPolicyTrait.metadata.fqn): tr.#NetworkPolicyTrait
	}

	optionalResources: {}
	optionalTraits: {}

	producesKinds: ["NetworkPolicy"]

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		_policy: #component.spec.networkPolicy

		output: {
			apiVersion: "networking.k8s.io/v1"
			kind:       "NetworkPolicy"
			metadata: {
				name:      #component.#names.resourceName
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
				if len(#context.componentAnnotations) > 0 {
					annotations: #context.componentAnnotations
				}
			}
			spec: {
				// Derived, never authored — see the note above.
				podSelector: matchLabels: #context.componentLabels
				policyTypes: _policy.policyTypes
				if _policy.ingress != _|_ {
					ingress: _policy.ingress
				}
				if _policy.egress != _|_ {
					egress: _policy.egress
				}
			}
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// Mirrors istiod's NetworkPolicy at Istio 1.30.3 with
// global.networkPolicy.enabled: webhook + xDS ingress ports, and an allow-all
// egress expressed as a single empty rule.
_testNetPolComponent: tr.#NetworkPolicy & {
	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: name: "istiod"

	spec: networkPolicy: {
		policyTypes: ["Ingress", "Egress"]
		ingress: [
			{ports: [{protocol: "TCP", port: 15017}]},
			{ports: [
				{protocol: "TCP", port: 15010},
				{protocol: "TCP", port: 15012},
				{protocol: "TCP", port: 8080},
				{protocol: "TCP", port: 15014},
			]},
		]
		egress: [{}]
	}
}

_testNetPolTransformer: (#NetworkPolicyTransformer.#transform & {
	#component: _testNetPolComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "istio"
			namespace: "istio-system"
			fqn:       "opmodel.dev/catalogs/opm/istio@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "istiod"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// The policy's own name follows the component's resourceName.
_testNetPolName: "\(_testNetPolTransformer.metadata.name)" & "istio-istiod"

// The selector must be exactly the context's component labels — this is what
// makes the policy track the workload's pods. Length is non-invertible, so a
// dropped or extra key cannot be repaired by the assertion.
_testNetPolSelectorSize: (len(_testNetPolTransformer.spec.podSelector.matchLabels) + 0) & 2

_testNetPolSelectorName: [
	if _testNetPolTransformer.spec.podSelector.matchLabels["app.kubernetes.io/name"] != _|_ {
		_testNetPolTransformer.spec.podSelector.matchLabels["app.kubernetes.io/name"]
	},
] & ["istiod"]

// An empty egress rule means allow-all. A naive `if len(x) > 0` guard anywhere
// in the chain would eat it and turn the policy into deny-all-egress, which
// would break istiod's JWKS resolution — so assert the rule survives.
_testNetPolEgressAllowAll: (len(_testNetPolTransformer.spec.egress) + 0) & 1

_testNetPolIngressRules: (len(_testNetPolTransformer.spec.ingress) + 0) & 2
_testNetPolPolicyTypes:  (len(_testNetPolTransformer.spec.policyTypes) + 0) & 2

// policyTypes must be carried through verbatim; naming a direction with no
// rules is a deny, so a dropped entry silently changes the policy's meaning.
_testNetPolTypesPresent: [
	if _testNetPolTransformer.spec.policyTypes != _|_ {_testNetPolTransformer.spec.policyTypes[1]},
] & ["Egress"]

// The blueprint-attachment test — the whole reason this trait was ported here —
// lives in blueprints/, because transformers does not import
// blueprints and should not start.
