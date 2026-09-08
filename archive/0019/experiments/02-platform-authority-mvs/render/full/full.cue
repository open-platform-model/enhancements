// TIER 2 READOUT. Same as `probe`, plus the consumer module IMPORTED.
//
// Two things it adds:
//
//  1. Whether importing a module changes resolution versus merely depending on
//     it (compare with `probe`).
//  2. Where version skew becomes visible as a BUILD failure rather than as a
//     silently different answer. A consumer authored against one catalog and
//     evaluated against another either compiles or does not, and which one
//     happens is worth recording per case.
package full

import (
	catalog "opmodel.dev/catalogs/opm@v2"
	consumer "experiments.opmodel.dev/0019/authority/consumer@v0"
	platform "experiments.opmodel.dev/0019/authority/platform@v0"
)

catalogVersionResolved: catalog.metadata.version
platformCatalogVersion: platform.#catalogVersionResolved

// The consumer's own view of the same path. In ONE build there is exactly one
// answer per path@major, so this must equal catalogVersionResolved. When it
// does, the consumer is evaluating against the platform's catalog rather than
// against the one its own cue.mod names, which is the behaviour the design
// turns on.
catalogVersionSeenByConsumer: consumer.#catalogVersionResolved

consumerComponents: [for id, _ in consumer.#components {id}]
