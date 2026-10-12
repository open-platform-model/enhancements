@if(refused)

package core

// Gate inputs the patched core refuses. Evaluated only with -t refused.

gateV5FlatRefused: #g & {identity: _id5, kind: "resources", name: "container", declaredFQN: "opmodel.dev/catalogs/opm/resources/container@v1beta1", declaredModulePath: "opmodel.dev/catalogs/opm/resources/v1beta1", declaredCatalogVersion: "5.0.0", declaredAPIVersion: "v1beta1"}
gateV5WrongMajorRefused: #g & {identity: _id5, kind: "traits", name: "backup", declaredFQN: "opmodel.dev/catalogs/opm/v4/traits/backup@v1alpha1", declaredModulePath: "opmodel.dev/catalogs/opm/traits/v1alpha1", declaredCatalogVersion: "5.0.0", declaredAPIVersion: "v1alpha1"}

txBridge: #TransformerOwnMajorGate & {identity: _id6, required: ["opmodel.dev/catalogs/opm/v5/resources/container@v1beta1"]}
txFlat: #TransformerOwnMajorGate & {identity: _id6, required: ["opmodel.dev/catalogs/opm/resources/container@v1beta1"]}
