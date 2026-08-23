// Root declares the shared identity constant AND imports the subpackage to
// assemble #transformers — closing the loop.
package without_identity

import t "enhancements.opmodel.dev/0003/experiments/03-identity-subpackage-necessity/without_identity/transformers"

Catalog: {
	ModulePath: "example.com/cat"
	Version:    "1.0.0-alpha.2"
}

catalog: {
	kind: "Catalog"
	metadata: {
		modulePath: Catalog.ModulePath
		version:    Catalog.Version
		fqn:        "\(modulePath)@\(version)"
	}
	#transformers: {
		(t.#FooTransformer.metadata.fqn): t.#FooTransformer
	}
}

shipped: catalogFQN: catalog.metadata.fqn
