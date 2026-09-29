// The declaring catalog: publishes backup and backup-command, both
// provider-fulfilled, and ships no transformer (0010 D37). The
// executor: module projection is a plain function in contracts/projection
// that every provider adapter calls.
package contracts

import (
	c "opmodel.dev/core@v2"
	id "testing.opmodel.dev/experiments/0015/exp02/contracts/identity"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/02: declaring catalog for backup and backup-command"
}

#transformers: {}
