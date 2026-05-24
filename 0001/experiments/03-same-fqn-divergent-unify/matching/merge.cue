package matching

import schema "enhancements.opmodel.dev/0001/experiments/03-same-fqn-divergent-unify/schema"

// Build a #composedTransformers-shaped map by indexing the collapsed
// widget_transformer under its FQN. Unification of the two source files
// happens implicitly via the shared `widget_transformer` field name.
composed: schema.#TransformerMap & {
	(widget_transformer.metadata.fqn): widget_transformer
}
