package transformers

import (
	c "opmodel.dev/core@v2"
	k8scorev1 "opmodel.dev/catalogs/opm/schemas/kubernetes/core/v1"
)

// WHY: Both schema types provide `name!: string` and `automountToken?: bool`, so either
// can be passed directly without conversion.
//
// Usage:
//   (#ToK8sServiceAccount & {"in": _identity, context: #context}).out

// #ToK8sServiceAccount converts an OPM identity spec (either #WorkloadIdentitySchema
// or #ServiceAccountSchema — both share the same shape) to a Kubernetes ServiceAccount.
#ToK8sServiceAccount: {
	X="in": {
		name!:           string
		automountToken?: bool
	}
	context: c.#TransformerContext

	out: k8scorev1.#ServiceAccount & {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: {
			name:      X.name // exact — workloads and RoleBindings reference the ServiceAccount by name
			namespace: context.#moduleInstanceMetadata.namespace
			labels:    context.labels
			if len(context.componentAnnotations) > 0 {
				annotations: context.componentAnnotations
			}
		}
		automountServiceAccountToken: X.automountToken
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

_testToK8sServiceAccount: (#ToK8sServiceAccount & {
	"in": {
		name:           "ci-bot"
		automountToken: false
	}
	context: {
		namespace: "ci"
		labels: app: "ci-bot"
		componentAnnotations: {}
	}
}).out
