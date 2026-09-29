package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1alpha1"
)

// AdmissionPolicyTransformer converts ValidatingAdmissionPolicies resources to
// Kubernetes ValidatingAdmissionPolicy + ValidatingAdmissionPolicyBinding pairs.
//
// Two objects per entry, emitted together so the binding's `policyName` is
// always the policy that was actually rendered. Names are exact — both objects
// are cluster-scoped and the binding references the policy by name.
#AdmissionPolicyTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "admission-policy-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/admission-policy-transformer@\(id.Version)"
		description:    "Converts ValidatingAdmissionPolicies resources to CEL admission policies and their bindings"

		labels: {
			"core.opmodel.dev/resource-category": "cluster"
			"core.opmodel.dev/resource-type":     "validatingadmissionpolicy"
		}
	}

	requiredLabels: {}

	requiredResources: {
		(res.#ValidatingAdmissionPoliciesResource.metadata.fqn): res.#ValidatingAdmissionPoliciesResource
	}

	optionalResources: {}
	requiredTraits: {}
	optionalTraits: {}

	producesKinds: ["ValidatingAdmissionPolicy", "ValidatingAdmissionPolicyBinding"]

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		output: [
			for _, p in #component.spec.validatingAdmissionPolicies
			let _userLabels = [if p.labels != _|_ {p.labels}, {}][0]
			let _labels = {
				for k, v in #context.labels if _userLabels[k] == _|_ {(k): v}
				for k, v in _userLabels {(k): v}
			}
			for _obj in [
				{
					apiVersion: p.apiVersion
					kind:       "ValidatingAdmissionPolicy"
					metadata: {
						name:   p.name // exact — bindings reference the policy by name
						labels: _labels
						if p.annotations != _|_ {
							annotations: p.annotations
						}
					}
					spec: {
						if p.failurePolicy != _|_ {
							failurePolicy: p.failurePolicy
						}
						matchConstraints: p.matchConstraints
						if p.variables != _|_ {
							variables: p.variables
						}
						validations: p.validations
					}
				},
				{
					apiVersion: p.apiVersion
					kind:       "ValidatingAdmissionPolicyBinding"
					metadata: {
						name:   p.binding.name // exact — authored binding identity
						labels: _labels
						if p.annotations != _|_ {
							annotations: p.annotations
						}
					}
					spec: {
						// Always the policy rendered directly above, so the two
						// cannot drift apart.
						policyName:        p.name
						validationActions: p.binding.validationActions
						if p.binding.matchResources != _|_ {
							matchResources: p.binding.matchResources
						}
					}
				},
			] {_obj},
		]
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// Mirrors istio's stable-channel policy at 1.30.3 under
// experimental.stableValidationPolicy.
_testVAPComponent: res.#ValidatingAdmissionPolicies & {
	spec: validatingAdmissionPolicies: "stable-channel-policy-istio-system.istio.io": {
		failurePolicy: "Fail"
		matchConstraints: {
			objectSelector: matchExpressions: [{
				key:      "istio.io/rev"
				operator: "In"
				values: ["default"]
			}]
			resourceRules: [{
				apiGroups: [
					"security.istio.io",
					"networking.istio.io",
					"telemetry.istio.io",
					"extensions.istio.io",
				]
				apiVersions: ["*"]
				operations: ["CREATE", "UPDATE"]
				resources: ["*"]
			}]
		}
		variables: [{
			name:       "isEnvoyFilter"
			expression: "object.kind == 'EnvoyFilter'"
		}]
		validations: [{
			expression: "!variables.isEnvoyFilter"
			message:    "EnvoyFilter is not supported in the stable channel"
		}]
		binding: name: "stable-channel-policy-binding-istio-system.istio.io"
	}
}

_testVAPTransformer: (#AdmissionPolicyTransformer.#transform & {
	#component: _testVAPComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "istio"
			namespace: "istio-system"
			fqn:       "opmodel.dev/catalogs/opm/istio@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "stable-validation-policy"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// One entry must produce exactly two objects.
_testVAPCount: (len(_testVAPTransformer) + 0) & 2

_testVAPPolicyKind:  "\(_testVAPTransformer[0].kind)" & "ValidatingAdmissionPolicy"
_testVAPBindingKind: "\(_testVAPTransformer[1].kind)" & "ValidatingAdmissionPolicyBinding"

_testVAPPolicyName:  "\(_testVAPTransformer[0].metadata.name)" & "stable-channel-policy-istio-system.istio.io"
_testVAPBindingName: "\(_testVAPTransformer[1].metadata.name)" & "stable-channel-policy-binding-istio-system.istio.io"

// The binding must reference the policy actually rendered — compared against
// the sibling object rather than a literal, so the two cannot drift.
_testVAPBindingTargetsPolicy: "\(_testVAPTransformer[1].spec.policyName)" & "\(_testVAPTransformer[0].metadata.name)"

// apiVersion defaults to v1 and must be concrete on both objects; a regression
// leaving the disjunction unresolved would render an object the API rejects.
_testVAPApiVersion: "\(_testVAPTransformer[0].apiVersion)" & "admissionregistration.k8s.io/v1"

_testVAPBindingActions: [
	if _testVAPTransformer[1].spec.validationActions != _|_ {_testVAPTransformer[1].spec.validationActions[0]},
] & ["Deny"]
