package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"

	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// Secrets Resource
/////////////////////////////////////////////////////////////////

#SecretsResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1beta1"
		name:           "secrets"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/secrets@v1beta1"
		description:    "A Secret definition for sensitive configuration"
		labels: {
			"resource.opmodel.dev/category": "config"
		}
	}

	spec: secrets: [secretName=string]: #SecretSchema & {name: string | *secretName}
}

#Secrets: c.#Component & {
	#resources: (#SecretsResource.metadata.fqn): #SecretsResource
}

/////////////////////////////////////////////////////////////////
//// Secret Schema
/////////////////////////////////////////////////////////////////

// Secret specification. `data` holds string values only; `name` is
// auto-populated from the map key in the resource spec. The rendered K8s
// object is named {instance}-{component}-{name}, with a content-hash suffix
// appended when `immutable` is set.
#SecretSchema: {
	name!: string
	// Default Opaque so a secret that omits `type` renders concrete (same
	// non-concrete-field hazard as `immutable` below).
	type: *"Opaque" | "kubernetes.io/service-account-token" | "kubernetes.io/dockercfg" | "kubernetes.io/dockerconfigjson" | "kubernetes.io/basic-auth" | "kubernetes.io/ssh-auth" | "kubernetes.io/tls" | "bootstrap.kubernetes.io/token"
	// Default false so a secret that omits `immutable` still renders a concrete
	// value — a bare `bool` leaves the field non-concrete and the instance fails
	// to compile ("incomplete value bool").
	immutable: bool | *false
	data: [string]: string
}
