// THE GLUE, execute-only.
//
// This is experiment 01's render.cue with the match phase removed and the
// platform interposed. The removal is deliberate and it is what keeps this
// experiment single-variable: moving matching into the build adds evaluation
// work that experiment 05 owns, so folding it in here would make every number
// below a sum of two unknowns.
//
// What remains is the part of the render step that a single build cannot avoid
// paying: resolve, load and evaluate the catalog behind the platform, and
// unify one #transform per pair with its three inputs.
package render

import (
	inst "experiments.opmodel.dev/0019/render-build-cost/instance@v0"
	platform "experiments.opmodel.dev/0019/render-build-cost/platform@v0"
)

// The transformer map arrives through the platform (D5), not by importing the
// catalog directly. That is the shape a real render glue has: it imports the
// instance and the platform and has no reason to name the catalog.
_transformers: platform.#composedTransformers

instance:   inst.instance
components: instance.components

// ---------------------------------------------------------------------------
// Pair selection, which is NOT matching
// ---------------------------------------------------------------------------
//
// The pairs are the five experiment 01 produced from the real predicate rung
// on this fixture. They are named here by transformer SHORT NAME and located
// by a key lookup, so no version is restated as data and a catalog bump does
// not silently change which bodies execute (it fails instead, because a name
// that locates nothing yields an empty pair list and `rendered` shrinks).
//
// This is a lookup, not a match: nothing here reads a component's #resources,
// #traits or matchLabels. Read `02-design.md`'s "What matching costs" for what
// the real rungs do, and experiment 05 for what they cost.
_wanted: {
	web: ["deployment-transformer", "hpa-transformer", "http-route-transformer", "service-transformer"]
	config: ["configmap-transformer"]
}

pairs: [
	for cid, names in _wanted
	for n in names
	for fqn, _ in _transformers
	if fqn =~ "/\(n)@" {{component: cid, transformer: fqn}},
]

// ---------------------------------------------------------------------------
// #context, as a projection over the other two inputs (OQ5)
// ---------------------------------------------------------------------------

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
		#runtimeName: "render-build-cost"
	}
}

// ---------------------------------------------------------------------------
// Execute
// ---------------------------------------------------------------------------
//
// One unification per pair, all three declared inputs supplied, nothing
// stripped. This is the whole executePair equivalent.

rendered: {
	for p in pairs {
		"\(p.component) :: \(p.transformer)": (_transformers[p.transformer].#transform & {
			#moduleInstance: instance
			#component:      components[p.component]
			#context:        (_contextFor & {comp: components[p.component]}).out
		}).output
	}
}
