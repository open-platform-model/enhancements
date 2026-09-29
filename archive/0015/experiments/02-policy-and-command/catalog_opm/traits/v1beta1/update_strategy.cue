package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#UpdateStrategyTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "update-strategy"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/update-strategy@v1beta1"
		description:    "A trait to specify the update strategy for a workload"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: updateStrategy: #UpdateStrategySchema
}

#UpdateStrategy: c.#Component & {
	#traits: (#UpdateStrategyTrait.metadata.fqn): #UpdateStrategyTrait
}

#UpdateStrategySchema: {
	type: "RollingUpdate" | "Recreate" | "OnDelete"
	if type == "RollingUpdate" {
		rollingUpdate?: {
			maxUnavailable?: uint | string
			maxSurge?:       uint | string
			partition?:      uint
		}
	}
}
