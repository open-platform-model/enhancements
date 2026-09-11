// Copied shape: catalog_opm/opm/transformers/pdb_transformer.cue. Same
// predicate as the k8up provider; different engine object.
package transformers

import (
	"list"

	id "testing.opmodel.dev/experiments/0015/velero/identity"
	velerov1 "testing.opmodel.dev/experiments/0015/velero/schemas/velero/v1"
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
		description:    "Renders a component's backup trait as a Velero Schedule selecting its pods"
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
		#component: _
		#context:   c.#TransformerContext
		_backup:    #component.spec.backup
		_r:         _backup.retention

		// The keep-more rule: Velero has one ttl, the trait has tiers. The
		// ttl is the longest span any tier asks for, so nothing is deleted
		// sooner than a tiered engine would. keepLast and keepHourly assume
		// at most one backup per day and per hour respectively.
		_hours: [
			if _r.keepHourly != _|_ {_r.keepHourly},
			if _r.keepLast != _|_ {_r.keepLast * 24},
			if _r.keepDaily != _|_ {_r.keepDaily * 24},
			if _r.keepWeekly != _|_ {_r.keepWeekly * 168},
			if _r.keepMonthly != _|_ {_r.keepMonthly * 744},
			if _r.keepYearly != _|_ {_r.keepYearly * 8784},
		]

		// Velero Schedules live in the velero namespace only, so the name
		// carries the instance namespace to stay unique across tenants.
		output: velerov1.#Schedule & {
			metadata: {
				name:      "\(#context.#moduleInstanceMetadata.namespace)-\(#component.#names.resourceName)"
				namespace: "velero"
				labels:    #context.labels
			}
			spec: {
				schedule: _backup.schedule
				template: {
					includedNamespaces: [#context.#moduleInstanceMetadata.namespace]
					labelSelector: matchLabels: #context.componentLabels
					// Guarded so the definition evaluates with #component unconstrained
					// (the platform build evaluates every transformer once, with no
					// component): list.Max refuses an empty list.
					if len(_hours) > 0 {
						ttl: "\(list.Max(_hours))h"
					}
				}
			}
		}
	}
}
