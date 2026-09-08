package matching

import schema "enhancements.opmodel.dev/0001/experiments/03-same-fqn-divergent-unify/schema"

// Two CUE files (transformer_a.cue + transformer_b.cue) declare the SAME FQN
// with IDENTICAL bodies. CUE unification must collapse them to one entry in
// the shared #composedTransformers map.

widget_transformer: schema.#ComponentTransformer & {
	metadata: {
		name:        "widget"
		modulePath:  "opmodel.dev/test"
		version:     "1.0.0"
		description: "Identical body — emits widget Deployments."
	}
	producesKinds: ["Deployment"]
}
