package divergent

import schema "enhancements.opmodel.dev/0001/experiments/03-same-fqn-divergent-unify/schema"

composed: schema.#TransformerMap & {
	(widget_transformer.metadata.fqn): widget_transformer
}
