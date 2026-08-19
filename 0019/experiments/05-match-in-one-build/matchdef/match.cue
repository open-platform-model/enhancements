// THE GLUE UNDER TEST. library/opm/compile/match.go's three rungs plus 0010
// D28's demand resolution, expressed as ONE CUE definition whose every verdict
// is DATA rather than bottom.
//
// Laid out rung by rung against match.go so the two can be read side by side:
//
//	match.go / index.go                     here
//	-------------------------------------   ------------------------------
//	indexCatalogs (required ∪ optional)     _bucketsResources/_bucketsTraits
//	walk: bucket lookup, MissingFQN         _candidates, missing*
//	runUnify / unifyIntersection (D6/D1)    _unify        <- PLAIN &, no D30
//	candidateSatisfied (predicate)          _pred
//	D28 demand resolution + traitOptional   _resOutcome/_traitOutcome/posture
//	compile/module.go hard gate             resolved
//
// The one deliberate divergence is the point of claim 2: _unify carries NO
// provenance carve-out. match.go:excludeProvenance drops diagnostics located
// at metadata.catalogVersion / metadata.description because two BUILDS of one
// catalog diverge there by construction; in one build both sides of the
// unification resolve to the same catalog bytes, so if the healthy fixture
// pairs cleanly through plain `&`, the carve-out is a federation artifact.
//
// Failure reporting contract (the hypothesis): verdicts, conflicts, missing
// FQNs and unresolved demands are values a caller reads, so one failing
// demand cannot poison the sibling verdicts. The single place that contract
// is NOT expressible is an unhandled trait with an UNSTATED optional posture:
// classifying it requires evaluating a plain `bool`, which is incomplete, so
// the refusal arrives as an incomplete-value error at vet rather than as a
// row in `unresolved`. That boundary is measured by broken/unstated.
package matchdef

#Match: {
	// ── Inputs ──────────────────────────────────────────────────────
	// The platform's composed transformer map (D5: arrives by import) and
	// the instance's components. Both deliberately unconstrained: the glue
	// reads the same paths the kernel reads and nothing else.
	#transformers: [string]: _
	#components: [string]:   _

	// ── Rung 1 index (opm/materialize/index.go) ─────────────────────
	// Reverse index: primitive FQN -> the transformers whose required ∪
	// optional maps name it. A transformer is only ever CONSIDERED through
	// a bucket some demanded FQN reaches — the divergence experiment 01
	// left latent is closed here.
	_bucketsResources: {
		for tfqn, tf in #transformers {
			if tf.requiredResources != _|_ {
				for fqn, _ in tf.requiredResources {(fqn): (tfqn): true}
			}
			if tf.optionalResources != _|_ {
				for fqn, _ in tf.optionalResources {(fqn): (tfqn): true}
			}
		}
	}
	_bucketsTraits: {
		for tfqn, tf in #transformers {
			if tf.requiredTraits != _|_ {
				for fqn, _ in tf.requiredTraits {(fqn): (tfqn): true}
			}
			if tf.optionalTraits != _|_ {
				for fqn, _ in tf.optionalTraits {(fqn): (tfqn): true}
			}
		}
	}

	// ── Per-component verdicts ──────────────────────────────────────
	verdicts: {
		for cid, comp in #components {
			(cid): {
				_resFqns: [for fqn, _ in comp.#resources {fqn}]
				_traitFqns: [if comp.#traits != _|_ for fqn, _ in comp.#traits {fqn}]

				// Rung 2, always-unify — plain `&`, verdict as data.
				// match.go validates with cue.Concrete(false); the CUE
				// equivalent of "structurally agrees" is "the unification
				// is not bottom", which `== _|_` answers without letting
				// the bottom escape (probed: nested conflicts detected,
				// no false positives, incomplete is NOT bottom).
				_unify: {
					for tfqn, tf in #transformers {
						(tfqn): {
							conflicts: [
								if tf.requiredResources != _|_
								for fqn, req in tf.requiredResources
								if comp.#resources[fqn] != _|_
								if (comp.#resources[fqn] & req) == _|_ {fqn},
								if tf.requiredTraits != _|_
								for fqn, req in tf.requiredTraits
								if comp.#traits[fqn] != _|_
								if (comp.#traits[fqn] & req) == _|_ {fqn},
							]
							ok: len(conflicts) == 0
						}
					}
				}

				// Rung 3, predicate (candidateSatisfied). One divergence
				// runs the kernel's way and is kept deliberately: the `&`
				// on label values covers every type #LabelsAnnotationsType
				// admits, where the kernel's cue.Value.String() silently
				// skips non-strings (flagged by experiment 01).
				_pred: {
					for tfqn, tf in #transformers {
						(tfqn): {
							missingLabels: [
								if tf.requiredLabels != _|_
								for k, v in tf.requiredLabels
								if (comp.matchLabels[k] & v) == _|_ {k},
							]
							missingResources: [
								if tf.requiredResources != _|_
								for fqn, _ in tf.requiredResources
								if comp.#resources[fqn] == _|_ {fqn},
							]
							missingTraits: [
								if tf.requiredTraits != _|_
								for fqn, _ in tf.requiredTraits
								if comp.#traits[fqn] == _|_ {fqn},
							]
							ok: len(missingLabels) == 0 &&
								len(missingResources) == 0 &&
								len(missingTraits) == 0
						}
					}
				}

				// Rung 1 walk: only transformers reachable through a
				// demanded FQN's bucket are candidates.
				_candidates: {
					for _, fqn in _resFqns if _bucketsResources[fqn] != _|_ {
						for tfqn, _ in _bucketsResources[fqn] {(tfqn): true}
					}
					for _, fqn in _traitFqns if _bucketsTraits[fqn] != _|_ {
						for tfqn, _ in _bucketsTraits[fqn] {(tfqn): true}
					}
				}

				matched: {
					for tfqn, _ in _candidates
					if _unify[tfqn].ok
					if _pred[tfqn].ok {(tfqn): true}
				}

				// Hard misses (oerrors.MissingFQN): demanded FQN, no bucket.
				missingResources: [for _, fqn in _resFqns if _bucketsResources[fqn] == _|_ {fqn}]
				missingTraits: [for _, fqn in _traitFqns if _bucketsTraits[fqn] == _|_ {fqn}]

				// D28 per-demand resolution. A demand is satisfied iff some
				// candidate in ITS bucket survived both rungs; an empty
				// bucket and an all-disqualified bucket are the same verdict
				// with different `disqualified` contents, exactly as walk()
				// reports them.
				_resOutcome: {
					for _, fqn in _resFqns {
						(fqn): {
							satisfied: len([
								if _bucketsResources[fqn] != _|_
								for tfqn, _ in _bucketsResources[fqn]
								if _unify[tfqn].ok
								if _pred[tfqn].ok {tfqn},
							]) > 0
							disqualified: [
								if _bucketsResources[fqn] != _|_
								for tfqn, _ in _bucketsResources[fqn]
								if !_unify[tfqn].ok {tfqn},
							]
						}
					}
				}
				unresolvedResources: [
					for _, _f in _resFqns if !_resOutcome[_f].satisfied {
						{kind: "resource", fqn: _f, disqualified: _resOutcome[_f].disqualified}
					},
				]

				_traitOutcome: {
					for _, fqn in _traitFqns {
						(fqn): {
							satisfied: len([
								if _bucketsTraits[fqn] != _|_
								for tfqn, _ in _bucketsTraits[fqn]
								if _unify[tfqn].ok
								if _pred[tfqn].ok {tfqn},
							]) > 0
							disqualified: [
								if _bucketsTraits[fqn] != _|_
								for tfqn, _ in _bucketsTraits[fqn]
								if !_unify[tfqn].ok {tfqn},
							]
						}
					}
				}
				// A trait is handled if its own bucket satisfied, or any
				// MATCHED transformer lists it in optionalTraits (match.go's
				// carry-forward loop).
				_optionalCovered: {
					for tfqn, _ in matched
					if #transformers[tfqn].optionalTraits != _|_ {
						for fqn, _ in #transformers[tfqn].optionalTraits {(fqn): true}
					}
				}
				_handled: {
					for _, fqn in _traitFqns {
						(fqn): _traitOutcome[fqn].satisfied || _optionalCovered[fqn] != _|_
					}
				}
				// Posture split (traitOptional + D28/D46). Guards resolve
				// DEFAULTS (probed), so a catalog-stated `bool | *true`
				// lands in warnings and `bool | *false` in unresolved. An
				// UNSTATED plain `bool` makes both guards incomplete: the
				// fail-closed refusal survives, but as an incomplete-value
				// error at the trait's own `optional` field, not as data.
				unhandledWarnings: [
					for _, fqn in _traitFqns
					if !_handled[fqn]
					if comp.#traits[fqn].optional {fqn},
				]
				unresolvedTraits: [
					for _, _f in _traitFqns
					if !_handled[_f]
					if !comp.#traits[_f].optional {
						{kind: "trait", fqn: _f, disqualified: _traitOutcome[_f].disqualified}
					},
				]
			}
		}
	}

	// ── Flattened outputs ───────────────────────────────────────────
	pairs: [
		for cid, v in verdicts
		for tfqn, _ in v.matched {{component: cid, transformer: tfqn}},
	]
	unmatchedComponents: [for cid, v in verdicts if len(v.matched) == 0 {cid}]
	missing: [
		for cid, v in verdicts
		for _, _f in v.missingResources {{component: cid, kind: "resource", fqn: _f}},
		for cid, v in verdicts
		for _, _f in v.missingTraits {{component: cid, kind: "trait", fqn: _f}},
	]
	unresolved: [
		for cid, v in verdicts
		for _, u in v.unresolvedResources {{u, component: cid}},
		for cid, v in verdicts
		for _, u in v.unresolvedTraits {{u, component: cid}},
	]
	warnings: [
		for cid, v in verdicts
		for _, _f in v.unhandledWarnings {{component: cid, fqn: _f}},
	]

	// plan.Unify's equivalent: every CANDIDATE the always-unify rung
	// disqualified, with the conflicting FQNs — recorded whether or not the
	// demand later resolved through another candidate, exactly as the kernel
	// records oerrors.UnifyError.
	unifyFailures: [
		for cid, v in verdicts
		for tfqn, u in v._unify
		if v._candidates[tfqn] != _|_
		if !u.ok {{component: cid, transformer: tfqn, conflicts: u.conflicts}},
	]

	// compile/module.go's hard gate, as one boolean a caller asserts.
	// Unifying `resolved: true` into an instantiation is the fail-closed
	// refusal: the build errors, and the DATA above still names the demand.
	resolved: len(unresolved) == 0 && len(unmatchedComponents) == 0
}
