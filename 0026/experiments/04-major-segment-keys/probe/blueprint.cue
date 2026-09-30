package core

import (
	"strings"
)

// #Blueprint: Defines a reusable blueprint
// that composes resources and traits into a higher-level abstraction.
// Blueprints enable standardized configurations for common use cases.
#Blueprint: {
	kind: "Blueprint"

	metadata: {
		name!: #NameType // Example: "stateless-workload"
		#definitionName: (#KebabToPascal & {"in": name}).out

		// WHY never an arbitrary grouping: #CatalogMemberFQNGate compares this
		// against kindPrefix.blueprints + "/" + apiVersion by EQUALITY, so a
		// blueprint filed flat or under any other segment is refused at
		// publish.

		// WHY modulePath: 0010:D42 as amended by 0010:D49.

		// Exactly "<catalog registryPath>/blueprints/<apiVersion>" — one base
		// segment per kind and one version segment beneath it, DERIVED from this
		// blueprint's own apiVersion. The version segment never enters the fqn. See
		// SPEC.md § 3.3.
		modulePath!: #PackagePathType // Example: "opmodel.dev/catalogs/opm/blueprints/v1beta1"

		// WHY apiVersion: 0010:D4; 0010:D44.

		// apiVersion: this contract's own level, and the only component of its key.
		// A blueprint carries one because it is a PRIMITIVE: it composes resources
		// and traits rather than introducing vocabulary, but a module attaches it
		// and writes against its `spec`, so it earns the contract key and the
		// additive-only promise that key gates.
		apiVersion!: #APIVersionType // Example: "v1beta1"

		// WHY catalogVersion: 0010:D25.

		// catalogVersion: the catalog build this definition shipped in. Provenance
		// only — no contract key interpolates it.
		catalogVersion!: #VersionType // Example: "1.0.0"

		// WHY fqn: 0010:D21.

		// fqn: AUTHORED by the catalog at the definition site, not derived here, so
		// fqn, modulePath and catalogVersion trace to one identity package and a
		// release moves them together. `core` no longer refuses a value disagreeing
		// with this definition's own fields; #CatalogMemberFQNGate asserts that
		// agreement at publish.
		fqn!: #ContractFQNType // Example: "opmodel.dev/catalogs/opm/blueprints/stateless-workload@v1beta1"

		// Human-readable description of the definition
		description?: string

		// WHY labels: 0010:D36.

		// Optional metadata labels for CATEGORIZATION. Descriptive only — nothing
		// selects on these, and they are never unified upward into a #Component.
		// Example: {"blueprint.opmodel.dev/category": "workload"}
		labels?: #LabelsAnnotationsType

		// Optional metadata annotations for definition behavior hints (not used for categorization)
		// Annotations provide additional metadata but are not used for selection
		annotations?: #LabelsAnnotationsType
	}

	// WHY a blueprint typically answers the key: a blueprint is where the
	// workload-type key is typically CONCRETE: it composes a container that
	// declares the key required and answers it, so attaching the blueprint
	// is what makes the component's matching identity complete. See
	// #Resource.matchLabels for why the two cannot be one field. NOT
	// rendered: matchLabels does not reach #TransformerContext.

	// WHY matchLabels: 0010:D36.

	// matchLabels: this blueprint's MATCHING identity — the keys a
	// #ComponentTransformer.requiredLabels predicate selects on, unified
	// wholesale into every #Component that attaches this blueprint. Separate from
	// metadata.labels. NOT rendered. See SPEC.md § 3.3.
	matchLabels?: #LabelsAnnotationsType // Example: {"opm.opmodel.dev/workload-type": "stateful"}

	// WHY: see #Resource.#nameConstraint. The rule and its measured pitfalls are
	// stated once there (SPEC.md § 2.1 Rationale, "Why the primitive declares
	// the name rule and the component asserts it"); this slot is the same slot.

	// WHY #nameConstraint: 0019:D21; 0019:D23.

	// nameConstraint: the name rule a kind this primitive renders enforces on the
	// owning component's metadata.resourceName; top when the primitive is
	// indifferent, which is the default. A hidden definition field: never
	// optional, never guarded on presence. MAY be computed from this primitive's
	// own fields. See SPEC.md § 3.3.
	#nameConstraint: _

	// NO fulfilment field, and the exclusion is STRUCTURAL rather than an
	// omission: #ComponentTransformer carries requiredResources and
	// requiredTraits and has no blueprint equivalent, so nothing can ever
	// DEMAND a blueprint and the field would name a question no matcher
	// asks. A blueprint's fulfilment is that of the contracts it composes,
	// each of which declares its own.
	//
	// Because this struct is a definition it is CLOSED, so supplying
	// `fulfilment` here is a `field not allowed` error rather than a field
	// nothing reads — see the pinned case in platform_and_match_pins.cue.
	// This is the same reasoning that keeps apiVersion off a transformer
	// (0010:D44): a shape that admits a field nobody reads hands
	// every future field to the wrong kind for free.

	// Resources that compose this blueprint (full references)
	composedResources!: [...#Resource]

	// Traits that compose this blueprint (full references)
	composedTraits?: [...#Trait]

	// MUST be an OpenAPIv3 compatible schema
	// The field and schema exposed by this definition
	spec!: (strings.ToCamel(metadata.#definitionName)): _
}

#BlueprintMap: [string]: #Blueprint
