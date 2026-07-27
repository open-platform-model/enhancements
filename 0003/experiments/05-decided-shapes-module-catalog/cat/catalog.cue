// The catalog manifest, as an author writes it.
//
// Compare with catalog_opm/src/catalog.cue today, which declares BOTH
// "modulePath: id.ModulePath" and "version: id.Version" in metadata. Under
// Reading B the version line is gone from the catalog root entirely — only
// the primitives carry it, read straight from identity.
package cat

import (
	c "enhancements.opmodel.dev/0003/exp05/core"
	t "enhancements.opmodel.dev/0003/exp05/cat/transformers"
)

c.#Catalog

// metadata.modulePath is NOT here either. Under D25 it is generated into this
// package (gen_identity.cue) from identity/. The catalog still NEEDS the
// identity/ subpackage — its resources/ and transformers/ leaves read
// id.ModulePath to compute their own FQNs, and experiment 03 measured that
// removing it makes root and leaves import each other.

// Keyed by each transformer's own major-keyed fqn, exactly as today.
#transformers: {
	(t.#ConfigMapTransformer.metadata.fqn): t.#ConfigMapTransformer
}
