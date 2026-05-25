// Blueprint writes a typo in its subpath — `/blueprnts/web-app` instead of
// `/blueprints/web-app`. Expected: vet SUCCEEDS — same residual surface as
// resources and traits (no schema-stamping pattern on `#Blueprint`).
package blueprint_typo_subpath

import (
	s  "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/schema"
	id "enhancements.opmodel.dev/0001/experiments/10-catalog-stamping-asymmetry/identity"
)

#WebAppBlueprint: s.#Blueprint & {
	metadata: {
		name:       "web-app"
		modulePath: "\(id.ModulePath)/blueprnts/web-app" // typo: blueprnts (residual surface)
		version:    id.Version
	}
	spec: {}
}

shipped: #WebAppBlueprint.metadata
