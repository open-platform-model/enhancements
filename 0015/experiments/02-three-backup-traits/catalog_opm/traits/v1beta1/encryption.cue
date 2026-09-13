package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#EncryptionConfigTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "encryption"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/encryption@v1beta1"
		description:    "Enforces encryption requirements"
		labels: {
			"trait.opmodel.dev/category": "security"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: encryption: #EncryptionConfigSchema
}

#EncryptionConfig: c.#Component & {
	#traits: (#EncryptionConfigTrait.metadata.fqn): #EncryptionConfigTrait
}

#EncryptionConfigSchema: {
	atRest:    bool
	inTransit: bool
}
