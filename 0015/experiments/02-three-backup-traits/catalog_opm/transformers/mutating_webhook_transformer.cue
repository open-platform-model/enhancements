package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1alpha1"
)

// MutatingWebhookTransformer converts MutatingWebhooks resources to
// Kubernetes MutatingWebhookConfigurations. Names are emitted exactly as
// authored — external controllers (istiod, cert-manager cainjector) reference
// and patch these cluster-scoped objects by name.
#MutatingWebhookTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "mutating-webhook-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/mutating-webhook-transformer@\(id.Version)"
		description:    "Converts MutatingWebhooks resources to Kubernetes MutatingWebhookConfigurations with exact names"

		labels: {
			"core.opmodel.dev/resource-category": "admission"
			"core.opmodel.dev/resource-type":     "mutating-webhooks"
		}
	}

	requiredLabels: {}

	// Required resources - MutatingWebhooks resource MUST be present
	requiredResources: {
		(res.#MutatingWebhooksResource.metadata.fqn): res.#MutatingWebhooksResource
	}

	optionalResources: {}
	requiredTraits: {}
	optionalTraits: {}

	producesKinds: ["MutatingWebhookConfiguration"]

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		// Emit one MutatingWebhookConfiguration per map entry.
		output: [
			for _, cfg in #component.spec.mutatingWebhooks
			let _userLabels = [if cfg.labels != _|_ {cfg.labels}, {}][0] {
				apiVersion: "admissionregistration.k8s.io/v1"
				kind:       "MutatingWebhookConfiguration"
				metadata: {
					name: cfg.name // exact — patched/referenced by name at runtime
					// Merge labels: context labels the user did not set, then
					// user labels (user wins on conflict, no unify clash).
					labels: {
						for k, v in #context.labels if _userLabels[k] == _|_ {(k): v}
						for k, v in _userLabels {(k): v}
					}
					if cfg.annotations != _|_ {
						annotations: cfg.annotations
					}
				}
				webhooks: cfg.webhooks
			},
		]
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

_testMutatingWebhooksComponent: res.#MutatingWebhooks & {
	spec: mutatingWebhooks: {
		// istiod patches this config's caBundle by exact name at runtime.
		// Exercises the mutating-only reinvocationPolicy plus both selectors.
		"istio-sidecar-injector": {
			webhooks: [{
				name: "rev.namespace.sidecar-injector.istio.io"
				clientConfig: service: {
					name:      "istiod"
					namespace: "istio-system"
					path:      "/inject"
					port:      443
				}
				rules: [{
					apiGroups: [""]
					apiVersions: ["v1"]
					operations: ["CREATE"]
					resources: ["pods"]
				}]
				failurePolicy: "Ignore"
				sideEffects:   "None"
				admissionReviewVersions: ["v1"]
				namespaceSelector: matchLabels: "istio-injection": "enabled"
				objectSelector: matchExpressions: [{
					key:      "sidecar.istio.io/inject"
					operator: "NotIn"
					values: ["false"]
				}]
				reinvocationPolicy: "Never"
				timeoutSeconds:     10
			}]
		}
	}
}

_testMutatingWebhooksTransformer: (#MutatingWebhookTransformer.#transform & {
	#component: _testMutatingWebhooksComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "test-instance"
			namespace: "istio-system"
			fqn:       "opmodel.dev/catalogs/opm/test-instance@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: {
			name: "webhooks"
		}
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// Golden fixture — cue vet fails on any drift, not just schema errors.
_testMutatingWebhooksTransformer: [
	{
		apiVersion: "admissionregistration.k8s.io/v1"
		kind:       "MutatingWebhookConfiguration"
		metadata: {
			name: "istio-sidecar-injector"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"app.kubernetes.io/instance":       "webhooks"
				"app.kubernetes.io/name":           "webhooks"
				"module-instance.opmodel.dev/name": "test-instance"
			}
		}
		webhooks: [{
			name: "rev.namespace.sidecar-injector.istio.io"
			clientConfig: service: {
				name:      "istiod"
				namespace: "istio-system"
				path:      "/inject"
				port:      443
			}
			rules: [{
				apiGroups: [""]
				apiVersions: ["v1"]
				operations: ["CREATE"]
				resources: ["pods"]
			}]
			failurePolicy: "Ignore"
			sideEffects:   "None"
			admissionReviewVersions: ["v1"]
			namespaceSelector: matchLabels: "istio-injection": "enabled"
			objectSelector: matchExpressions: [{
				key:      "sidecar.istio.io/inject"
				operator: "NotIn"
				values: ["false"]
			}]
			reinvocationPolicy: "Never"
			timeoutSeconds:     10
		}]
	},
]
