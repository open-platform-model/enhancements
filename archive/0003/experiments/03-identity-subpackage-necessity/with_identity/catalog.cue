// Root catalog imports BOTH the transformers subpackage and identity.
package with_identity

import (
	id "enhancements.opmodel.dev/0003/experiments/03-identity-subpackage-necessity/with_identity/identity"
	t "enhancements.opmodel.dev/0003/experiments/03-identity-subpackage-necessity/with_identity/transformers"
)

catalog: {
	kind: "Catalog"
	metadata: {
		modulePath: id.ModulePath
		version:    id.Version
		fqn:        "\(modulePath)@\(version)"
	}
	#transformers: {
		(t.#FooTransformer.metadata.fqn): t.#FooTransformer
	}
}

shipped: {
	catalogFQN:     catalog.metadata.fqn
	transformerFQN: t.#FooTransformer.metadata.fqn
}
