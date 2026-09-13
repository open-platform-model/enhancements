package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	k8scorev1 "opmodel.dev/catalogs/opm/schemas/kubernetes/core/v1"
)

// WHY: The name is instance-scoped ({instance}-{component}-{name}) so two
// instances of the same module coexist in one namespace. #ImmutableName
// appends a content hash when the secret is immutable — the same name
// #ToK8sVolumes computes for an inline secret volume, so a volume resolves
// its object without extra wiring.

// SecretTransformer converts Secrets resources to Kubernetes Secrets.
// `data` is string-only and renders as stringData verbatim. The object is
// named {instance}-{component}-{name}, with a content-hash suffix appended
// when the secret is immutable.
#SecretTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "secret-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/secret-transformer@\(id.Version)"
		description:    "Converts Secrets resources to Kubernetes Secrets"

		labels: {
			"core.opmodel.dev/resource-category": "config"
			"core.opmodel.dev/resource-type":     "secret"
		}
	}

	requiredLabels: {}

	// Required resources - Secrets MUST be present
	requiredResources: {
		(res.#SecretsResource.metadata.fqn): res.#SecretsResource
	}

	optionalResources: {}
	requiredTraits: {}
	optionalTraits: {}

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		_secrets: #component.spec.secrets

		// Build the instance-scoped prefix: {instanceName}-{componentName}
		let _relName = #context.#moduleInstanceMetadata.name
		let _compName = #context.#componentMetadata.name

		// Emit one K8s Secret per entry in the component's secrets map.
		// Output is a list of resources; the renderer dispatches on cue.Kind
		// (see core's #ComponentTransformer output contract) and produces one
		// Compiled per list element.
		output: [
			for _, secret in _secrets
			let _k8sName = (res.#ImmutableName & {
				baseName:  "\(_relName)-\(_compName)-\(secret.name)"
				data:      secret.data
				immutable: secret.immutable
			}).out {
				k8scorev1.#Secret & {
					apiVersion: "v1"
					kind:       "Secret"
					metadata: {
						name:      _k8sName
						namespace: #context.#moduleInstanceMetadata.namespace
						labels:    #context.labels
						if len(#context.componentAnnotations) > 0 {
							annotations: #context.componentAnnotations
						}
					}
					type: secret.type
					if secret.immutable == true {
						immutable: true
					}
					stringData: secret.data
				}
			},
		]
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// One component carrying both naming modes: `api` is immutable and takes a
// content-hash suffix, `db` is mutable and keeps the stable name.
_testSecretNamingComponent: res.#Secrets & {
	spec: secrets: {
		api: {
			immutable: true
			data: token: "s3cr3t"
		}
		db: data: {
			username: "admin"
			password: "hunter2"
		}
	}
}

_testSecretNamingTransformer: (#SecretTransformer.#transform & {
	#component: _testSecretNamingComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "myapp"
			namespace: "myapp-system"
			fqn:       "opmodel.dev/catalogs/opm/myapp@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "mycomponent"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// Golden — an immutable secret carries the content-hash suffix
// (sha256("token=s3cr3t")[:5]), a mutable one keeps the stable name;
// stringData is the authored map verbatim. Order follows map key order.
_testSecretNamingTransformer: [
	{
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name:      "myapp-mycomponent-api-51ff59373f"
			namespace: "myapp-system"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"app.kubernetes.io/instance":       "mycomponent"
				"app.kubernetes.io/name":           "mycomponent"
				"module-instance.opmodel.dev/name": "myapp"
			}
		}
		type:      "Opaque"
		immutable: true
		stringData: token: "s3cr3t"
	},
	{
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name:      "myapp-mycomponent-db"
			namespace: "myapp-system"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"app.kubernetes.io/instance":       "mycomponent"
				"app.kubernetes.io/name":           "mycomponent"
				"module-instance.opmodel.dev/name": "myapp"
			}
		}
		type: "Opaque"
		stringData: {
			username: "admin"
			password: "hunter2"
		}
	},
]
