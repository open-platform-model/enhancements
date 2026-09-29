package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	k8scorev1 "opmodel.dev/catalogs/opm/schemas/kubernetes/core/v1"
)

// ConfigMapTransformer converts ConfigMaps resources to Kubernetes ConfigMaps.
// Supports immutable ConfigMaps with content-hash naming.
#ConfigMapTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "configmap-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/configmap-transformer@\(id.Version)"
		description:    "Converts ConfigMaps resources to Kubernetes ConfigMaps"

		labels: {
			"core.opmodel.dev/resource-category": "config"
			"core.opmodel.dev/resource-type":     "configmap"
		}
	}

	requiredLabels: {}

	// Required resources - ConfigMaps MUST be present
	requiredResources: {
		(res.#ConfigMapsResource.metadata.fqn): res.#ConfigMapsResource
	}

	optionalResources: {}
	requiredTraits: {}
	optionalTraits: {}

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		_configMaps: #component.spec.configMaps

		// Build the instance-scoped prefix: {instanceName}-{componentName}
		// The same prefix the secret-transformer uses, so all config resources
		// share the same namespace-isolation guarantee across instances.
		let _relName = #context.#moduleInstanceMetadata.name
		let _compName = #context.#componentMetadata.name

		// Emit one K8s ConfigMap per entry in the component's configMaps map.
		// Output is a list of resources; the renderer dispatches on cue.Kind
		// (see core's #ComponentTransformer output contract) and produces one
		// Compiled per list element.
		output: [
			for _, cm in _configMaps
			let _baseName = "\(_relName)-\(_compName)-\(cm.name)"
			// exactName renders the authored name verbatim (externally-referenced
			// well-known ConfigMaps); the schema forbids pairing it with
			// immutable, so the content-hash path is unreachable when it is set.
			let _k8sName = [
				if cm.exactName {cm.name},
				(res.#ImmutableName & {
					baseName:  _baseName
					data:      cm.data
					immutable: cm.immutable
				}).out,
			][0] {
				k8scorev1.#ConfigMap & {
					apiVersion: "v1"
					kind:       "ConfigMap"
					metadata: {
						name:      _k8sName
						namespace: #context.#moduleInstanceMetadata.namespace
						labels:    #context.labels
						if len(#context.componentAnnotations) > 0 {
							annotations: #context.componentAnnotations
						}
					}
					if cm.immutable == true {
						immutable: true
					}
					data: cm.data
				}
			},
		]
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// One component carrying both naming modes: `istio` is read by name from
// outside the module (istiod's mesh config), while `app-config` takes the
// default instance-scoped name.
_testConfigMapNamingComponent: res.#ConfigMaps & {
	spec: configMaps: {
		istio: {
			exactName: true
			data: mesh: "defaultConfig: {}"
		}
		"app-config": {
			data: "log-level": "info"
		}
	}
}

_testConfigMapNamingTransformer: (#ConfigMapTransformer.#transform & {
	#component: _testConfigMapNamingComponent
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

// Golden — exact name emitted verbatim; the default path keeps the
// {instance}-{component}-{name} prefix. Order follows declaration order.
_testConfigMapNamingTransformer: [
	{
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "istio"
			namespace: "istio-system"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"app.kubernetes.io/instance":       "istiod"
				"app.kubernetes.io/name":           "istiod"
				"module-instance.opmodel.dev/name": "istio"
			}
		}
		data: mesh: "defaultConfig: {}"
	},
	{
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "istio-istiod-app-config"
			namespace: "istio-system"
			labels: {
				"app.kubernetes.io/managed-by":     "opm-test"
				"app.kubernetes.io/instance":       "istiod"
				"app.kubernetes.io/name":           "istiod"
				"module-instance.opmodel.dev/name": "istio"
			}
		}
		data: "log-level": "info"
	},
]
