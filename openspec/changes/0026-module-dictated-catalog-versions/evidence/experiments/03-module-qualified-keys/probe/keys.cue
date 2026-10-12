package core

// Key shapes, key decomposition, the publish gate and the one-major-per-
// lineage rule: the cases that evaluate.

typeLegacy:                  #ContractFQNType & "opmodel.dev/catalogs/opm/traits/backup@v1alpha1"
typeQualified:               #ContractFQNType & "opmodel.dev/catalogs/opm@v5/traits/backup@v1alpha1"
typeSlashMajorIsAModulePath: #ModulePathType & "opmodel.dev/catalogs/opm/v4@v0"

refQualified: #ContractRef & {fqn: "opmodel.dev/catalogs/opm@v5/traits/backup@v1alpha1"}
refLegacy: #ContractRef & {fqn: "opmodel.dev/catalogs/opm/traits/backup@v1alpha1"}

// Gate.
_id5: #IdentityPackage & {ModulePath: "opmodel.dev/catalogs/opm@v5", Version: "5.0.0"}
_id4: #IdentityPackage & {ModulePath: "opmodel.dev/catalogs/opm@v4", Version: "4.4.2", ContractScope: "registry"}
gateV5Qualified: #CatalogMemberFQNGate & {identity: _id5, kind: "traits", name: "backup", declaredAPIVersion: "v1alpha1", declaredFQN: "opmodel.dev/catalogs/opm@v5/traits/backup@v1alpha1", declaredModulePath: "opmodel.dev/catalogs/opm/traits/v1alpha1", declaredCatalogVersion: "5.0.0"}
gateV4Legacy: #CatalogMemberFQNGate & {identity: _id4, kind: "traits", name: "backup", declaredAPIVersion: "v1alpha1", declaredFQN: "opmodel.dev/catalogs/opm/traits/backup@v1alpha1", declaredModulePath: "opmodel.dev/catalogs/opm/traits/v1alpha1", declaredCatalogVersion: "4.4.2"}
gateV5Transformer: #CatalogMemberFQNGate & {identity: _id5, kind: "transformers", name: "deployment-transformer", declaredFQN: "opmodel.dev/catalogs/opm/transformers/deployment-transformer@5.0.0", declaredModulePath: "opmodel.dev/catalogs/opm/transformers", declaredCatalogVersion: "5.0.0"}

// One declaring major per lineage inside one component: unification of the
// per-lineage declaring module IS the check.
#OneMajorPerLineage: {
	keys: [...#ContractFQNType]
	by: {for k in keys let r = (#ContractRef & {fqn: k}) if r.qualified {(r.lineage): r.declaringModule}}
}
mixOK: #OneMajorPerLineage & {keys: ["opmodel.dev/catalogs/opm@v5/resources/container@v1beta1", "opmodel.dev/catalogs/opm@v5/traits/expose@v1beta1", "opmodel.dev/catalogs/k8up@v2/traits/x@v1"]}
lineageHint: (#ContractRef & {fqn: "opmodel.dev/catalogs/opm@v5/traits/backup@v1alpha1"}).lineageKey == "opmodel.dev/catalogs/opm/traits/backup@v1alpha1"
