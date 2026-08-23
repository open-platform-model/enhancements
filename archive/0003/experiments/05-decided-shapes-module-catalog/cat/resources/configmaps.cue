// A catalog resource, as an author writes it. Note what is ABSENT: no
// modulePath, no version. Both come from the generated identity package.
package resources

import (
	c "enhancements.opmodel.dev/0003/exp05/core"
	id "enhancements.opmodel.dev/0003/exp05/cat/identity"
)

#ConfigMapsResource: c.#Resource & {
	metadata: {
		name: "config-maps"

		// modulePath: the catalog's registry path + "/resources", with the
		// catalog's major re-appended (D16 puts "@vN" mid-string).
		modulePath: (c.#SplitPath & {in: id.ModulePath}).registryPath + "/resources@" + (c.#SplitPath & {in: id.ModulePath}).major

		// version: the FULL catalog version — the compatibility signal (D19).
		// It is NOT in the fqn; core derives fqn from modulePath + name + major.
		version: id.Version
	}
}
