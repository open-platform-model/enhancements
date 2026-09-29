package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#DisruptionBudgetTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "disruption-budget"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/disruption-budget@v1beta1"
		description:    "Availability constraints during voluntary disruptions"
		labels: {
			"trait.opmodel.dev/category": "workload"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	spec: disruptionBudget: #DisruptionBudgetSchema
}

#DisruptionBudget: c.#Component & {
	#traits: (#DisruptionBudgetTrait.metadata.fqn): #DisruptionBudgetTrait
}

// WHY: Spelled as one struct with matchN rather than a disjunction of two, matching
// #VolumeSchema and #ProjectedSourceSchema. The disjunction form was unusable:
// its arms were open structs, so setting `minAvailable` did not eliminate the
// `maxUnavailable` arm — the value stayed a two-armed disjunction, never became
// concrete, and no PodDisruptionBudget could be rendered from it.

// Exactly one of minAvailable or maxUnavailable must be set. matchN
// resolves as soon as one field is set, and makes setting both a hard error
// rather than another silently incomplete value.
#DisruptionBudgetSchema: {
	minAvailable?:   int | string & =~"^[0-9]+%$"
	maxUnavailable?: int | string & =~"^[0-9]+%$"

	matchN(1, [
		{minAvailable!: _},
		{maxUnavailable!: _},
	])
}
