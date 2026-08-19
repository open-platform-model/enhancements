// Claim 2, negative case: a component whose primitive body GENUINELY
// conflicts with a candidate's required copy must still be disqualified by
// plain `&` — the claim is "provenance cannot diverge in one build", not
// "unification was disabled".
//
// The component narrows Container at the attachment site (the raw-authoring
// shape experiment 07 recorded) to name "pinned"; localcat's
// conflicting-transformer requires Container narrowed to a different name.
// The two copies conflict at spec.container.name, a real schema divergence.
//
// Expected readout:
//
//	conflicting-transformer is NOT in pairs                       <- rung 2
//	its unify verdict carries the container FQN in conflicts       <- as data
//	deployment-transformer still pairs (unnarrowed required copy)  <- isolation
//	the container demand is satisfied, so resolved stays true      <- D28
package conflict

import (
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	platform "experiments.opmodel.dev/0019/match-in-one-build/opm_platform:platform"
	matchdef "experiments.opmodel.dev/0019/match-in-one-build/matchdef"
	localcat "experiments.opmodel.dev/0019/match-in-one-build/localcat"
)

components: {
	pinned: c.#Component & {
		metadata: name: "pinned"
		#resources: (res.#ContainerResource.metadata.fqn): res.#ContainerResource & {
			matchLabels: "core.opmodel.dev/workload-type": "stateless"
			spec: container: name: "pinned"
		}
		#instance: {
			name:      "conflict-probe"
			namespace: "default"
			uuid:      "11111111-2222-5333-8444-555555555555"
		}
		spec: container: {
			name: "pinned"
			image: {
				repository: "nginx"
				tag:        "1.27"
				digest:     ""
			}
		}
	}
}

// The platform's map plus the synthetic conflicting adapter, sharing the
// real Container bucket. Folded by comprehension, NOT unified into the
// catalog's own map: catalog.#transformers carries a pattern constraint
// stamping the declaring catalog's modulePath/catalogVersion onto every
// member (0010 D25's provenance stamp), so injecting a foreign transformer
// into it is refused outright — measured here first, and itself a finding:
// multi-catalog composition is a map FOLD, never a unification into one
// catalog's member map.
_transformers: {
	for tfqn, tf in platform.#composedTransformers {(tfqn): tf}
	(localcat.#ConflictingTransformer.metadata.fqn): localcat.#ConflictingTransformer
}

match: matchdef.#Match & {
	#transformers: _transformers
	#components:   components
}

resolved: match.resolved

diagnostics: {
	pairs:         match.pairs
	unresolved:    match.unresolved
	unifyFailures: match.unifyFailures
}
