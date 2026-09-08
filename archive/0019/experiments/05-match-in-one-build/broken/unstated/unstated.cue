// Claim 3, trait half, fail-closed case: a component carries an unhandled
// trait whose declaring catalog states NO optional posture. D28 treats the
// unstated posture as load-bearing and refuses the render.
//
// Expected readout (measured, not assumed): classifying the posture requires
// evaluating a plain `bool`, which CUE reports as an INCOMPLETE value — so
// unlike broken/missing, the refusal here does NOT arrive as a row in
// `unresolved`. `cue vet -c` refuses naming the trait's own `optional` field,
// and the diagnostics comprehensions upstream of it go incomplete. This
// fixture measures the exact boundary of failure-as-data.
//
// The component pairs healthily on its ConfigMaps demand, so the readout also
// shows how much of the healthy remainder the incompleteness takes with it.
package unstated

import (
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	platform "experiments.opmodel.dev/0019/match-in-one-build/opm_platform:platform"
	matchdef "experiments.opmodel.dev/0019/match-in-one-build/matchdef"
	localcat "experiments.opmodel.dev/0019/match-in-one-build/localcat"
)

components: {
	carrier: c.#Component & {
		metadata: name:                                     "carrier"
		#resources: (res.#ConfigMapsResource.metadata.fqn): res.#ConfigMapsResource
		#traits: (localcat.#UnstatedTrait.metadata.fqn):    localcat.#UnstatedTrait
		#instance: {
			name:      "unstated-probe"
			namespace: "default"
			uuid:      "11111111-2222-5333-8444-555555555555"
		}
		spec: {
			configMaps: probe: data: KEY: "value"
			unstated: note: "posture deliberately unstated"
		}
	}
}

match: matchdef.#Match & {
	#transformers: platform.#composedTransformers
	#components:   components
}

resolved: match.resolved

diagnostics: {
	missing:    match.missing
	unresolved: match.unresolved
	warnings:   match.warnings
	pairs:      match.pairs
	unmatched:  match.unmatchedComponents
}
