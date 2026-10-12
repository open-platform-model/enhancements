package core

// The patched #CatalogMemberFQNGate: inputs it accepts.
#g: #CatalogMemberFQNGate
gateV5Container: #g & {identity: _id5, kind: "resources", name: "container", declaredFQN: _opm5.container.metadata.fqn, declaredModulePath: "opmodel.dev/catalogs/opm/resources/v1beta1", declaredCatalogVersion: "5.0.0", declaredAPIVersion: "v1beta1"}
gateV5MinorSameKey: #g & {identity: _id5b, kind: "resources", name: "container", declaredFQN: "opmodel.dev/catalogs/opm/v5/resources/container@v1beta1", declaredModulePath: "opmodel.dev/catalogs/opm/resources/v1beta1", declaredCatalogVersion: "5.3.1", declaredAPIVersion: "v1beta1"}
gateV5Transformer: #g & {identity: _id5b, kind: "transformers", name: "deployment-transformer", declaredFQN: "opmodel.dev/catalogs/opm/v5/transformers/deployment-transformer@5.3.1", declaredModulePath: "opmodel.dev/catalogs/opm/transformers", declaredCatalogVersion: "5.3.1"}
