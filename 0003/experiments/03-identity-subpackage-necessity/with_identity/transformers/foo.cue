// Subpackage sources identity from the sibling identity package.
package transformers

import id "enhancements.opmodel.dev/0003/experiments/03-identity-subpackage-necessity/with_identity/identity"

#FooTransformer: {
	kind: "ComponentTransformer"
	metadata: {
		name:       "foo"
		modulePath: "\(id.ModulePath)/transformers"
		version:    id.Version
		fqn:        "\(modulePath)/\(name)@\(version)"
	}
}
