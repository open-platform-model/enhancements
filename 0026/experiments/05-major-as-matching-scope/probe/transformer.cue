package core

import (
	"strings"
)

// WHY #ComponentTransformer: 0010:D36.

// #ComponentTransformer: Declares how to convert OPM components into
// platform-specific resources. A transformer matches a component when ALL of
// the following are true: 1. ALL requiredLabels are present in the component's
// matchLabels with matching values 2. ALL requiredResources FQNs exist in
// component #resources 3. ALL requiredTraits FQNs exist in component #traits
// Matching never reads metadata.labels. See SPEC.md § 4.1.
#ComponentTransformer: {
	kind: "ComponentTransformer"

	// WHY no apiVersion: the absence is load-bearing rather than an
	// omission. Nothing would read one: this key interpolates catalogVersion,
	// the matcher keys on the CONTRACTS a transformer demands rather than on
	// the transformer, and the additive-only promise binds contracts. There is
	// no value to assign either — a transformer's inputs are other people's
	// contracts and its output is platform objects, so "this transformer's
	// contract major" has no referent. Worse than useless: with an apiVersion
	// present, the publish gate ("pull the last published build shipping this
	// name at this apiVersion, assert additive") resolves for transformers too,
	// and would then refuse ORDINARY catalog releases — changing rendering
	// logic, dropping an emitted field and narrowing an output type are all
	// normal transformer edits.
	//
	// Because this struct sits inside a definition it is CLOSED, so supplying
	// `apiVersion` here is a `field not allowed` error rather than a field
	// nothing reads. That is what makes the exclusion structural instead of
	// remembered — see the pinned case in identity_pins.cue.

	// WHY metadata: 0010:D44.

	// A transformer's identity shape is its OWN — it deliberately shares no
	// parent definition with the three primitives'. It carries NO apiVersion, and
	// the struct is CLOSED, so supplying one is a `field not allowed` error. See
	// SPEC.md § 4.1.
	metadata: {
		modulePath!: #PackagePathType // Example: "opmodel.dev/catalogs/opm/transformers"
		name!:       #NameType        // Example: "deployment-transformer"

		// WHY catalogVersion: 0010:D4.

		// catalogVersion: the catalog build this transformer shipped in. Unlike a
		// primitive's, it IS this key's own source component — an operator upgrading
		// a catalog is choosing new rendering logic and needs to know which bytes
		// are running.
		catalogVersion!: #VersionType // Example: "1.0.0"

		// WHY fqn: 0010:D21.

		// fqn: AUTHORED by the catalog at the definition site, not derived here.
		// #ImplFQNType, not #ContractFQNType: what a platform EXECUTES is keyed by
		// its build. #CatalogMemberFQNGate asserts the agreement with modulePath,
		// name and catalogVersion at publish.
		fqn!: #ImplFQNType // Example: "opmodel.dev/catalogs/opm/transformers/deployment-transformer@1.0.0"

		description!: string // A brief description of what this transformer produces

		// Labels for categorizing this transformer (not used for matching)
		labels?: #LabelsAnnotationsType

		// Annotations for additional transformer metadata
		annotations?: #LabelsAnnotationsType
	}

	// WHY the key is the DECLARING CATALOG's, not `core`'s: a catalog's
	// container resource declares the key in its own matchLabels (required,
	// so the author must pick), and its workload blueprints answer it.
	// Transformers requiring "stateful" won't match. `core` names no
	// matching key, which is what lets a catalog introduce one without a
	// `core` release. SPEC.md § 2.1 Rationale, "Why `core` names no matching
	// key".

	// WHY requiredLabels: 0010:D36.

	// Labels a component MUST carry in its matchLabels to match this transformer.
	// Selection reads #Component.matchLabels — the wholesale unification of the
	// attached primitives' matchLabels — and never metadata.labels on either
	// side. Example: A DeploymentTransformer requires stateless workloads:
	// requiredLabels: {"opm.opmodel.dev/workload-type": "stateless"}
	requiredLabels?: #LabelsAnnotationsType

	// Labels optionally used by this transformer - component MAY include these
	// in its matchLabels. If not provided, defaults from the definition can be used.
	optionalLabels?: #LabelsAnnotationsType

	// Resources required by this transformer - component MUST include these.
	// Map key is the FQN, value is the Resource definition (provides access to #defaults).
	requiredResources?: [#ContractFQNType]: #Resource

	// Resources optionally used by this transformer - component MAY include these.
	optionalResources?: [#ContractFQNType]: #Resource

	// Traits required by this transformer - component MUST include these.
	// Map key is the FQN, value is the Trait definition (provides access to #defaults).
	requiredTraits?: [#ContractFQNType]: #Trait

	// Traits optionally used by this transformer - component MAY include these.
	optionalTraits?: [#ContractFQNType]: #Trait

	// Catalog hints — purely informational; not used by the matcher.
	// `readsContext` declares which #ctx paths the transformer reads (e.g. "runtime.cluster.domain").
	// `producesKinds` declares which output kinds it emits (e.g. "Deployment", "Service").
	readsContext?: [...string]
	producesKinds?: [...string]

	// WHY struct or list:
	//   StructKind → one Compiled per (component, transformer) pair; the
	//                whole struct is the resource.
	//   ListKind   → one Compiled per list item; each item is one resource.
	// The renderer never inspects fields inside the value — apply-layer code
	// interprets the resource shape. Transformers that emit a fixed number
	// of resources should use a struct; transformers that emit N resources
	// derived from a component-side map (e.g. ConfigMaps, Secrets, PVCs)
	// should use a list comprehension.

	// WHY the projection lives here and not on #TransformerContext: the
	// computed blocks need #moduleInstance and #component, which are in scope
	// only at this site, and the definition stays standalone-constructible.
	// The `!= _|_` guards project an absent optional source as absent rather
	// than as an error or an empty struct (0019:D12; SPEC.md § 4.1 Rationale).

	// WHY #transform: 0019:D3; 0019:D12.

	// Transform function. The runtime supplies #moduleInstance and #component
	// concretely plus #context.#runtimeName; the context's two metadata blocks
	// compute themselves from those inputs. output is a single resource (struct)
	// or a list of resources; the renderer dispatches on cue.Kind and never
	// inspects fields inside the value. See SPEC.md § 4.1.
	#transform: {
		// WHY #moduleInstance: was #moduleRelease, renamed by 0002:D8.

		#moduleInstance: _ // Fully concrete #ModuleInstance (0019:D3)

		#component: _ // Unconstrained; validated by matching, not by the transform signature

		// Projected from the two inputs above; #runtimeName is the runtime's
		// whole remaining obligation. name reads #component.metadata.name —
		// the component's own identity, never the components-map key.
		#context: #TransformerContext & {
			#moduleInstanceMetadata: {
				name:      #moduleInstance.metadata.name
				namespace: #moduleInstance.metadata.namespace
				fqn:       #moduleInstance.metadata.fqn
				uuid:      #moduleInstance.metadata.uuid
				version:   #moduleInstance.#moduleMetadata.version
				if #moduleInstance.metadata.labels != _|_ {
					labels: #moduleInstance.metadata.labels
				}
				if #moduleInstance.metadata.annotations != _|_ {
					annotations: #moduleInstance.metadata.annotations
				}
			}
			#componentMetadata: {
				name: #component.metadata.name
				if #component.metadata.labels != _|_ {
					labels: #component.metadata.labels
				}
				if #component.metadata.annotations != _|_ {
					annotations: #component.metadata.annotations
				}
			}
		}

		output: {...} | [...{...}]
	}
}

// Map of transformers by fully qualified name
#TransformerMap: [#ImplFQNType]: #ComponentTransformer

// Provider context passed to transformers
#TransformerContext: {
	// WHY #moduleInstanceMetadata: was #moduleReleaseMetadata, renamed by
	// 0002:D8.

	#moduleInstanceMetadata: {
		name!:        #NameType
		namespace!:   #NameType // Required for instances (target environment)
		fqn:          string
		version:      string
		uuid:         #UUIDType
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	#componentMetadata: {
		name!:        #NameType
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// Identity of the runtime that is executing this transform. Mandatory — CUE
	// evaluation fails if the runtime forgets to fill this. The value is stamped
	// verbatim onto every rendered resource as "app.kubernetes.io/managed-by".
	// Runtimes are expected to fill this with their own identity (e.g. "opm-cli"
	// for the CLI, "opm-controller" for the operator).
	#runtimeName!: #NameType

	// WHY #Component.matchLabels is DELIBERATELY absent from every fold here: a
	// component's matching identity selects a transformer, it does not
	// describe the objects that transformer emits, and folding it in would
	// publish a catalog's private matching vocabulary onto every live object.
	// The omission is a decision (0010:D36), not an oversight —
	// it is also visible, because rendered objects carried
	// `core.opmodel.dev/workload-type` before this change and stop here. An
	// opt-in render flag was demonstrated working in experiment 04 and
	// deliberately not taken; adding it later is a struct-level guard on
	// componentLabels and disturbs nothing else. SPEC.md § 2.1 Rationale,
	// "Why `matchLabels` is not rendered".

	// Labels and annotations. These are inherited from the component and module metadata.
	// - moduleLabels: labels from #moduleInstanceMetadata.labels (if defined)
	// - moduleAnnotations: annotations from #moduleInstanceMetadata.annotations (if defined)
	// - componentLabels: labels from #componentMetadata.labels (if defined) + "app.kubernetes.io/name" = component name
	// - componentAnnotations: annotations from #componentMetadata.annotations (if defined)
	// - controllerLabels: standard controller labels (including managed-by = #runtimeName)
	moduleLabels: {
		if #moduleInstanceMetadata.labels != _|_ {
			for k, v in #moduleInstanceMetadata.labels {
				(k): "\(v)"
			}
		}
	}

	moduleAnnotations: {
		if #moduleInstanceMetadata.annotations != _|_ {
			for k, v in #moduleInstanceMetadata.annotations {
				(k): "\(v)"
			}
		}
	}

	componentLabels: {
		"app.kubernetes.io/name":           #componentMetadata.name
		"module-instance.opmodel.dev/name": #moduleInstanceMetadata.name
		if #componentMetadata.labels != _|_ {
			for k, v in #componentMetadata.labels {
				if !strings.HasPrefix(k, "transformer.opmodel.dev/") {
					(k): "\(v)"
				}
			}
		}
	}

	componentAnnotations: {
		if #componentMetadata.annotations != _|_ {
			for k, v in #componentMetadata.annotations {
				if !strings.HasPrefix(k, "transformer.opmodel.dev/") {
					(k): "\(v)"
				}
			}
		}
	}

	controllerLabels: {
		"app.kubernetes.io/managed-by": #runtimeName
		"app.kubernetes.io/name":       #componentMetadata.name
		"app.kubernetes.io/instance":   #componentMetadata.name
	}

	// Final labels and annotations applied to the output resource
	labels: {[string]: string}
	labels: {
		for k, v in moduleLabels {
			(k): "\(v)"
		}
		for k, v in componentLabels {
			(k): "\(v)"
		}
		for k, v in controllerLabels {
			(k): "\(v)"
		}
		...
	}
	annotations: {[string]: string}
	annotations: {
		for k, v in moduleAnnotations {
			(k): "\(v)"
		}
		for k, v in componentAnnotations {
			(k): "\(v)"
		}
		...
	}
}
