package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	k8scorev1 "opmodel.dev/catalogs/opm/schemas/kubernetes/core/v1"
)

// PVCTransformer creates standalone PersistentVolumeClaims from Volume resources
#PVCTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "pvc-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/pvc-transformer@\(id.Version)"
		description:    "Creates standalone Kubernetes PersistentVolumeClaims from Volume resources"

		labels: {
			"core.opmodel.dev/resource-category": "storage"
			"core.opmodel.dev/resource-type":     "persistentvolumeclaim"
		}
	}

	requiredLabels: {} // No specific labels required; matches any component with Volumes resource

	// Required resources - Volumes MUST be present
	requiredResources: {
		(res.#VolumesResource.metadata.fqn): res.#VolumesResource
	}

	// No optional resources
	optionalResources: {}

	// No required traits
	requiredTraits: {}

	// No optional traits
	optionalTraits: {}

	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext

		// Extract required Volumes resource (will be bottom if not present)
		_volumes: #component.spec.volumes

		// Emit one PVC per volume that declares a persistentClaim. Output is
		// a list of resources; the renderer dispatches on cue.Kind and
		// produces one Compiled per list element.
		output: [
			for volumeName, volume in _volumes if volume.persistentClaim != _|_ {
				k8scorev1.#PersistentVolumeClaim & {
					apiVersion: "v1"
					kind:       "PersistentVolumeClaim"
					metadata: {
						name:      "\(#context.#moduleInstanceMetadata.name)-\(#context.#componentMetadata.name)-\(volumeName)"
						namespace: #context.#moduleInstanceMetadata.namespace
						// EXPERIMENT 0015/02, prerequisite P1: the volume key as a
						// label, so a provider adapter can select ONE of a
						// component's volumes. The only edit to this copy of
						// catalog_opm v4.0.1.
						labels: #context.labels & {"volume.opmodel.dev/name": volumeName}
						if len(#context.componentAnnotations) > 0 {
							annotations: #context.componentAnnotations
						}
					}
					spec: {
						accessModes: [volume.persistentClaim.accessMode | *"ReadWriteOnce"]
						resources: {
							requests: {
								storage: volume.persistentClaim.size
							}
						}
						if volume.persistentClaim.storageClass != _|_ {
							storageClassName: volume.persistentClaim.storageClass
						}
					}
				}
			},
		]
	}
}
