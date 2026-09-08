package matching

import schema "enhancements.opmodel.dev/0001/experiments/03-same-fqn-divergent-unify/schema"

// Byte-identical to transformer_a.cue's widget_transformer body. Unification
// must succeed without error and collapse to one entry.

widget_transformer: schema.#ComponentTransformer & {
	metadata: {
		name:        "widget"
		modulePath:  "opmodel.dev/test"
		version:     "1.0.0"
		description: "Identical body — emits widget Deployments."
	}
	producesKinds: ["Deployment"]
}
