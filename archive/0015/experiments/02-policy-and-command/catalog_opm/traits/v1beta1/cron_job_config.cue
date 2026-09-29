package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#CronJobConfigTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "cron-job-config"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/cron-job-config@v1beta1"
		description:    "A trait to configure CronJob-specific settings for scheduled task workloads"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: cronJobConfig: #CronJobConfigSchema
}

#CronJobConfig: c.#Component & {
	#traits: (#CronJobConfigTrait.metadata.fqn): #CronJobConfigTrait
}

#CronJobConfigSchema: {
	scheduleCron!:               string
	concurrencyPolicy?:          "Allow" | "Forbid" | "Replace"
	startingDeadlineSeconds?:    uint
	successfulJobsHistoryLimit?: uint
	failedJobsHistoryLimit?:     uint
}
