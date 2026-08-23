package consumer

import (
	a "testing.opmodel.dev/exp0003/cat_a@v1"
	b "testing.opmodel.dev/exp0003/cat_b@v1"
)

// What a consumer observes when it resolves each catalog FROM THE REGISTRY.
fromRegistry: {
	methodA: {catalogFQN: a.CatalogFQN, transformerFQN: a.FooTransformerFQN}
	methodB: {catalogFQN: b.CatalogFQN, transformerFQN: b.FooTransformerFQN}
}
