package core

// #Catalog: top-level catalog definition. Authoring shape uses the modules
// pattern — bare `c.#Catalog` at file root, fields written at package level,
// no `Catalog:` wrapper:
//
//   // library/modules/opm/catalog.cue
//   package opm
//
//   import (
//       c  "opmodel.dev/core@v2"
//       id "opmodel.dev/catalogs/opm/identity"
//       t  "opmodel.dev/catalogs/opm/transformers"
//   )
//
//   c.#Catalog
//   metadata: {
//       modulePath:  id.ModulePath  // "opmodel.dev/catalogs/opm@v1"
//       version:     id.Version
//       description: "OPM core catalog"
//   }
//   #transformers: {
//       (t.#ConfigMapTransformer.metadata.fqn):  t.#ConfigMapTransformer
//       (t.#DeploymentTransformer.metadata.fqn): t.#DeploymentTransformer
//   }
//
// Catalog identity lives in a sibling `identity/` subpackage so transformer
// subpackages can source it without a circular import. That subpackage is a
// COMMITTED `identity/identity.cue` (enhancement 0010 D5): it holds the real
// ModulePath and Version, so a checkout and a published artifact compute the
// same values. It replaces the earlier arrangement, in which the committed
// tree carried a placeholder version and publish stamped the real one into a
// generated `identity/version_override.cue` — under which a local render
// demanded ".../transformers/deployment@0.0.0-dev" while the registry supplied
// ".../transformers/deployment@1.0.0".
//
// The pattern constraint on `#transformers` stamps every entry's
// `metadata.modulePath` to "\(_ref.registryPath)/transformers" — the MAJOR-FREE
// path, because a transformer declares a #PackagePathType — and
// `metadata.catalogVersion` to the catalog's version. It does NOT stamp
// `metadata.fqn`: under enhancement 0010 D21 an fqn is AUTHORED at the
// definition site rather than derived, and the map key already carries the
// transformer's own fqn. D18 lockstep on the build stays structural, since
// the stamp is what supplies the key's version component.
//
// `M=metadata` is a field-label alias (enhancement 0001 D25). It binds the
// label `M` to the metadata field path so the pattern constraint can reach
// `M.modulePath` and `M.version` across the nested struct boundary. The
// value-alias form `metadata: M={...}` does NOT carry across this boundary
// and fails cue vet with "reference M not found". Experiment 09 validated
// both sound forms (label alias + hidden mirror); the label alias is
// chosen for inline locality.
//
// Resources / Traits / Blueprints are surfaced transitively via each
// transformer's required/optional maps. Adding sibling maps (#resources,
// #traits, #blueprints) is an additive extension if introspection demand
// surfaces later.
#Catalog: {
	kind: "Catalog"
	M=metadata: {
		modulePath!: #ModulePathType // Example: "opmodel.dev/catalogs/opm@v1"

		// No "0.0.0-dev" default: an unfilled version is an incomplete value
		// naming this field, rather than one that renders successfully while
		// being wrong.
		version!: #VersionType

		// fqn IS the module path (enhancement 0010 D1) — the version no longer
		// joins it, and #CatalogFQNType retires with the derivation it typed.
		fqn: #ModulePathType & modulePath

		// The one decomposition of modulePath. registryPath is what the
		// #transformers stamp below is built on.
		_ref: #ArtifactRef & {"modulePath": modulePath}

		// NO version/path major assertion here, deliberately — D43, the same
		// holding #Module carries under D45. `identity/identity.cue` asserts
		// VersionMajor == Major at the point both values are WRITTEN; `core`
		// re-deriving it one hop downstream tests the same relation over the
		// same two values. The exposure — a catalog whose identity package is
		// absent or non-conformant carries no consumer-runnable major check,
		// and the skew surfaces in a platform author's file instead — is
		// accepted and bounded by enhancement 0011's publish gates.

		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	#transformers: [#ImplFQNType]: #ComponentTransformer & {
		metadata: {
			// The major is split out and NOT re-appended: a transformer
			// declares a #PackagePathType, which admits no "@vN".
			modulePath: "\(M._ref.registryPath)/transformers"

			// The catalog's own version IS the build every member of it
			// shipped in — enhancement 0010 D25's rename, stamped rather
			// than authored per leaf.
			catalogVersion: M.version
		}
	}
}
