package divergent

import schema "enhancements.opmodel.dev/0001/experiments/03-same-fqn-divergent-unify/schema"

// Same FQN as divergent/transformer_a.cue but description DIFFERS.

widget_transformer: schema.#ComponentTransformer & {
	metadata: {
		name:        "widget"
		modulePath:  "opmodel.dev/test"
		version:     "1.0.0"
		description: "DIVERGENT — B: emits widget StatefulSets."
	}
	producesKinds: ["StatefulSet"]
}
