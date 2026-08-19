// Claim 3, resource half: a component demands a contract with an EMPTY
// bucket. D28 requires the render to refuse, and the hypothesis requires the
// refusal's EVIDENCE to be data.
//
// Expected readout:
//
//	match.missing     names (orphan, resource, orphan-store fqn)   <- rung 1
//	match.unresolved  names the same demand, disqualified: []       <- D28
//	match.resolved    is false, so `cue vet` FAILS on the resolved: true
//	                  gate below while every sibling verdict stays readable
//	                  via `cue eval` — refusal without poisoning.
//
// The component also attaches ConfigMaps so it has one healthy, satisfiable
// demand beside the broken one: attribution means naming the one that failed,
// not failing the component wholesale.
package missing

import (
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	platform "experiments.opmodel.dev/0019/match-in-one-build/opm_platform:platform"
	matchdef "experiments.opmodel.dev/0019/match-in-one-build/matchdef"
	localcat "experiments.opmodel.dev/0019/match-in-one-build/localcat"
)

components: {
	orphan: c.#Component & {
		metadata: name: "orphan"
		#resources: {
			(localcat.#OrphanStoreResource.metadata.fqn): localcat.#OrphanStoreResource
			(res.#ConfigMapsResource.metadata.fqn):       res.#ConfigMapsResource
		}
		#instance: {
			name:      "missing-probe"
			namespace: "default"
			uuid:      "11111111-2222-5333-8444-555555555555"
		}
		spec: {
			orphanStore: size: "10Gi"
			configMaps: probe: data: KEY: "value"
		}
	}
}

match: matchdef.#Match & {
	#transformers: platform.#composedTransformers
	#components:   components
}

// The verdict, as DATA. The in-build refusal gate lives in gate.cue so this
// file's diagnostics can be read with the gate's failure present in the same
// package — which is exactly the coexistence claim 3 needs to measure.
resolved: match.resolved

diagnostics: {
	missing:    match.missing
	unresolved: match.unresolved
	pairs:      match.pairs
	unmatched:  match.unmatchedComponents
}
