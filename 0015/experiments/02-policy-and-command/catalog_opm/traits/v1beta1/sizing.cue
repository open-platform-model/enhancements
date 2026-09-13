package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#SizingTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "sizing"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/sizing@v1beta1"
		description:    "A trait to specify vertical sizing behavior for a workload"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: sizing: #SizingSchema
}

#Sizing: c.#Component & {
	#traits: (#SizingTrait.metadata.fqn): #SizingTrait
}

#SizingSchema: {
	resources?:   res.#ResourceRequirementsSchema
	autoScaling?: #VerticalScalingSchema
}

// Placeholder for future VPA support.
#VerticalScalingSchema: {}
