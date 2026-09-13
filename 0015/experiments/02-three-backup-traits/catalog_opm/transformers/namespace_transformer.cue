package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1alpha1"
)

// NamespaceTransformer converts Namespaces resources to Kubernetes Namespaces.
// Names are emitted exactly as authored — namespaces are cluster-scoped
// identities referenced from outside the module (ModuleInstance.metadata,
// RBAC subjects, webhook clientConfigs), so prefixing is never useful.
#NamespaceTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "namespace-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/namespace-transformer@\(id.Version)"
		description:    "Converts Namespaces resources to Kubernetes Namespaces with exact names and user-label passthrough"

		labels: {
			"core.opmodel.dev/resource-category": "cluster"
			"core.opmodel.dev/resource-type":     "namespace"
		}
	}

	requiredLabels: {}

	// Required resources - Namespaces resource MUST be present
	requiredResources: {
		(res.#NamespacesResource.metadata.fqn): res.#NamespacesResource
	}

	optionalResources: {}
	requiredTraits: {}
	optionalTraits: {}

	producesKinds: ["Namespace"]

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		// Emit one K8s Namespace per entry in the component's namespaces map.
		output: [
			for _, ns in #component.spec.namespaces
			let _userLabels = [if ns.labels != _|_ {ns.labels}, {}][0] {
				apiVersion: "v1"
				kind:       "Namespace"
				metadata: {
					name: ns.name // exact — namespaces are externally referenced
					// Merge labels: context labels the user did not set, then
					// user labels (user wins on conflict, no unify clash).
					labels: {
						for k, v in #context.labels if _userLabels[k] == _|_ {(k): v}
						for k, v in _userLabels {(k): v}
					}
					if ns.annotations != _|_ {
						annotations: ns.annotations
					}
				}
			},
		]
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

_testNamespacesComponent: res.#Namespaces & {
	spec: namespaces: {
		// Privileged namespace: PSS labels must survive and win over context.
		"metallb-system": {
			labels: {
				"pod-security.kubernetes.io/enforce": "privileged"
				"pod-security.kubernetes.io/audit":   "privileged"
				"pod-security.kubernetes.io/warn":    "privileged"
				// Deliberately collides with the stub context label below —
				// the golden output asserts the user value wins.
				"app.kubernetes.io/name": "metallb"
			}
		}
		// Bare namespace: exact name, context labels only, no annotations.
		"cert-manager": {}
	}
}

_testNamespacesTransformer: (#NamespaceTransformer.#transform & {
	#component: _testNamespacesComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "test-instance"
			namespace: "metallb-system"
			fqn:       "opmodel.dev/catalogs/opm/test-instance@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: {
			name: "namespace"
		}
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// Golden fixtures — cue vet fails on any drift, not just schema errors.
_testNamespacesTransformer: [
	{
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			name: "metallb-system"
			labels: {
				"app.kubernetes.io/managed-by":       "opm-test"
				"app.kubernetes.io/instance":         "namespace"
				"module-instance.opmodel.dev/name":   "test-instance"
				"pod-security.kubernetes.io/enforce": "privileged"
				"pod-security.kubernetes.io/audit":   "privileged"
				"pod-security.kubernetes.io/warn":    "privileged"
				// User value wins over the context's component-derived name.
				"app.kubernetes.io/name": "metallb"
			}
		}
	},
	{
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: {
			name: "cert-manager"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"app.kubernetes.io/instance":       "namespace"
				"app.kubernetes.io/name":           "namespace"
				"module-instance.opmodel.dev/name": "test-instance"
			}
		}
	},
]
