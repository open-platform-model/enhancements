package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#SecurityContextTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "security-context"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/security-context@v1beta1"
		description:    "Container and pod-level security constraints"
		labels: {
			"trait.opmodel.dev/category": "security"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	// Pod-level securityContext. The schema shape lives in resources/container.cue
	// because #ContainerSchema also embeds it (per-container scope).
	spec: securityContext: res.#SecurityContextSchema
}

#SecurityContext: c.#Component & {
	#traits: (#SecurityContextTrait.metadata.fqn): #SecurityContextTrait
}
