// Copied shape: catalog_opm/opm/transformers/pdb_transformer.cue.
package transformers

import (
	id "testing.opmodel.dev/experiments/0015/k8up/identity"
	k8upv1 "testing.opmodel.dev/experiments/0015/k8up/schemas/k8up/v1"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "testing.opmodel.dev/experiments/0015/contracts/traits/v1alpha1"
)

#BackupScheduleTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "backup-schedule-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/backup-schedule-transformer@\(id.Version)"
		description:    "Renders a component's backup trait as a K8up Schedule scoped to its PVCs"
		labels: {
			"core.opmodel.dev/resource-type": "schedule"
		}
	}

	requiredResources: {
		(res.#VolumesResource.metadata.fqn): res.#VolumesResource
	}
	requiredTraits: {
		(tr.#BackupTrait.metadata.fqn): tr.#BackupTrait
	}

	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext
		_backup:    #component.spec.backup

		// No spec.backend: the operator's BACKUP_GLOBAL* values apply
		// (credential shape 1). The schema refuses one structurally.
		output: k8upv1.#Schedule & {
			metadata: {
				name:      #component.#names.resourceName
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
			}
			spec: {
				backup: {
					schedule: _backup.schedule
					// Only this component's PVCs, by the labels the base
					// catalog stamps on them.
					labelSelectors: [{matchLabels: #context.componentLabels}]
					tags: [#context.#moduleInstanceMetadata.name, #context.#componentMetadata.name]
				}
				// Engine-side cadence choices: tokens are legal here because
				// this is k8up's own vocabulary, not the trait's.
				prune: {
					schedule:  "@daily-random"
					retention: _backup.retention
				}
				check: schedule: "@weekly-random"
			}
		}
	}
}
