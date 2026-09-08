// The HEALTHY fixture: experiment 01's instance run through the full
// three-rung glue, with the transformer map arriving the D5 way — off the
// platform's registry entry — instead of by direct catalog import.
//
// Claims exercised here:
//
//	claim 1: `pairs` equals the kernel's own pair set for the same fixture
//	         (../expected/pairs.json, captured by ../capture/).
//	claim 2: rung 2 runs as PLAIN `&` with no D30 carve-out and disqualifies
//	         nothing; `provenance*` below states the reason directly — in one
//	         build both sides of the unification carry identical provenance.
//	claim 4 (healthy half): rendered-as-data yields every pair concretely and
//	         `failedPairs` is empty.
package healthy

import (
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	webapp "experiments.opmodel.dev/0019/match-in-one-build/web_app"
	platform "experiments.opmodel.dev/0019/match-in-one-build/opm_platform:platform"
	matchdef "experiments.opmodel.dev/0019/match-in-one-build/matchdef"
)

// The instance, authored exactly as experiment 01 authored it: the module
// enters by IMPORT, which keeps #config / #components cross-references bound.
// Name and namespace match the kernel flow test so pairs are comparable.
instance: c.#ModuleInstance & {
	metadata: {
		name:      "web-app-demo"
		namespace: "default"
	}
	#module: webapp
	values: {
		image: {
			repository: "nginx"
			tag:        "1.27"
			digest:     ""
		}
		replicas: 2
		port:     8080
		hostnames: ["web.example.test"]
	}
}

// The transformer map, read off the D5 platform's registry entry. This is
// the fold materialize/index.go performs, already done by the schema.
_transformers: platform.#composedTransformers

match: matchdef.#Match & {
	#transformers: _transformers
	#components:   instance.components
}

pairs: match.pairs

// The healthy fixture must pair cleanly and resolve every demand. These are
// the fail-closed gate unified against its expected verdict: if plain-&
// disqualified anything, or a demand went unresolved, the build refuses.
resolved: match.resolved
resolved: true

// Claim 2 stated directly rather than only by absence of disqualification:
// the component's embedded primitive copy and the transformer's embedded
// required copy resolve to the SAME catalog bytes, so the two fields D30
// exists to excuse are equal, not merely compatible.
_containerFQN: res.#ContainerResource.metadata.fqn
_deployFQN: [for p in pairs if p.component == "web" if p.transformer =~ "deployment-transformer" {p.transformer}][0]

provenanceCatalogVersionEqual: instance.components.web.#resources[_containerFQN].metadata.catalogVersion ==
				_transformers[_deployFQN].requiredResources[_containerFQN].metadata.catalogVersion
provenanceCatalogVersionEqual: true

provenanceDescriptionEqual: instance.components.web.#resources[_containerFQN].metadata.description ==
				_transformers[_deployFQN].requiredResources[_containerFQN].metadata.description
provenanceDescriptionEqual: true

// And the rung 2 verdict itself, surfaced for the run log: no candidate
// anywhere was disqualified by plain unification.
disqualifiedCount: len([
	for _, v in match.verdicts
	for _, u in v.unresolvedResources
	for _, d in u.disqualified {d},
])
disqualifiedCount: 0

// ── Render, as data (claim 4's healthy half) ────────────────────────
// Same three fills as experiment 01, but each pair's output is admitted
// into `rendered` only when it is not bottom, and failures collect in
// `failedPairs` — the shape the single-build glue would ship.

_contextFor: {
	comp!: _
	out: {
		#moduleInstanceMetadata: {
			name:      instance.metadata.name
			namespace: instance.metadata.namespace
			fqn:       instance.metadata.fqn
			uuid:      instance.metadata.uuid
			version:   instance.#moduleMetadata.version
			if instance.metadata.labels != _|_ {labels: instance.metadata.labels}
			if instance.metadata.annotations != _|_ {annotations: instance.metadata.annotations}
		}
		#componentMetadata: {
			name: comp.metadata.name
			if comp.metadata.labels != _|_ {labels: comp.metadata.labels}
			if comp.metadata.annotations != _|_ {annotations: comp.metadata.annotations}
		}
		#runtimeName: "match-in-one-build"
	}
}

rendered: {
	for p in pairs
	let applied = (_transformers[p.transformer].#transform & {
		#moduleInstance: instance
		#component:      instance.components[p.component]
		#context: (_contextFor & {comp: instance.components[p.component]}).out
	}).output
	if applied != _|_ {
		"\(p.component) :: \(p.transformer)": applied
	}
}

failedPairs: [
	for p in pairs
	let applied = (_transformers[p.transformer].#transform & {
		#moduleInstance: instance
		#component:      instance.components[p.component]
		#context: (_contextFor & {comp: instance.components[p.component]}).out
	}).output
	if applied == _|_ {p},
]

failedCount: len(failedPairs)
failedCount: 0
