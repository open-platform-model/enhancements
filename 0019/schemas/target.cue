// Core-schema delta for enhancement 0019 — Kernel render path parity with
// pure CUE.
//
// Most of this entry changes kernel BEHAVIOUR rather than core shapes, and
// that material lives in ../contracts/contracts.cue. The decisions that land
// in opmodel.dev/core (D5, D12, D16, D17, D20, D21, D23) are here, and only
// those.
//
// Delta manifest (classified against core/src on the v2 line):
//
//   #Subscription        — REMOVED (D5). The `{enable, version!}` pair is
//                          replaced by #CatalogEntry. Removal rather than
//                          extension is forced: #Subscription is closed
//                          around those two fields, so the proposal is
//                          inexpressible as a unification onto it
//                          (measured by experiments/02-platform-authority-mvs).
//   #CatalogEntry        — NEW (D5). A registry entry carries the catalog
//                          itself by import and derives `version` and
//                          `#transformers` from it.
//   #Platform            — CHANGED (D5). `#registry`'s pattern constraint
//                          binds the map key into the embedded catalog's
//                          modulePath; `#composedTransformers` stops being a
//                          kernel-filled optional slot and becomes a fold
//                          over enabled entries; `#matchers` is REMOVED
//                          outright (D17).
//   #TransformerContext  — CHANGED (D12). Its two metadata blocks become
//                          projections of #transform's other two inputs.
//                          Field names and values are unchanged, which is
//                          what makes the migration stageable.
//   #ComponentTransformer.#transform
//                        — CHANGED (D12). `#context` stops being a bare slot
//                          the runtime fills and becomes the projection site;
//                          the runtime's remaining obligation is #runtimeName.
//   #ObjectNameType      — NEW (D20). RFC 1123 DNS subdomain, ≤253 runes:
//                          the ceiling of metadata.resourceName.
//   #ServiceNameType     — NEW (D20). RFC 1035 label (alphabetic lead), ≤63:
//                          the type Expose declares as its #nameConstraint.
//   #Resource / #Trait / #Blueprint
//                        — CHANGED (D21). Each gains a hidden slot
//                          `#nameConstraint: _` (top by default), a type the
//                          owning component's resourceName must additionally
//                          satisfy; a primitive MAY compute it from its own
//                          fields (D23). Only the naming surface is restated.
//   #Component           — CHANGED (D16, LANDED in core PR 51 with an
//                          unvalidated default arm, a guarded length
//                          assertion and an error() arm; D20 widens the
//                          ceiling to #ObjectNameType; D21 collects every
//                          attached primitive's #nameConstraint into a hidden
//                          conjunction and asserts the resolved name against
//                          it on a hidden field). #names.dns.* inherits the
//                          D16 change by construction.
//
// Restatement, not import: CUE cannot "edit" an imported closed definition,
// so a changed definition is restated here in full and the restatement IS the
// proposal (the convention 0017's delta follows). Definitions marked MIRROR
// are unchanged core surface, carried only so the changed ones compile and so
// examples.cue can exercise them; where a mirror is simplified, its comment
// says so. core is the source of truth once the slices land.
//
// Slices: core-registry-import (D5), core-context-projection (D12),
// core-resourcename-default (D16). Each carries a SPEC.md co-update under the
// core-schema-edit protocol; spec.md in this directory pre-drafts it.
package schema

import "strings"

/////////////////////////////////////////////////////////////////
// MIRROR — unchanged core types the delta references
/////////////////////////////////////////////////////////////////

// core/src/types.cue, verbatim. Carried with its real constraints rather
// than as a plain string, because D16's default is unified with it and the
// 63-rune bound is the whole reason that unification is load-bearing.
#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

// NEW (D20). RFC 1123 DNS subdomain: dot-separated label segments, 253 runes.
// What the API server admits for most metadata.name (Deployment, DaemonSet,
// ConfigMap, Secret, StorageClass, CSIDriver, CRD, APIService — measured by
// server-side dry-run, experiment 09). The ceiling of an explicit
// resourceName; never the type of anything that composes into DNS.
#ObjectNameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" & strings.MinRunes(1) & strings.MaxRunes(253)

// NEW (D20). RFC 1035 label: like #NameType but the first rune is alphabetic.
// Service metadata.name refuses a leading digit at apply, which #NameType
// admits; this type closes that gap at vet.
#ServiceNameType: string & =~"^[a-z]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

#ModulePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$" & strings.MinRunes(1) & strings.MaxRunes(254)

#VersionType: string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#ImplFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

#ContractFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+((alpha|beta)[0-9]+)?$"

#LabelsAnnotationsType: [string]: string

// MIRROR, simplified: core/src/module_context.cue. Only the fields D16's
// default and #names read.
#InstanceIdentity: {
	name!:         #NameType
	namespace!:    #NameType
	clusterDomain: string | *"cluster.local"
	...
}

// MIRROR, simplified: core/src/transformer.cue's map. The value type is left
// open here so examples can carry small stand-in transformers rather than
// full ones.
#TransformerMap: [#ImplFQNType]: _

// MIRROR, simplified: core/src/catalog.cue. Only the two identity fields and
// the transformer map, which are what a registry entry derives from. Open
// (`...`) so a real catalog value unifies with the mirror instead of being
// refused by definition closedness.
#Catalog: {
	kind: "Catalog"
	metadata: {
		modulePath!: #ModulePathType
		version!:    #VersionType
		...
	}
	#transformers: #TransformerMap
	...
}

/////////////////////////////////////////////////////////////////
// D5 — the registry entry carries the catalog, and derives the rest
/////////////////////////////////////////////////////////////////

// NEW. Replaces #Subscription.
//
// The shape difference is one question with one answer instead of two. A
// subscription named a build by version string, which nothing resolves; an
// entry carries the build itself, resolved by the same mechanism that
// resolves every other CUE dependency, named in the platform module's own
// cue.mod. That is what lets a single render build have an answer at all
// (D9), and it keeps 0010 D14's property intact: catalog selection stays a
// pure function of committed source, because cue.mod is committed source.
#CatalogEntry: {
	// Unchanged from #Subscription.
	enable: bool | *true

	// The imported catalog, embedded WHOLE. Free to carry: experiment 07
	// measured unevaluated definition payloads as costing nothing, and a
	// subset would be a second selection mechanism competing with
	// enhancement 0015's provider classes.
	#catalog: #Catalog

	// DERIVED, never authored: a readout of the release-stamped identity.
	// #Catalog.metadata.version! is required and has no dev default, so an
	// unstamped catalog refuses as incomplete rather than rendering wrong.
	//
	// The operator MAY stamp the expected version at platform-generation
	// time; the stamp unifies with this readout, so wrong bytes become a
	// build conflict naming this entry rather than a second answer (D13's
	// tripwire, defense in depth for the promotion rule).
	version: #catalog.metadata.version

	// DERIVED. Per-transformer selection is deliberately inexpressible here:
	// that concern belongs to enhancement 0015 (provider classes,
	// TransformerRegistration).
	#transformers: #TransformerMap & #catalog.#transformers
}

// CHANGED. Restated in full; the three changed regions carry CHANGED
// comments, everything else is core's current shape.
#Platform: {
	kind: "Platform"

	metadata: {
		name!:        #NameType
		description?: string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	type!: string

	// CHANGED (D5): the value type becomes #CatalogEntry, and the pattern
	// constraint binds the map key INTO the embedded catalog's modulePath.
	// The binding is what makes key-versus-import drift impossible rather
	// than merely detectable: an entry keyed at one path carrying a catalog
	// published at another is a conflict at build time, reported at a path
	// that names the offending entry.
	//
	// One entry per catalog path still holds, by CUE map semantics (0010
	// D13); two builds of one catalog remain two platforms.
	#registry: [Path=#ModulePathType]: #CatalogEntry & {#catalog: metadata: modulePath: Path}

	// CHANGED (D5): derived, and no longer optional. With the transformer
	// maps present in the registry this is a fold over enabled entries, which
	// is library/opm/materialize/index.go rewritten as four lines of CUE.
	//
	// The fold COPIES entry by entry (comprehension) rather than unifying the
	// entry maps together: the catalog's D25 provenance stamp refuses a
	// foreign transformer unified into its member map, measured by
	// experiments/05-match-in-one-build.
	#composedTransformers: {
		for _, entry in #registry if entry.enable {
			for fqn, tf in entry.#transformers {(fqn): tf}
		}
	}

	// REMOVED (D17). The slot existed because a Go step filled it, and both
	// halves of that sentence are deleted: Materialize by D5, and the Go
	// matcher that read it by D10.
	//
	// Nothing replaces it in core. Inside the render build the reverse index
	// is built by the matching glue from #composedTransformers, keyed contract
	// FQN to a SET of transformer FQNs — a different shape from the list-valued
	// buckets core carried, and the one experiment 05's #Match actually
	// consumes. A caller wanting the index outside a render folds it in four
	// lines over the field above.
	//
	// #matchers: REMOVED
}

/////////////////////////////////////////////////////////////////
// D12 — #TransformerContext becomes a projection of the other two inputs
/////////////////////////////////////////////////////////////////

// CHANGED. Field names and values are identical to core's current shape,
// which is what makes the migration stageable: for one release the kernel
// keeps filling values identical to what the projection computes and
// unification simply agrees, and the Go fills are removed only after the
// parity harness reports agreement.
//
// What changes is WHERE the two metadata blocks come from. Today
// library/opm/schema/context.go decodes them out of the instance and the
// component and re-encodes them into a fresh value, a hand-maintained mirror
// that can drift; under D12 core computes them at the #transform site, where
// both inputs are already in scope. Experiment 01's _contextFor derives every
// field in 18 lines of CUE against the real published catalog.
//
// MIRROR-simplified: the label and annotation folds below are shortened to
// the two that examples.cue asserts on. They are UNCHANGED by this entry, and
// they were already projections — of these two metadata blocks. That is the
// argument for D12 in one line: the context was half a projection already,
// and the half that was not is the half that needed a Go mirror.
#TransformerContext: {
	#moduleInstanceMetadata: {
		name!:        #NameType
		namespace!:   #NameType
		fqn:          string
		version:      string
		uuid:         string
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	#componentMetadata: {
		name!:        #NameType
		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// UNCHANGED and deliberately so: nothing in the two inputs can know what
	// is executing them, so this stays the runtime's obligation and it is the
	// whole of what remains of it (D12).
	#runtimeName!: #NameType

	componentLabels: {
		"app.kubernetes.io/name":           #componentMetadata.name
		"module-instance.opmodel.dev/name": #moduleInstanceMetadata.name
	}

	controllerLabels: {
		"app.kubernetes.io/managed-by": #runtimeName
		"app.kubernetes.io/name":       #componentMetadata.name
		"app.kubernetes.io/instance":   #componentMetadata.name
	}

	// Elided: moduleLabels, moduleAnnotations, componentAnnotations, and the
	// final labels/annotations folds. Unchanged by this entry.
	...
}

// CHANGED. Only #transform is restated; the metadata, matching maps and
// hints on #ComponentTransformer are unchanged and elided.
#ComponentTransformer: {
	// Elided: metadata, requiredLabels/optionalLabels,
	// required/optionalResources, required/optionalTraits, hints.
	requiredResources?: [#ContractFQNType]: _
	optionalResources?: [#ContractFQNType]: _
	requiredTraits?: [#ContractFQNType]:    _
	optionalTraits?: [#ContractFQNType]:    _

	#transform: {
		// UNCHANGED in shape, and the contract the comment already states
		// ("the runtime supplies all three inputs concretely") is what this
		// entry finally makes true: today the kernel fills a stripped
		// #component and does not fill #moduleInstance at all (D3).
		#moduleInstance: _
		#component:      _

		// CHANGED (D12): #context is no longer a bare slot. Its two metadata
		// blocks are projected from the inputs above, so the only thing left
		// for the runtime to fill is #runtimeName.
		//
		// Guarded with `!= _|_` on the optional sources so an instance or
		// component without labels projects an absent field rather than an
		// error, matching what context.go does today.
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

/////////////////////////////////////////////////////////////////
// D16 — the resourceName cascade defaults to the instance-qualified name
/////////////////////////////////////////////////////////////////

// CHANGED. Restated down to the fields the change touches; #resources,
// #traits, #blueprints, matchLabels, _allFields and the exposed-field
// machinery are unchanged and elided.
//
// The default moves from the bare component name to <instance>-<component>,
// which is what every hand-rolled catalog formula already renders (the
// divergence open-platform-model/core#49 reports). Flipping it first is what
// makes D15's sweep a byte-identical refactor instead of a double rename.
// CHANGED (D21). Naming surface only; every other field of the three
// primitives is elided. The slot is a hidden DEFINITION field defaulting to
// top, deliberately not optional and never guarded: measured on cue v0.17.1
// (experiment 09), `x.#nameConstraint != _|_` is false for a non-concrete
// value, so an optional-slot-plus-guard spelling silently never propagates.
// Unifying top is the identity, so an indifferent primitive costs nothing.
// A primitive MAY compute the slot from its own fields (D23): the container
// resource declares #NameType when its own workload-type key reads
// "stateful", top otherwise, in list-index form so a default arm cannot win
// over the concrete one.
#Resource: {
	kind: "Resource"
	metadata: name!: #NameType
	matchLabels?:    #LabelsAnnotationsType
	#nameConstraint: _
	...
}
#Trait: {
	kind: "Trait"
	metadata: name!: #NameType
	#nameConstraint: _
	...
}
#Blueprint: {
	kind: "Blueprint"
	metadata: name!: #NameType
	#nameConstraint: _
	...
}

#Component: {
	kind: "Component"

	metadata: {
		name!: #NameType

		// CHANGED (D16, as LANDED; D20). Previously `*name | #NameType`.
		//
		// The default arm is deliberately NOT unified with a type: on cue
		// v0.17.1 a validated default that fails degrades to a bare
		// `incomplete value` naming the constraints and never the string,
		// and it leaves the field non-concrete so no guard can compare
		// against it (core PR 51; SPEC.md §3.1). _resourceNameDefaultFits
		// below carries the length check instead. The error() arm is
		// reported only when every other arm fails, replacing the nested
		// empty-disjunction output an invalid explicit name would produce.
		//
		// D20 widens the override ceiling from #NameType to #ObjectNameType:
		// an explicit name may carry dots and run to 253 runes, because the
		// kinds most components render admit that. The default is
		// structurally dotless (both halves are #NameType labels), so only an
		// explicit override can ever meet a dot-hostile constraint.
		resourceName: *"\(#instance.name)-\(name)" | #ObjectNameType | error("resourceName \"\(resourceName)\" is not a DNS subdomain (lowercase alphanumerics, hyphens and dots, 1-253 runes)")

		labels?:      #LabelsAnnotationsType
		annotations?: #LabelsAnnotationsType
	}

	// Attachment maps, restated only as far as D21 reads them. Elided:
	// matchLabels and its derivation check, _allFields, the exposed-field
	// machinery.
	#resources: [string]:   #Resource
	#traits?: [string]:     #Trait
	#blueprints?: [string]: #Blueprint

	// NEW (D21). The conjunction of every attached primitive's constraint,
	// top when none. Collected UNCONDITIONALLY: comprehensions over the three
	// maps, no existence guard (see the slot's comment).
	_nameConstraints: _
	for _, r in #resources {_nameConstraints: r.#nameConstraint}
	if #traits != _|_ {
		for _, t in #traits {_nameConstraints: t.#nameConstraint}
	}
	if #blueprints != _|_ {
		for _, b in #blueprints {_nameConstraints: b.#nameConstraint}
	}

	#instance: #InstanceIdentity

	// D16's _resourceNameDefault / _resourceNameDefaultFits guard is RETIRED
	// by D20: both operands are #NameType (≤63), so the default is at most
	// 127 runes and can never reach the 253-rune ceiling. A 64-to-127-rune
	// default is a valid object name for every subdomain kind, and the
	// dot-restricted kinds refuse it through their primitive's constraint
	// (below), which names the string and the 63-rune bound.

	// NEW (D21). The assertion. The conjunction is applied to the RESOLVED
	// name, never unified into metadata.resourceName: unified into the field
	// it distributes into the default arm, a failing default drops out of the
	// disjunction, and the refusal degrades to `non-concrete value … in
	// operand to ==` at the guard above with the string nowhere (experiment
	// 11). The interpolation is load-bearing: it forces the default arm to a
	// string, and `string & C` is either that string or an error naming it,
	// the violated bound and the constraint type's definition site. A plain
	// `metadata.resourceName & _nameConstraints` SILENTLY ADMITS every
	// default-arm failure, and an error()-guarded form fires on this bare
	// definition (`(incomplete & C) == _|_` is true), so neither the
	// primitive nor a remedy can be named here; the type site in the
	// diagnostic is the pointer.
	_nameFits: "\(metadata.resourceName)" & _nameConstraints

	// UNCHANGED in shape; changed in value by construction. The DNS variants
	// read resourceName, so service DNS becomes
	// <instance>-<component>.<namespace>.svc.<clusterDomain> with no second
	// edit. This is D16's ripple, and it is the reason the deleted
	// #ResourceNameTrait (D15) has no replacement to write: the trait never
	// carried the DNS variants.
	#names: {
		resourceName: metadata.resourceName
		dns: {
			short: resourceName
			local: "\(resourceName).\(#instance.namespace)"
			fqdn:  "\(resourceName).\(#instance.namespace).svc.\(#instance.clusterDomain)"
		}
	}
}
