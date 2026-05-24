package divergent

import schema "enhancements.opmodel.dev/0001/experiments/03-same-fqn-divergent-unify/schema"

// Same FQN as divergent/transformer_b.cue's widget_transformer but the
// description field DIVERGES. CUE unification must fail and name the
// diverging field in the error.

widget_transformer: schema.#ComponentTransformer & {
	metadata: {
		name:        "widget"
		modulePath:  "opmodel.dev/test"
		version:     "1.0.0"
		description: "DIVERGENT — A: emits widget Deployments."
	}
	producesKinds: ["Deployment"]
}
