package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#ScalingTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "scaling"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/scaling@v1beta1"
		description:    "A trait to specify scaling behavior for a workload"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: scaling: #ScalingSchema
}

#Scaling: c.#Component & {
	#traits: (#ScalingTrait.metadata.fqn): #ScalingTrait
}

/////////////////////////////////////////////////////////////////
//// Scaling Schemas
/////////////////////////////////////////////////////////////////

#ScalingSchema: {
	count: int & >=0 & <=1000
	auto?: #AutoscalingSpec
}

#AutoscalingSpec: {
	min!: int & >=1
	max!: int & >=1
	metrics!: [_, ...#MetricSpec]
	behavior?: {
		scaleUp?: {stabilizationWindowSeconds?: int}
		scaleDown?: {stabilizationWindowSeconds?: int}
	}
}

#MetricSpec: {
	type!:   "cpu" | "memory" | "custom"
	target!: #MetricTargetSpec
	if type == "custom" {
		metricName!: string
	}
}

#MetricTargetSpec: {
	averageUtilization?: int & >=1 & <=100
	averageValue?:       string
}
