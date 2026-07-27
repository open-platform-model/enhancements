// The assembled scenario a reviewer reads: does the module match the catalog,
// and does the platform clear the floor. Values print via `cue eval`.
package exp05

import (
	"list"
	m "enhancements.opmodel.dev/0003/exp05/mod"
	cat "enhancements.opmodel.dev/0003/exp05/cat"
	p "enhancements.opmodel.dev/0003/exp05/platform"
)

// What the module demands, and what the catalog supplies.
moduleDemands: m.#components.web.demands
catalogSupplies: [ for fqn, t in cat.#transformers for r in t.requiredResources {r}]

// Identity, which must NOT move between catalog releases.
moduleFQN:  m.metadata.fqn
moduleUUID: m.metadata.uuid
catalogFQN: cat.metadata.fqn

// The compatibility signal, which DOES move.
builtAgainstCatalog: m.builtAgainstCatalog

// Does every demanded FQN appear in what the catalog supplies?
matched: [ for d in moduleDemands if list.Contains(catalogSupplies, d) {d}]

// The floor check against a platform that materialized 1.2.0.
floor: p.#CatalogFloor & {
	requiredVersion: builtAgainstCatalog
	resolvedVersion: "1.2.0"
}
