// Transformer in catalog_a that references a resource owned by catalog_b
// via standard CUE import. When catalog_b is present on disk (both_subscribed
// scenario), this import resolves and the transformer's requiredResources
// stamps catalog_b's #BarResource by its FQN. When catalog_b is absent
// (b_missing scenario), this exact file fails at cue evaluation with a
// "cannot find package" error — which the kernel would wrap as a
// MaterializeError at Materialize time.
package transformers

import (
	s "test.example/cross-catalog/schema"
	b "test.example/cross-catalog/catalog_b/resources"
)

// Definition (`#`-prefixed) for the transformer. metadata.modulePath and
// metadata.version are deliberately omitted from this definition — the
// `#Catalog.#transformers` pattern constraint stamps them when the
// transformer is placed inside a catalog (mirrors production catalog layout).
// Use `#FooTransformer` as a closed schema value the catalog instantiates;
// don't reference its fqn outside the catalog manifest.
#FooTransformer: s.#ComponentTransformer & {
	metadata: {
		name:        "foo"
		description: "exercises cross-catalog primitive reference (D16)"
	}
	requiredResources: {
		(b.#BarResource.metadata.fqn): b.#BarResource
	}
}
