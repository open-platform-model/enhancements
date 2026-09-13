package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1alpha1"
)

// ValidatingWebhookTransformer converts ValidatingWebhooks resources to
// Kubernetes ValidatingWebhookConfigurations. Names are emitted exactly as
// authored — external controllers (istiod, cert-manager cainjector) reference
// and patch these cluster-scoped objects by name.
#ValidatingWebhookTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "validating-webhook-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/validating-webhook-transformer@\(id.Version)"
		description:    "Converts ValidatingWebhooks resources to Kubernetes ValidatingWebhookConfigurations with exact names"

		labels: {
			"core.opmodel.dev/resource-category": "admission"
			"core.opmodel.dev/resource-type":     "validating-webhooks"
		}
	}

	requiredLabels: {}

	// Required resources - ValidatingWebhooks resource MUST be present
	requiredResources: {
		(res.#ValidatingWebhooksResource.metadata.fqn): res.#ValidatingWebhooksResource
	}

	optionalResources: {}
	requiredTraits: {}
	optionalTraits: {}

	producesKinds: ["ValidatingWebhookConfiguration"]

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		// Emit one ValidatingWebhookConfiguration per map entry.
		output: [
			for _, cfg in #component.spec.validatingWebhooks
			let _userLabels = [if cfg.labels != _|_ {cfg.labels}, {}][0] {
				apiVersion: "admissionregistration.k8s.io/v1"
				kind:       "ValidatingWebhookConfiguration"
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

_testValidatingWebhooksComponent: res.#ValidatingWebhooks & {
	spec: validatingWebhooks: {
		// istiod patches this config's caBundle by exact name at runtime.
		"istio-validator-istio-system": {
			webhooks: [{
				name: "rev.validation.istio.io"
				clientConfig: service: {
					name:      "istiod"
					namespace: "istio-system"
					path:      "/validate"
					port:      443
				}
				rules: [{
					apiGroups: ["security.istio.io", "networking.istio.io", "telemetry.istio.io", "extensions.istio.io"]
					apiVersions: ["*"]
					operations: ["CREATE", "UPDATE"]
					resources: ["*"]
				}]
				failurePolicy: "Ignore"
				sideEffects:   "None"
				admissionReviewVersions: ["v1"]
				timeoutSeconds: 10
			}]
		}
		// cert-manager keeps upstream labels + the cainjector annotation.
		"cert-manager-webhook": {
			labels: {
				app:                           "webhook"
				"app.kubernetes.io/name":      "webhook"
				"app.kubernetes.io/instance":  "cert-manager"
				"app.kubernetes.io/component": "webhook"
				"app.kubernetes.io/version":   "v1.21.0"
			}
			annotations: {
				"cert-manager.io/inject-ca-from-secret": "cert-manager/cert-manager-webhook-ca"
			}
			webhooks: [{
				name: "webhook.cert-manager.io"
				clientConfig: service: {
					name:      "cert-manager-webhook"
					namespace: "cert-manager"
					path:      "/validate"
				}
				rules: [{
					apiGroups: ["cert-manager.io", "acme.cert-manager.io"]
					apiVersions: ["v1"]
					operations: ["CREATE", "UPDATE"]
					resources: ["*/*"]
				}]
				failurePolicy: "Fail"
				matchPolicy:   "Equivalent"
				sideEffects:   "None"
				admissionReviewVersions: ["v1"]
				namespaceSelector: matchExpressions: [{
					key:      "cert-manager.io/disable-validation"
					operator: "NotIn"
					values: ["true"]
				}]
				timeoutSeconds: 30
			}]
		}
	}
}

_testValidatingWebhooksTransformer: (#ValidatingWebhookTransformer.#transform & {
	#component: _testValidatingWebhooksComponent
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

// Golden fixtures — cue vet fails on any drift, not just schema errors.
_testValidatingWebhooksTransformer: [
	{
		apiVersion: "admissionregistration.k8s.io/v1"
		kind:       "ValidatingWebhookConfiguration"
		metadata: {
			name: "istio-validator-istio-system"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"app.kubernetes.io/instance":       "webhooks"
				"app.kubernetes.io/name":           "webhooks"
				"module-instance.opmodel.dev/name": "test-instance"
			}
		}
		webhooks: [{
			name: "rev.validation.istio.io"
			clientConfig: service: {
				name:      "istiod"
				namespace: "istio-system"
				path:      "/validate"
				port:      443
			}
			rules: [{
				apiGroups: ["security.istio.io", "networking.istio.io", "telemetry.istio.io", "extensions.istio.io"]
				apiVersions: ["*"]
				operations: ["CREATE", "UPDATE"]
				resources: ["*"]
			}]
			failurePolicy: "Ignore"
			sideEffects:   "None"
			admissionReviewVersions: ["v1"]
			timeoutSeconds: 10
		}]
	},
	{
		apiVersion: "admissionregistration.k8s.io/v1"
		kind:       "ValidatingWebhookConfiguration"
		metadata: {
			name: "cert-manager-webhook"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"module-instance.opmodel.dev/name": "test-instance"
				// User-supplied labels win over the context's component-derived
				// name/instance values.
				app:                           "webhook"
				"app.kubernetes.io/name":      "webhook"
				"app.kubernetes.io/instance":  "cert-manager"
				"app.kubernetes.io/component": "webhook"
				"app.kubernetes.io/version":   "v1.21.0"
			}
			annotations: {
				"cert-manager.io/inject-ca-from-secret": "cert-manager/cert-manager-webhook-ca"
			}
		}
		webhooks: [{
			name: "webhook.cert-manager.io"
			clientConfig: service: {
				name:      "cert-manager-webhook"
				namespace: "cert-manager"
				path:      "/validate"
			}
			rules: [{
				apiGroups: ["cert-manager.io", "acme.cert-manager.io"]
				apiVersions: ["v1"]
				operations: ["CREATE", "UPDATE"]
				resources: ["*/*"]
			}]
			failurePolicy: "Fail"
			matchPolicy:   "Equivalent"
			sideEffects:   "None"
			admissionReviewVersions: ["v1"]
			namespaceSelector: matchExpressions: [{
				key:      "cert-manager.io/disable-validation"
				operator: "NotIn"
				values: ["true"]
			}]
			timeoutSeconds: 30
		}]
	},
]
