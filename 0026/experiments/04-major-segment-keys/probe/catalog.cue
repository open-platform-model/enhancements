package core

// WHY it is authored this way. The full authoring shape:
//
//
//   // library/modules/opm/catalog.cue
//   package opm
//
//   import (
//       c  "opmodel.dev/core@v2"
//       id "opmodel.dev/catalogs/opm/identity"
//       t  "opmodel.dev/catalogs/opm/transformers"
//       tr "opmodel.dev/catalogs/opm/traits"
//   )
//
//   c.#Catalog
//   metadata: {
//       modulePath:  id.ModulePath  // "opmodel.dev/catalogs/opm@v1"
//       version:     id.Version
//       description: "OPM core catalog"
//   }
//   #traits: {
//       (tr.#BackupTrait.metadata.fqn):  tr.#BackupTrait
//       (tr.#ScalingTrait.metadata.fqn): tr.#ScalingTrait
//   }
//   #transformers: {
//       (t.#ConfigMapTransformer.metadata.fqn):  t.#ConfigMapTransformer
//       (t.#DeploymentTransformer.metadata.fqn): t.#DeploymentTransformer
//   }
//
// Catalog identity lives in a sibling `identity/` subpackage so transformer
// subpackages can source it without a circular import. That subpackage is a
// COMMITTED `identity/identity.cue` (0010:D5): it holds the real
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
// `metadata.fqn`: under 0010:D21 an fqn is AUTHORED at the
// definition site rather than derived, and the map key already carries the
// transformer's own fqn. 0001:D18 lockstep on the build stays structural, since
// the stamp is what supplies the key's version component.
//
// `M=metadata` is a field-label alias (0001:D25). It binds the
// label `M` to the metadata field path so the pattern constraint can reach
// `M.modulePath` and `M.version` across the nested struct boundary. The
// value-alias form `metadata: M={...}` does NOT carry across this boundary
// and fails cue vet with "reference M not found". Experiment 09 validated
// both sound forms (label alias + hidden mirror); the label alias is
// chosen for inline locality.
//
// The contract maps (#resources, #traits, #blueprints) list what the catalog
// DEFINES, separately from what its #transformers implement (enhancement
// 0015:D1): a `fulfilment: "provider"` contract ships no adapter and was
// otherwise invisible to a subscribing platform. Each map stamps the same
// two fields the transformer map does, but its modulePath stamp carries the
// member's own apiVersion as the filing segment (0010:D49) — the value
// #CatalogMemberFQNGate derives at publish — read through an `A=apiVersion`
// label alias: a bare `apiVersion` inside the stamp literal is "reference
// apiVersion not found", because lexical resolution sees only the fields the
// literal itself declares, not those the primitive supplies by unification
// (measured on cue v0.17.1). The transformer stamp stays flat: a transformer
// carries no apiVersion (0010:D44). SPEC.md § 3.6 Rationale, "Why a single
// `#Catalog` construct instead of a `#Module.#defines` block", "Why the
// `M=metadata` field-label alias", "Why the pattern stamps `modulePath` +
// `catalogVersion` but not `fqn`", "Why a catalog publishes its contracts as
// members", "Why the contract stamp carries the member's apiVersion segment
// while the transformer stamp does not" and "Why the member is the primitive
// itself rather than a projection".

// #Catalog: top-level catalog definition. Authoring shape uses the modules
// pattern — bare `c.#Catalog` at file root, fields written at package level,
// no `Catalog:` wrapper; identity comes from the sibling `identity/` package.
// Publishes the contracts it defines (#resources, #traits, #blueprints)
// beside the transformers that implement them (#transformers). See SPEC.md § 3.6.
#Catalog: {
	kind: "Catalog"
	M=metadata: {
		modulePath!: #ModulePathType // Example: "opmodel.dev/catalogs/opm@v1"

		// No "0.0.0-dev" default: an unfilled version is an incomplete value
		// naming this field, rather than one that renders successfully while
		// being wrong.
		version!: #VersionType

		// WHY fqn: 0010:D1.

		// fqn IS the module path — the version no longer joins it, and
		// #CatalogFQNType retires with the derivation it typed.
		fqn: #ModulePathType & modulePath

		// The one decomposition of modulePath. registryPath is what the
		// member stamps below are built on.
		_ref: #ArtifactRef & {"modulePath": modulePath}

		// NO version/path major assertion here, deliberately — 0010:D43, the same
		// holding #Module carries under 0010:D45. `identity/identity.cue` asserts
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

	// WHY one stamping rule for three maps, and why it reads apiVersion
	// through a label alias: the file header. #traits and #blueprints below
	// carry the same stamp under their own kind segment and point here.

	// WHY #resources: 0015:D1.

	// resources: the #Resource contracts this catalog DEFINES, keyed by contract
	// fqn; listing one requires no adapter. Stamps metadata.modulePath to
	// "<registryPath>/resources/<apiVersion>" and metadata.catalogVersion to the
	// catalog's version, never fqn; an authored value that disagrees is a
	// conflict. See SPEC.md § 3.6.
	#resources: [#ContractFQNType]: #Resource & {
		metadata: {
			A=apiVersion:   #APIVersionType
			modulePath:     "\(M._ref.registryPath)/resources/\(A)"
			catalogVersion: M.version
		}
	}

	// traits: the #Trait contracts this catalog DEFINES, keyed by contract
	// fqn; the #resources stamp under the `traits` segment. A `fulfilment:
	// "provider"` trait is listed here and implemented nowhere in this
	// catalog: this map is what makes it visible. See SPEC.md § 3.6.
	#traits: [#ContractFQNType]: #Trait & {
		metadata: {
			A=apiVersion:   #APIVersionType
			modulePath:     "\(M._ref.registryPath)/traits/\(A)"
			catalogVersion: M.version
		}
	}

	// blueprints: the #Blueprint contracts this catalog DEFINES, keyed by
	// contract fqn; the #resources stamp under the `blueprints` segment.
	// See SPEC.md § 3.6.
	#blueprints: [#ContractFQNType]: #Blueprint & {
		metadata: {
			A=apiVersion:   #APIVersionType
			modulePath:     "\(M._ref.registryPath)/blueprints/\(A)"
			catalogVersion: M.version
		}
	}

	#transformers: [#ImplFQNType]: #ComponentTransformer & {
		metadata: {
			// The major is split out and NOT re-appended: a transformer
			// declares a #PackagePathType, which admits no "@vN".
			modulePath: "\(M._ref.registryPath)/transformers"

			// WHY catalogVersion: 0010:D25.

			// The catalog's own version IS the build every member of it shipped
			// in, stamped rather than authored per leaf.
			catalogVersion: M.version
		}
	}
}
