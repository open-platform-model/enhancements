package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

// References pre-existing K8s Secrets (type kubernetes.io/dockerconfigjson)
// that the kubelet uses to authenticate to private container registries when
// pulling images for any container in the pod.
#ImagePullSecretsTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "image-pull-secrets"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/image-pull-secrets@v1beta1"
		description:    "Reference K8s Secrets used to authenticate to private container registries"
		labels: {
			"trait.opmodel.dev/category": "security"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: imagePullSecrets: #ImagePullSecretsSchema
}

#ImagePullSecrets: c.#Component & {
	#traits: (#ImagePullSecretsTrait.metadata.fqn): #ImagePullSecretsTrait
}

// References to pre-existing K8s Secrets. Each entry is a LocalObjectReference
// to a Secret of type kubernetes.io/dockerconfigjson in the pod's namespace.
// OPM does not create these — they must already exist (typically managed by
// an external secret operator or platform team).
#ImagePullSecretsSchema: [...{name!: string}]
