package core

#Component: {
	kind: "Component"

	metadata: {
		name!: #NameType

		// WHY the default branch is deliberately NOT unified with a type: on cue
		// v0.17.1 a failed validated default degrades to a bare `incomplete
		// value` that never names the offending string. The error() arm is
		// reported only when every other arm fails, replacing the nested
		// empty-disjunction output an explicit invalid name would otherwise
		// produce. The default (0019:D16), its 127-rune bound and the
		// #ObjectNameType ceiling (0019:D20): SPEC.md § 3.1 Rationale, "Why the
		// default branch is not unified with a type", "Why there is no length
		// guard on the default any more" and "Why the override ceiling is a
		// subdomain and not a label".

		// Per-component resource-name override. Defaults to the
		// instance-qualified name `<instance>-<component>`; an explicit value
		// wins via the disjunction-default cascade and must be a DNS subdomain
		// (#ObjectNameType, dots admitted, 253 runes). #names reads from here.
		// See SPEC.md § 3.1.
		resourceName: *"\(#instance.name)-\(name)" | #ObjectNameType | error("resourceName \"\(resourceName)\" is not a DNS subdomain (lowercase alphanumerics, hyphens and dots, 1-253 runes)")

		// WHY labels are not unified upward: both claims were here and both
		// were false: no CUE in this definition performed the union, and the
		// kernel reads this field off the component rather than folding it up
		// from below. Matching now has its own field — see matchLabels
		// (0010:D36).

		// Component labels — descriptive metadata for this component, and the
		// labels that reach rendered output via #TransformerContext. NOT
		// unified from the attached primitives, and nothing matches on them;
		// matching has its own field, matchLabels.
		labels?: #LabelsAnnotationsType

		// Component annotations — descriptive metadata for this component.
		// Not unified from the attached primitives either, for the same
		// reason.
		annotations?: #LabelsAnnotationsType
	}

	// Resources applied for this component
	#resources: #ResourceMap

	// Traits applied to this component
	#traits?: #TraitMap

	// Blueprints applied to this component
	#blueprints?: #BlueprintMap

	// NO demand-side optionality marker for RESOURCES, and the absence is a
	// decision (0010:D28): a component does not attach a resource it can do
	// without. Every declared resource is a demand the platform must satisfy,
	// and an unsupplied one fails the render. Traits differ because a trait
	// can be advisory — it modifies something that renders regardless.

	// WHY this is the component's MATCHING identity: the wholesale
	// unification of every attached primitive's matchLabels. No filter, no
	// key list, no prefix rule — every key a primitive puts there exists to
	// be matched on, so there is nothing to select between. `metadata.labels`
	// is NOT unified upward (see there); the two fields never meet.
	//
	// A component contributes NOTHING here of its own — see the derivation
	// check below, which is what makes that structural rather than a
	// convention. Every key traces to a primitive, which is what puts the
	// matching label under the primitive's own additive-only promise instead
	// of under a wrapper nobody versions.
	//
	// The comprehension iterates the attachment MAPS and embeds each
	// primitive's matchLabels struct whole — it never iterates the labels
	// themselves. That distinction is the whole design: CUE refuses to
	// iterate a struct holding an unset required field, so a `for k, v`
	// over the labels would force every primitive to drop `!` from the key a
	// module author must answer. Embedded wholesale, the marker survives and
	// an unanswered key is reported as a missing required field.
	//
	// Measured in enhancement 0010 experiment 04 (0010:D36).
	//
	// The union itself is hidden, because it is the PROVENANCE of the public
	// field rather than a second value a consumer reads: matchLabels IS this,
	// and the check underneath is what keeps it exactly this. SPEC.md § 3.1
	// Rationale, "Why matching identity unifies upward but `metadata.labels`
	// does not" and "Why the union is a comprehension over the attachment
	// maps and never over the labels".

	// The wholesale unification of every attached primitive's matchLabels:
	// the provenance of the public matchLabels field, which IS this value.
	// Embeds each primitive's matchLabels struct whole; never iterates the
	// labels themselves.
	_matchLabelsFromPrimitives: {
		for _, resource in #resources {
			if resource.matchLabels != _|_ {resource.matchLabels}
		}
		if #traits != _|_ {
			for _, trait in #traits {
				if trait.matchLabels != _|_ {trait.matchLabels}
			}
		}
		if #blueprints != _|_ {
			for _, blueprint in #blueprints {
				if blueprint.matchLabels != _|_ {blueprint.matchLabels}
			}
		}
	}

	matchLabels: _matchLabelsFromPrimitives

	// WHY not `close()` around the union: measured against cue v0.17.1, a
	// closed comprehension still admits an authored key, so the obvious
	// spelling would read as enforcement while enforcing nothing. Why a
	// length comparison works, and why this binds every #Component rather
	// than only catalog fragments: SPEC.md § 3.1 Rationale, "Why the
	// derivation is enforced, and why the rule binds every Component rather
	// than only fragments".

	// matchLabels is DERIVED, and this is the enforcement: a size difference
	// between the union and the field is exactly "this component contributed
	// a key of its own". IF THIS FIRES: put the key on the primitive that
	// owns it, or attach a blueprint that answers it.
	_matchLabelsAreDerived: len(matchLabels) == len(_matchLabelsFromPrimitives)
	_matchLabelsAreDerived: true

	// WHY: introduced by 0001:D3; was #release: #ReleaseIdentity, renamed by
	// 0002:D8. SPEC.md § 3.1
	// Rationale, "Why `#instance` is hidden and module-injected, not
	// author-supplied".

	// Instance context injected by the parent #Module via its #components
	// pattern constraint. Hidden definition slot — module authors never set
	// this directly.
	#instance: #InstanceIdentity

	// WHY unconditional (0019:D21): comprehensions over the three
	// attachment maps, no existence guard — because on cue v0.17.1
	// `x.#nameConstraint != _|_` is false for a non-concrete value and a
	// guarded spelling silently never propagates (0019 experiment 09).
	// Unifying top is the identity, so an indifferent primitive costs
	// nothing.
	//
	// COST: this is a second walk over the attachment maps beside
	// _matchLabelsFromPrimitives, paid per component at every evaluation.
	// Measured (0019 experiment 12, cue v0.17.1): 0.15-0.22 ms per component,
	// linear in component count, the walk itself rather than any primitive's
	// conditional; 0.5-2% of the per-component render cost experiment 07
	// measured. Small today, but it scales with components times attached
	// primitives, so a module with many components each attaching many
	// primitives pays it in full on every render. If render times grow with
	// module complexity, re-measure this walk before the transformers.

	// Every attached primitive's #nameConstraint, unified into one
	// conjunction; top when none declares one. Collected UNCONDITIONALLY,
	// with no existence guard.
	_nameConstraints: _
	for _, resource in #resources {_nameConstraints: resource.#nameConstraint}
	if #traits != _|_ {
		for _, trait in #traits {_nameConstraints: trait.#nameConstraint}
	}

	if #blueprints != _|_ {
		for _, blueprint in #blueprints {_nameConstraints: blueprint.#nameConstraint}
	}

	// WHY this exact spelling: two spellings that read as equivalent are
	// wrong, both measured on cue v0.17.1 (0019 experiment 11). Without the
	// interpolation the constraint distributes into the default arm and a
	// failing default is silently admitted; an `error()` guard fires on the
	// bare definition because `(incomplete & C) == _|_` is true while
	// #instance.name is unresolved. The full refutation, and why the
	// diagnostic cannot carry a remedy: SPEC.md § 3.1 Rationale, "Why the
	// constraint is asserted on a hidden field rather than unified into
	// `resourceName`".

	// The assertion: the RESOLVED resourceName satisfies every attached
	// constraint. Refuses naming the string, the violated bound and the
	// constraint type's definition site. The interpolation is load-bearing;
	// see below.
	_nameFits: "\(metadata.resourceName)" & _nameConstraints

	// WHY: introduced by enhancement 0001 (0001:D2). #Module.#ctx.components
	// projects this block automatically; authors writing self-references
	// inside a component's `spec` body MUST go through
	// `#ctx.components.<self-id>.dns.fqdn` because `#names` is not in lexical
	// scope under the spec definition block. SPEC.md § 3.1 Rationale, "Why
	// `#names` lives on the Component and `#ctx.components` is a projection".

	// Single source of truth for this component's computed names.
	// `resourceName` reads straight from metadata (cascade lives there); DNS
	// variants derive deterministically from resourceName +
	// #instance.namespace + #instance.clusterDomain. Authors inside a
	// component's `spec` body MUST use `#ctx.components.<self-id>.dns.fqdn`.
	#names: {
		resourceName: metadata.resourceName
		dns: {
			short: resourceName
			local: "\(resourceName).\(#instance.namespace)"
			fqdn:  "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
		}
	}

	_allFields: {
		for _, resource in #resources {
			if resource.spec != _|_ {resource.spec}
		}
		if #traits != _|_ {
			for _, trait in #traits {
				if trait.spec != _|_ {trait.spec}
			}
		}
		if #blueprints != _|_ {
			for _, blueprint in #blueprints {
				if blueprint.spec != _|_ {blueprint.spec}
			}
		}
	}

	// Fields exposed by this component (merged from all resources, traits, and blueprints)
	// Automatically turned into a spec.
	// Must be made concrete by the user.
	// Have to do it this way because if we allowed the spec flattened in the root of the component
	// we would have to open the #Module definition which would make it impossible to properly validate.
	spec: close({
		_allFields
	})
}

#ComponentMap: [string]: #Component
