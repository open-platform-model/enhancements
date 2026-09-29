package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// ServiceAccount Resource
/////////////////////////////////////////////////////////////////

#ServiceAccountResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1beta1"
		name:           "service-account"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/service-account@v1beta1"
		description:    "A standalone ServiceAccount definition for identity"
		labels: {
			"resource.opmodel.dev/category": "security"
		}
	}

	spec: serviceAccount: #ServiceAccountSchema
}

#ServiceAccount: c.#Component & {
	#resources: (#ServiceAccountResource.metadata.fqn): #ServiceAccountResource
}

/////////////////////////////////////////////////////////////////
//// Identity Schemas
//// Both #ServiceAccountSchema and #WorkloadIdentitySchema live here.
//// #WorkloadIdentitySchema is read by traits/workload_identity.cue
//// (the trait spec) and by #RoleSubjectSchema in role.cue.
/////////////////////////////////////////////////////////////////

#ServiceAccountSchema: {
	name!:           string
	automountToken?: bool
}

// Workload identity — used by #WorkloadIdentityTrait and as a #RoleSubjectSchema variant.
#WorkloadIdentitySchema: {
	name!:           string
	automountToken?: bool
}
