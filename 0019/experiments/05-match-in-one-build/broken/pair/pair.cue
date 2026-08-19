// Claim 4: failure isolation. The healthy instance plus TWO sabotaged
// transformers folded into the map, both pairing with `config` through the
// real ConfigMaps bucket:
//
//	broken-pair-transformer      output CONFLICTS at application -> an ERROR
//	incomplete-pair-transformer  output never becomes concrete   -> INCOMPLETE
//
// Expected readout, from the probes behind matchdef's design:
//
//	rendered      carries every healthy pair concretely, and NEITHER broken
//	              key poisons a sibling
//	failedPairs   names the ERROR pair — `== _|_` sees a conflict
//	failedPairs   does NOT name the INCOMPLETE pair — incomplete is not
//	              bottom, so it lands in `rendered` non-concrete and only
//	              `cue vet -c` catches it, at a path naming the pair key.
//
// The asymmetry is the measured boundary of failure-as-data at render time.
package pair

import (
	c "opmodel.dev/core@v2"
	webapp "experiments.opmodel.dev/0019/match-in-one-build/web_app"
	platform "experiments.opmodel.dev/0019/match-in-one-build/opm_platform:platform"
	matchdef "experiments.opmodel.dev/0019/match-in-one-build/matchdef"
	localcat "experiments.opmodel.dev/0019/match-in-one-build/localcat"
)

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

_transformers: {
	for tfqn, tf in platform.#composedTransformers {(tfqn): tf}
	(localcat.#BrokenPairTransformer.metadata.fqn):     localcat.#BrokenPairTransformer
	(localcat.#IncompletePairTransformer.metadata.fqn): localcat.#IncompletePairTransformer
}

match: matchdef.#Match & {
	#transformers: _transformers
	#components:   instance.components
}

pairs: match.pairs

// Both sabotaged transformers must PAIR — their required copies are the real
// contract, so matching cannot see the sabotage. Failure is a render-time
// fact, which is the point.
resolved: match.resolved
resolved: true

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

renderedKeys: [for k, _ in rendered {k}]
