// Resource writes a typo in its subpath — `/resorces/workload` instead of
// `/resources/workload`. Expected: vet SUCCEEDS — `#Resource` does NOT have
// a schema-stamping pattern constraint on its `metadata.modulePath`; the
// typo is just a regex-valid string, and there's nothing on the catalog
// side that would unify it against a canonical value. The drift ships
// silently. This is the deliberate residual surface D19 + D21 acknowledge.
package resource_typo_subpath

import (
	s  "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/schema"
	id "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/identity"
)

#ContainerResource: s.#Resource & {
	metadata: {
		name:       "container"
		modulePath: "\(id.ModulePath)/resorces/workload" // typo: resorces (residual surface)
		version:    id.Version
	}
	spec: container: image: "nginx"
}

// Public reader to surface the would-be wrong fqn.
shipped: #ContainerResource.metadata
