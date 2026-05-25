// Trait writes a typo in its subpath — `/trais/scaling` instead of
// `/traits/scaling`. Expected: vet SUCCEEDS — same residual surface as
// resources (no schema-stamping pattern on `#Trait`).
package trait_typo_subpath

import (
	s  "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/schema"
	id "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/identity"
)

#ScalingTrait: s.#Trait & {
	metadata: {
		name:       "scaling"
		modulePath: "\(id.ModulePath)/trais/scaling" // typo: trais (residual surface)
		version:    id.Version
	}
	spec: replicas: int | *1
}

shipped: #ScalingTrait.metadata
