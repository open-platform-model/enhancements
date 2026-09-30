@if(refused)

package core

// Key shapes and gate inputs the patched core refuses. Evaluated only with
// -t refused; every field here is expected to fail.

typeNoKind:      #ContractFQNType & "opmodel.dev/catalogs/opm@v5/backup@v1alpha1"
typeTwoMajors:   #ContractFQNType & "opmodel.dev/catalogs/opm@v5@v6/traits/backup@v1alpha1"
typeSemverMajor: #ContractFQNType & "opmodel.dev/catalogs/opm@5.0.0/traits/backup@v1alpha1"
typeImplStill:   #ImplFQNType & "opmodel.dev/catalogs/opm@v5/transformers/x@5.0.0"
gateV5Legacy: #CatalogMemberFQNGate & {identity: _id5, kind: "traits", name: "backup", declaredAPIVersion: "v1alpha1", declaredFQN: "opmodel.dev/catalogs/opm/traits/backup@v1alpha1", declaredModulePath: "opmodel.dev/catalogs/opm/traits/v1alpha1", declaredCatalogVersion: "5.0.0"}
gateV4Qualified: #CatalogMemberFQNGate & {identity: _id4, kind: "traits", name: "backup", declaredAPIVersion: "v1alpha1", declaredFQN: "opmodel.dev/catalogs/opm@v4/traits/backup@v1alpha1", declaredModulePath: "opmodel.dev/catalogs/opm/traits/v1alpha1", declaredCatalogVersion: "4.4.2"}
gateV5WrongMajor: #CatalogMemberFQNGate & {identity: _id5, kind: "traits", name: "backup", declaredAPIVersion: "v1alpha1", declaredFQN: "opmodel.dev/catalogs/opm@v4/traits/backup@v1alpha1", declaredModulePath: "opmodel.dev/catalogs/opm/traits/v1alpha1", declaredCatalogVersion: "5.0.0"}
mixBad: #OneMajorPerLineage & {keys: ["opmodel.dev/catalogs/opm@v6/resources/container@v1beta1", "opmodel.dev/catalogs/opm@v5/traits/expose@v1beta1"]}
