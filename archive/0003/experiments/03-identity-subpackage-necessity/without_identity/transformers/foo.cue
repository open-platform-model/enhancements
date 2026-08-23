// No identity package: the subpackage must reach BACK into the root catalog
// package to read the shared version.
package transformers

import root "enhancements.opmodel.dev/0003/experiments/03-identity-subpackage-necessity/without_identity"

#FooTransformer: {
	kind: "ComponentTransformer"
	metadata: {
		name:       "foo"
		modulePath: "\(root.Catalog.ModulePath)/transformers"
		version:    root.Catalog.Version
		fqn:        "\(modulePath)/\(name)@\(version)"
	}
}
