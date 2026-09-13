package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#GracefulShutdownTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "graceful-shutdown"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/graceful-shutdown@v1beta1"
		description:    "Termination grace period and pre-stop lifecycle hooks"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: gracefulShutdown: #GracefulShutdownSchema
}

#GracefulShutdown: c.#Component & {
	#traits: (#GracefulShutdownTrait.metadata.fqn): #GracefulShutdownTrait
}

#GracefulShutdownSchema: {
	terminationGracePeriodSeconds: uint
}
