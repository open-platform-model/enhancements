package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#ScheduledTaskWorkloadSchema: {
	container:      res.#ContainerSchema
	cronJobConfig:  tr.#CronJobConfigSchema
	restartPolicy?: tr.#RestartPolicySchema
	sidecarContainers?: [...tr.#SidecarContainersSchema]
	initContainers?: [...tr.#InitContainersSchema]
}

#ScheduledTaskWorkloadBlueprint: c.#Blueprint & {
	metadata: {
		modulePath:     "\(id.kindPrefix.blueprints)/v1beta1"
		name:           "scheduled-task-workload"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.blueprints)/scheduled-task-workload@v1beta1"
		description:    "A scheduled task workload that runs on a cron schedule (CronJob)"
	}

	// Answers the container resource's required matching key (0010 D36):
	// attaching this blueprint is what completes a component's matching
	// identity. Matching reads matchLabels; metadata.labels on the wrapper
	// below stays as a transitional duplicate until the kernel's matcher
	// flips its read (0010 library-matching).
	matchLabels: "core.opmodel.dev/workload-type": "scheduled-task"

	composedResources: [
		res.#ContainerResource,
	]

	composedTraits: [
		tr.#CronJobConfigTrait,
		tr.#RestartPolicyTrait,
		tr.#SidecarContainersTrait,
		tr.#InitContainersTrait,
	]

	spec: scheduledTaskWorkload: #ScheduledTaskWorkloadSchema
}

#ScheduledTaskWorkload: c.#Component & {
	metadata: labels: {
		"core.opmodel.dev/workload-type": "scheduled-task"
	}

	#blueprints: (#ScheduledTaskWorkloadBlueprint.metadata.fqn): #ScheduledTaskWorkloadBlueprint

	res.#Container
	tr.#CronJobConfig
	tr.#RestartPolicy
	tr.#SidecarContainers
	tr.#InitContainers

	// Override spec to propagate values from scheduledTaskWorkload.
	//
	// Guards hoisted at component level — do not move back inside the spec
	// block (CUE v0.17.0 closedness regression; see
	// docs/cue-guard-closedness-workaround.md in the catalog_opm repo).
	spec: {
		scheduledTaskWorkload: #ScheduledTaskWorkloadSchema
		container:             spec.scheduledTaskWorkload.container
		cronJobConfig:         spec.scheduledTaskWorkload.cronJobConfig
	}
	if spec.scheduledTaskWorkload.restartPolicy != _|_ {
		spec: restartPolicy: spec.scheduledTaskWorkload.restartPolicy
	}
	if spec.scheduledTaskWorkload.sidecarContainers != _|_ {
		spec: sidecarContainers: spec.scheduledTaskWorkload.sidecarContainers
	}
	if spec.scheduledTaskWorkload.initContainers != _|_ {
		spec: initContainers: spec.scheduledTaskWorkload.initContainers
	}
}
