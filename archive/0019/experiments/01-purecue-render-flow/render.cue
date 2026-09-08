// THE GLUE. This file is the whole render pipeline, written in CUE.
//
// It is deliberately laid out in the same phases the Go kernel uses, so the
// two can be read side by side:
//
//     library/opm/compile/match.go        ->  `matched` below (predicate rung
//                                             only; see Phase 1)
//     library/opm/compile/execute.go      ->  `rendered` below
//     library/opm/schema/context.go       ->  `_contextFor` below
//     library/opm/compile/finalize.go     ->  (nothing. there is no analogue.)
//
// The last line is the point of the experiment. The kernel's finalize step has
// no counterpart here because unification never needs one: a value is handed
// to a transformer as it is, and nothing about carrying definitions, closedness
// or validators makes that fail.
package render

import (
	catalog "opmodel.dev/catalogs/opm"
	platform "experiments.opmodel.dev/0019/purecue-render-flow/opm_platform"
)

// ---------------------------------------------------------------------------
// Inputs
// ---------------------------------------------------------------------------

// Every transformer the catalog publishes, keyed by its own FQN. This is the
// same map the kernel's Materialize step builds, except that here it arrives
// by import instead of by an OCI pull plus a Go-side index.
_transformers: catalog.#transformers

// The instance's components, verbatim. Note what is NOT happening: no
// finalization, no export-and-rebuild, no second value. `components` carries
// its definition fields (#names, #resources, #traits, #instance) into
// everything downstream, because that is what it means to pass a value along.
components: instance.components

// ---------------------------------------------------------------------------
// Phase 1: Match
// ---------------------------------------------------------------------------
//
// SCOPE. This is the PREDICATE rung, not the kernel's matcher. It is enough to
// produce the right pairs for this fixture, and it is deliberately not a
// specification of matching, which 02-design.md holds out of scope. Read
// "What this does not model" below before reading it as one.
//
// A transformer matches a component when all three predicates hold
// (core/src/transformer.cue):
//
//   1. every requiredLabels key is present in the component's matchLabels
//      with the same value
//   2. every requiredResources FQN exists in the component's #resources
//   3. every requiredTraits FQN exists in the component's #traits
//
// Predicates 2 and 3 read DEFINITION fields off the component. That is why
// the kernel matches against its unfinalized value and renders from the
// finalized one: matching structurally cannot use the value it renders with.
// Here there is only one value, so the question does not arise. The kernel
// agrees on this point and it is the one this experiment rests on:
// opm/kernel/compile.go hands schemaComponents to Match and the FinalizeValue
// output only to Execute.
//
// ---------------------------------------------------------------------------
// What this does not model
// ---------------------------------------------------------------------------
//
// library/opm/compile/match.go states its algorithm as
// FQN-lookup -> always-unify -> predicate. Only the third rung is below.
//
// RUNG 1, FQN LOOKUP. The kernel only ever considers transformers sitting in a
// #matchers.{resources,traits}[fqn] bucket for an FQN the component demands;
// the buckets are built from required UNION optional (opm/materialize/index.go
// indexCatalogs). This file loops every transformer in the catalog instead.
// The two universes coincide except for one class: a transformer with no
// requiredResources, no requiredTraits, and no optional FQN the component
// demands. The kernel can never reach it; this file pairs it with every
// component satisfying requiredLabels. Zero of the 50 transformers in
// catalogs/opm@2.0.0-alpha.3 fall in that class, so the divergence is latent
// rather than observable here.
//
// RUNG 2, ALWAYS-UNIFY (0010 D6/D1). Absent entirely. The kernel unifies the
// component's primitive BODY against the candidate's required body for every
// FQN present in BOTH sides, validates with cue.Concrete(false), drops
// diagnostics located at the D30 provenance denylist (metadata.catalogVersion,
// metadata.description in any metadata block), and DISQUALIFIES the candidate
// on any surviving conflict. The predicates below check key presence only, so
// a component whose body conflicts with a transformer's embedded required copy
// pairs here and is refused by the kernel. Note for the parity harness (slice
// 1): the D30 carve-out is a place where the kernel is deliberately NOT plain
// unification, so it needs a stated exemption rather than an equality
// assertion.
//
// DEMAND RESOLUTION (0010 D28). No analogue. The kernel records MissingFQN,
// UnresolvedDemand and UnhandledTraits, and compile/module.go hard-fails on a
// non-empty Unresolved or Unmatched set: a declared resource whose bucket is
// empty or all-disqualified, and an unhandled trait whose `optional` posture
// is false or unstated (fail-closed). All seven of web's traits are
// optional: true, so on this fixture the kernel only warns; make one unstated
// and the kernel refuses to render while this file still renders.
//
// MULTI-BUILD COMPOSITION. See the OQ3 note at the foot of this file. The
// kernel's indexCatalogs collapses same-FQN transformers across subscribed
// builds by unification and runs the D32/D37 single-provider guard. A single
// import has neither.
//
// ONE DIVERGENCE RUNS THE OTHER WAY, and is worth keeping in view because the
// kernel is the weaker side of it. #LabelsAnnotationsType admits
// `string | int | bool | [string|int|bool]` (core/src/types.cue), but the
// kernel's labelPairs and missingMapLabels both go through cue.Value.String()
// and SKIP on error. A required label with a non-string value, or a component
// label that is non-concrete, is therefore dropped silently and the label
// predicate passes regardless of what the component carries. The `&` below
// unifies instead, so it covers every admitted type and refuses on mismatch.
// The two agree only on concrete strings, which is all the catalog ships
// today. Flagged rather than worked around: this looks like the kernel
// narrowing a type core widens, not an intended rule.

matched: {
	for cid, comp in components {
		(cid): {
			for tfqn, tf in _transformers {
				(tfqn): {
					// Absent maps are legal on a transformer, so each predicate
					// collapses to an empty set rather than an error.
					_missingLabels: [
						if tf.requiredLabels != _|_ for k, v in tf.requiredLabels
						if (comp.matchLabels[k] & v) == _|_ {k},
					]
					_missingResources: [
						if tf.requiredResources != _|_ for fqn, _ in tf.requiredResources
						if comp.#resources[fqn] == _|_ {fqn},
					]
					_missingTraits: [
						if tf.requiredTraits != _|_ for fqn, _ in tf.requiredTraits
						if comp.#traits[fqn] == _|_ {fqn},
					]

					ok: len(_missingLabels) == 0 &&
						len(_missingResources) == 0 &&
						len(_missingTraits) == 0
				}
			}
		}
	}
}

// The matched pairs, flattened. Equivalent to MatchPlan.MatchedPairs(), and to
// the kernel's whole Matches map: pairTransformer re-checks requiredLabels
// after candidateSatisfied has already gated on them, and it has no other
// caller, so MatchResult.Matched is always true and NonMatchedPairs() is
// always empty. "Satisfied therefore paired" below is what the kernel does,
// not a simplification of it.
pairs: [
	for cid, byTf in matched
	for tfqn, m in byTf
	if m.ok {{component: cid, transformer: tfqn}},
]

// ---------------------------------------------------------------------------
// Phase 2: #context
// ---------------------------------------------------------------------------
//
// A pure projection over the two other inputs. Compare
// library/opm/schema/context.go, which decodes the same fields into Go structs
// and re-encodes them: a hand-maintained mirror of a shape core already owns.
//
// Only #runtimeName comes from outside. It is the identity of whatever is
// executing the render, and nothing in the instance can supply it. Everything
// else here is derivation, which is what OQ5 proposes moving into core.

_contextFor: {
	comp!: _
	out: {
		#moduleInstanceMetadata: {
			name:      instance.metadata.name
			namespace: instance.metadata.namespace
			fqn:       instance.metadata.fqn
			uuid:      instance.metadata.uuid
			version:   instance.#moduleMetadata.version
			if instance.metadata.labels != _|_ {labels: instance.metadata.labels}
			if instance.metadata.annotations != _|_ {annotations: instance.metadata.annotations}
		}
		#componentMetadata: {
			name: comp.metadata.name
			if comp.metadata.labels != _|_ {labels: comp.metadata.labels}
			if comp.metadata.annotations != _|_ {annotations: comp.metadata.annotations}
		}
		#runtimeName: "pure-cue"
	}
}

// ---------------------------------------------------------------------------
// Phase 3: Execute
// ---------------------------------------------------------------------------
//
// One unification per matched pair. This is the entire executePair equivalent.
//
// All THREE inputs core declares on #transform are supplied, including
// #moduleInstance, which the kernel has never filled. Filling it works even
// though no shipped transformer declares it in its own body: core declares it
// on #ComponentTransformer, so the field exists in the unified value. What a
// transformer cannot do without re-declaring it is REFERENCE it, because CUE resolves
// references lexically, against the source they are written in, which is why
// every shipped transformer writes `#component: _` despite core declaring that
// too.

rendered: {
	for p in pairs {
		"\(p.component) :: \(p.transformer)": (_transformers[p.transformer].#transform & {
			#moduleInstance: instance
			#component:      components[p.component]
			#context:        (_contextFor & {comp: components[p.component]}).out
		}).output
	}
}

// ---------------------------------------------------------------------------
// What the kernel cannot see today
// ---------------------------------------------------------------------------
//
// Every field below is stripped from #component before a transformer receives
// it, because compile.FinalizeValue exports through cue.Final() and that call
// sets omitDefinitions. None of these are reachable inside a real #transform
// as the kernel stands; all of them are reachable here.

visibleToTransformers: {
	for cid, comp in components {
		(cid): {
			resourceName: comp.#names.resourceName
			fqdn:         comp.#names.dns.fqdn
			local:        comp.#names.dns.local
			resources: [for fqn, _ in comp.#resources {fqn}]
			traits: [if comp.#traits != _|_ for fqn, _ in comp.#traits {fqn}]
			instanceNamespace: comp.#instance.namespace
			instanceName:      comp.#instance.name
		}
	}
}

// ---------------------------------------------------------------------------
// OQ3, made executable
// ---------------------------------------------------------------------------
//
// In a single build the catalog version is decided by cue.mod and CUE's
// Minimal Version Selection. The platform's subscription is inert here: it is
// authored data that nothing in this file resolves, because the import already
// resolved it.
//
// That is precisely the tension OQ3 names. 0010 D14 states "the platform file
// IS the resolution", and under single-build evaluation it is not: cue.mod
// is. The unification below asserts the two agree, and it is the check that
// would have to become load-bearing (or the decision that would have to
// change) before the render pipeline could collapse into one build.

catalogVersionFromCueMod:       catalog.metadata.version
catalogVersionFromSubscription: platform.#registry["opmodel.dev/catalogs/opm@v2"].version

// Fails the build if cue.mod and the platform disagree.
_versionsAgree: catalogVersionFromCueMod & catalogVersionFromSubscription
