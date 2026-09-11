// Copied shape: catalog_opm/opm/catalog.cue. The stand-in for catalog_opm as
// the DECLARING catalog of 0015's motivating contract: it publishes the
// backup trait and deliberately ships no transformer for it (0010 D37,
// fulfilment "provider"). #transformers is empty on purpose: today that
// means the contract reaches no bucket, which is the 0015 D1 premise this
// experiment measures in case C.
package contracts

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/experiments/0015/contracts/identity"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/01: declaring catalog for the provider-fulfilled backup trait"
}

#transformers: {}
