package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// Role Resource
/////////////////////////////////////////////////////////////////

#RoleResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1beta1"
		name:           "role"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/role@v1beta1"
		description:    "An RBAC Role definition with rules and CUE-referenced subjects"
		labels: {
			"resource.opmodel.dev/category": "security"
		}
	}

	spec: role: #RoleSchema
}

#Role: c.#Component & {
	#resources: (#RoleResource.metadata.fqn): #RoleResource
}

/////////////////////////////////////////////////////////////////
//// Role Schemas
/////////////////////////////////////////////////////////////////

// WHY: CUE drops a disjunct only on a contradiction; a missing required field
// is "incomplete", never contradictory, so absence alone cannot eliminate the
// wrong arm. Closedness could, but it is not applied to the fields of an
// embedding component ({res.#Role, spec: ...}), so a disjunction told apart
// only by absent fields never resolves there (measured, cue v0.17.1). Each arm
// therefore refuses the other arm's discriminating fields with `field?: _|_`:
// the wrong arm contradicts on a PRESENT field and the disjunction resolves in
// every authoring form. See docs/struct-disjunctions.md.

// Single RBAC permission rule, exactly one of the two k8s forms.
// A rule carrying fields of both forms is refused (empty disjunction).
#PolicyRuleSchema: #ResourcePolicyRuleSchema | #NonResourcePolicyRuleSchema

#ResourcePolicyRuleSchema: {
	apiGroups!: [...string]
	resources!: [...string]
	verbs!: [...string]
	// Optional whitelist of object names within the resources above.
	// For `signers`, the apiserver special-cases "<domain>/*" wildcards
	// (e.g. "issuers.cert-manager.io/*") — passed through verbatim.
	resourceNames?: [...string]
	// Present -> not this form (see the WHY block on #PolicyRuleSchema).
	nonResourceURLs?: _|_
}

// ClusterRole (scope: "cluster") only — enforced in review/docs, not schema.
#NonResourcePolicyRuleSchema: {
	nonResourceURLs!: [_, ...] & [...string]
	verbs!: [...string]
	// Present -> not this form (see the WHY block on #PolicyRuleSchema).
	apiGroups?:     _|_
	resources?:     _|_
	resourceNames?: _|_
}

// Role subject — embeds an identity directly via CUE reference.
// References sibling primitives (#WorkloadIdentitySchema, #ServiceAccountSchema)
// in the same package.
#RoleSubjectSchema: {#WorkloadIdentitySchema | #ServiceAccountSchema}

#RoleSchema: {
	name!: string
	scope: "namespace" | "cluster"
	rules!: [...#PolicyRuleSchema] & [_, ...]
	subjects!: [...#RoleSubjectSchema] & [_, ...]
}
