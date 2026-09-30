package core

import (
	"strings"
)

// #Resource: Defines a resource of deployment within the system.
// Resources represent deployable components, services or resources that can be instantiated and managed independently.
#Resource: {
	kind: "Resource"

	metadata: {
		name!: #NameType // Example: "container"
		#definitionName: (#KebabToPascal & {"in": name}).out

		// SCOPED-MATCHING PROBE: catalog is the defining catalog's module path,
		// major included, DERIVED from modulePath (registryPath + kind + apiVersion)
		// and the major of catalogVersion. Never authored. It is the scope a
		// contract key is matched and counted in.
		catalog: #ModulePathType & "\(strings.TrimSuffix(modulePath, "/resources/"+apiVersion))@v\(strings.Split(catalogVersion, ".")[0])"

		modulePath!: #PackagePathType // Example: "opmodel.dev/catalogs/opm/resources/v1beta1" (kind prefix + this resource's own apiVersion, 0010:D49)

		// WHY a field rather than an interpolation: it is the one identity
		// value on a primitive that is NOT derivable from its catalog's
		// identity package: it is a judgement the author makes. SPEC.md § 2.1
		// Rationale, "Why the key carries `apiVersion` and not
		// `catalogVersion`".

		// WHY apiVersion: 0010:D4.

		// apiVersion: this contract's own level, and the only component of its key.
		// Moved when this resource's shape breaks — a catalog release does not move
		// it, which is what lets a module's demand survive one. See SPEC.md § 2.1.
		apiVersion!: #APIVersionType // Example: "v1beta1"

		// WHY catalogVersion: 0010:D25.

		// catalogVersion: the catalog build this definition shipped in. Provenance
		// only — no contract key interpolates it. It is what lets a diagnostic say
		// "this platform's provider was built against 1.0.0; this module needs
		// 1.3.0" when the shapes are compatible but the provider lags.
		catalogVersion!: #VersionType // Example: "1.0.0"

		// WHY authored: the catalog interpolates it from its own identity
		// package, so fqn, modulePath and catalogVersion all trace to one
		// source and a release moves them together. `core` therefore no longer
		// refuses a value disagreeing with this definition's own name or path.
		// Enforcement MOVES rather than disappearing. SPEC.md § 2.1 Rationale,
		// "Why `fqn` is authored rather than computed, and what replaces the
		// check that lost".

		// WHY fqn: 0010:D21.

		// fqn: AUTHORED by the catalog at the definition site, not derived here.
		// `core` does not check it against this definition's own name or path;
		// #CatalogMemberFQNGate asserts the agreement at publish. See SPEC.md § 2.1.
		fqn!: #ContractFQNType // Example: "opmodel.dev/catalogs/opm/resources/container@v1beta1"

		// Human-readable description of the definition
		description?: string

		// WHY labels: 0010:D36.

		// Optional metadata labels for CATEGORIZATION. Descriptive only — nothing
		// selects on these, and they are never unified upward into a #Component.
		// Matching lives in matchLabels below. Example:
		// {"resource.opmodel.dev/category": "workload"}
		labels?: #LabelsAnnotationsType

		// Optional metadata annotations for definition behavior hints (not used for categorization)
		// Annotations provide additional metadata but are not used for selection
		annotations?: #LabelsAnnotationsType
	}

	// WHY deliberately not metadata.labels. The two were one field, and the
	// upward union that implied cannot be built: categorisation labels
	// legitimately disagree between primitives — "workload" on a container,
	// "storage" on volumes, "config" on config maps — so a full union fails
	// on the first real component. Every FILTERED union measured had to
	// iterate, and CUE refuses to iterate a struct holding an unset required
	// field, which forced dropping `!` from the one label a module author
	// must pick. Separating the fields removes the filter and both costs.
	//
	// Because the union embeds structs rather than iterating them, a REQUIRED
	// key survives it: a primitive MAY declare `matchLabels: "<key>"!: <disj>`
	// and the component reports that field unset rather than silently
	// carrying an incomplete value.
	//
	// `core` names no key here — the matching vocabulary belongs to the
	// catalog that defines it, by construction rather than by `core` agreeing
	// not to look at some keys.
	//
	// NOT rendered: matchLabels does not reach #TransformerContext, so it
	// appears on no rendered object (0010:D36). SPEC.md § 2.1 Rationale, "Why
	// matching has its own field instead of riding on `metadata.labels`",
	// "Why `core` names no matching key" and "Why `matchLabels` is not
	// rendered".

	// matchLabels: this resource's MATCHING identity — the keys a
	// #ComponentTransformer.requiredLabels predicate selects on. A #Component
	// unifies its attached primitives' matchLabels WHOLESALE, so every key
	// written here participates in matching and nothing else does. A key MAY
	// be declared required (`"<key>"!: <disj>`). Never rendered. See SPEC.md
	// § 2.1.
	matchLabels?: #LabelsAnnotationsType // Example: {"opm.opmodel.dev/workload-type": "stateless"}

	// WHY the primitive declares it: #Component collects every attached
	// primitive's slot into one conjunction and asserts the resolved name
	// against it, so the primitive that introduces a dot-hostile kind is the
	// one that declares the rule and core carries no per-kind knowledge.
	// Unifying top costs nothing.
	//
	// WHY not optional and never guarded on presence: measured on cue
	// v0.17.1, `x.#nameConstraint != _|_` is false for a non-concrete value,
	// so an optional slot behind an existence guard silently never propagates
	// while the code reads correctly.
	//
	// WHY it may be computed (0019:D23): the catalog's container resource
	// declares #NameType when its own workload-type key reads "stateful" and
	// top otherwise, in list-index form so a default arm cannot win over the
	// concrete one. SPEC.md § 2.1 Rationale, "Why the primitive declares the
	// name rule and the component asserts it".

	// WHY #nameConstraint: 0019:D21; 0019:D23.

	// nameConstraint: the name rule a kind this primitive renders enforces on the
	// owning component's metadata.resourceName; top when the primitive is
	// indifferent, which is the default. A hidden definition field: never
	// optional, never guarded on presence. MAY be computed from this primitive's
	// own fields. See SPEC.md § 2.1.
	#nameConstraint: _

	// WHY each value:
	//
	//   "catalog"  — the declaring catalog implements it. Today's behaviour,
	//                and the default, so nothing opts in by accident.
	//   "provider" — the declaring catalog ships NO transformer for it,
	//                deliberately, and a platform must carry EXACTLY ONE
	//                registry entry (path with major) whose transformers
	//                require this contract. Two are refused by the render
	//                build naming both registry keys and the contract key;
	//                zero is an unresolved
	//                demand and fails the render.
	//
	// A declaration, not an enforcement: `core` cannot refuse on a count
	// across a platform's enabled catalogs, so the guard is the kernel's.
	// Stating the intent here is what gives the kernel something to count
	// against — today the concept cannot be expressed at all, and a
	// transformerless contract is indistinguishable from an oversight.
	//
	// Detecting competing providers by predicate equality was measured to
	// have no false positives today and rejected for false-NEGATIVES on the
	// real case (a hypothetical `backup` contract): a k8up transformer
	// requiring backup + schedule and a Velero transformer requiring backup
	// alone are two providers of one contract, and their predicates differ.
	// Why it is declared rather than derived, why a closed enum and why
	// exactly one provider: SPEC.md § 2.1 Rationale, "Why a contract declares
	// where its fulfilment comes from, rather than the platform inferring
	// it", "Why a closed enum and not a boolean `providedExternally`" and
	// "Why exactly one provider, with no arbitration between two".

	// WHY fulfilment: 0010:D32.

	// fulfilment: where this contract's implementation is expected to come from.
	// "catalog" (the default): the declaring catalog implements it. "provider":
	// the catalog ships no transformer and a platform must carry EXACTLY ONE
	// registry entry (path with major) whose transformers require it. A
	// declaration the kernel counts against, not an enforcement. See SPEC.md
	// § 2.1.
	fulfilment: *"catalog" | "provider"

	// MUST be an OpenAPIv3 compatible schema
	// The field and schema exposed by this definition
	spec!: (strings.ToCamel(metadata.#definitionName)): _
}

#ResourceMap: [string]: #Resource
