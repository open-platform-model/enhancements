// Catalog manifest, written the way catalog_opm/src/catalog.cue is written
// today: embeds bare c.#Catalog, sources metadata from the sibling identity/
// package, enumerates every transformer keyed by its own metadata.fqn.
//
// Nothing here changed for this enhancement. What changed is what
// id.ModulePath now HOLDS (the complete path with major) and what id.Version
// now IS (a concrete committed value or an open field, never a sentinel).
package demo

import (
	c "example.com/exp0010/core"
	id "example.com/exp0010/cat/identity"
	t "example.com/exp0010/cat/transformers"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Demo catalog — one resource, one transformer"
}

#transformers: {
	(t.#ConfigMapTransformer.metadata.fqn): t.#ConfigMapTransformer
}
