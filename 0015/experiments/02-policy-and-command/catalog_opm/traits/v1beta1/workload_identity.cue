package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#WorkloadIdentityTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "workload-identity"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/workload-identity@v1beta1"
		description:    "A workload identity definition for service identity"
		labels: {
			"trait.opmodel.dev/category": "security"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	// Schema shape lives in resources/service_account.cue alongside #ServiceAccountSchema
	// because #RoleSubjectSchema (resources package) also references it.
	spec: workloadIdentity: res.#WorkloadIdentitySchema
}

#WorkloadIdentity: c.#Component & {
	#traits: (#WorkloadIdentityTrait.metadata.fqn): #WorkloadIdentityTrait
}
