// The demonstration cases. `cue vet -c ./...` passes with the must-fail
// cases commented out; uncommenting any one of them reproduces the exact
// error quoted beside it (observed on cue v0.17.1).
//
// Hidden assertions in the style of core's _matchLabelsAreDerived pin every
// derived value, so a regression fails vet rather than drifting silently.
package e0019x09

_instance: #InstanceIdentity & {
	name:      "prod"
	namespace: "media"
}

// ---------------------------------------------------------------------------
// CASE 1 — dot-neutral component, default name. The baseline: nothing
// tightens, the D16 qualified default renders, DNS projects from it.
// ---------------------------------------------------------------------------

case1: #Component & {
	metadata: name: "web"
	#resources: container: #ContainerResource
	#instance: _instance
}

_case1DefaultIsQualified: case1.#names.resourceName == "prod-web"
_case1DefaultIsQualified: true

_case1Fqdn: case1.#names.dns.fqdn == "prod-web.media.svc.cluster.local"
_case1Fqdn: true

// ---------------------------------------------------------------------------
// CASE 2 — dot-neutral component, DOTTED override. The point of D20: k8s
// admits dots on Deployment/DaemonSet/ConfigMap, so with no dot-hostile
// primitive attached the override may carry them.
// ---------------------------------------------------------------------------

case2: #Component & {
	metadata: {
		name:         "exporter"
		resourceName: "metrics.internal.example"
	}
	#resources: container: #ContainerResource
	#instance: _instance
}

_case2OverrideWins: case2.#names.resourceName == "metrics.internal.example"
_case2OverrideWins: true

// ---------------------------------------------------------------------------
// CASE 3 — Expose attached, default name. The constraint arrives but the
// default satisfies it: "prod-web2" is a valid DNS-1035 label. Attaching a
// dot-hostile primitive costs a well-named component nothing.
// ---------------------------------------------------------------------------

case3: #Component & {
	metadata: name: "web2"
	#resources: container: #ContainerResource
	#traits: expose: #ExposeTrait
	#instance: _instance
}

_case3StillQualified: case3.#names.resourceName == "prod-web2"
_case3StillQualified: true

// ---------------------------------------------------------------------------
// CASE 4 — Expose + StatefulWorkload together. Two constraints unify;
// the intersection (DNS-1035) governs. No precedence rule exists anywhere —
// unification IS the precedence rule.
// ---------------------------------------------------------------------------

case4: #Component & {
	metadata: name: "db"
	#resources: container: #ContainerResource
	#traits: expose: #ExposeTrait
	#blueprints: "stateful-workload": #StatefulWorkloadBlueprint
	#instance: _instance
}

_case4Composed: case4.#names.resourceName == "prod-db"
_case4Composed: true

// ---------------------------------------------------------------------------
// MUST FAIL A — dotted override WITH Expose attached. The core scenario the
// mechanism exists for.
//
//   caseFailA: #Component & {
//   	metadata: {
//   		name:         "web3"
//   		resourceName: "web.internal.example"
//   	}
//   	#resources: container: #ContainerResource
//   	#traits: expose: #ExposeTrait
//   	#instance: _instance
//   }
//
// Observed (cue v0.17.1) — 4 errors in empty disjunction; the two that
// matter (of ~14 lines, the #names interpolations re-derive the rest):
//
//   caseFailA.metadata.resourceName: conflicting values "prod-web3" and
//     "web.internal.example"                        ← default branch dies
//   caseFailA.metadata.resourceName: invalid value "web.internal.example"
//     (out of bound =~"^[a-z]([a-z0-9-]*[a-z0-9])?$")   ← override branch
//         ./component.cue:100:28   ← the TRAIT comprehension line
//
// The refusal names the DNS-1035 regex and traces through the trait's
// propagation site — the error points at WHY, not just THAT. The volume is
// noisy (each #names.dns interpolation re-reports); a production landing
// wants the D16-style hidden assertion for a one-line refusal.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// MUST FAIL B — leading-digit instance name meets Expose. The latent hole in
// today's core: "1prod-web" passes #NameType (DNS-1123 admits a leading
// digit) but Service rejects it at apply (DNS-1035 requires a letter). With
// D21 the DEFAULT itself refuses at vet — the apply-time failure moves to
// authoring time.
//
//   caseFailB: #Component & {
//   	metadata: name: "web"
//   	#resources: container: #ContainerResource
//   	#traits: expose: #ExposeTrait
//   	#instance: #InstanceIdentity & {
//   		name:      "1prod"
//   		namespace: "media"
//   	}
//   }
//
// Observed (cue v0.17.1) — vet -c REFUSES, but in exactly the failure
// shape D16's caveat documents for a failed default branch:
//
//   caseFailB.metadata.resourceName: incomplete value
//     =~"^[a-z]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) &
//     strings.MaxRunes(63) & =~"^[a-z0-9](...)*$" & strings.MaxRunes(253)
//
// The offending string "1prod-web" appears NOWHERE — both branches fail
// (default by the trait constraint, bare by non-concreteness) and the
// message is the residual constraint conjunction. Correct refusal,
// illegible message. This is the strongest argument for extending D16's
// hidden-assertion pattern to constraint-tightened defaults.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// MUST FAIL C — dotted override on a StatefulWorkload component.
//
//   caseFailC: #Component & {
//   	metadata: {
//   		name:         "db2"
//   		resourceName: "db.internal"
//   	}
//   	#resources: container: #ContainerResource
//   	#blueprints: "stateful-workload": #StatefulWorkloadBlueprint
//   	#instance: _instance
//   }
//
// Observed (cue v0.17.1) — same shape as MUST FAIL A:
//   caseFailC.metadata.resourceName: 4 errors in empty disjunction:
//   caseFailC.metadata.resourceName: conflicting values "prod-db2" and
//     "db.internal"
//   (…and among the re-derivations:)
//   invalid value "db.internal"
//     (out of bound =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")   ← the blueprint's
//                                                            DNS-1123 label
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// MUST FAIL D — the ceiling still exists: 254 chars overflows
// #ObjectNameType even with no primitive constraint attached.
//
//   caseFailD: #Component & {
//   	metadata: {
//   		name:         "big"
//   		resourceName: strings.Repeat("a", 254)
//   	}
//   	#resources: container: #ContainerResource
//   	#instance: _instance
//   }
//
// Observed (cue v0.17.1):
//   caseFailD.metadata.resourceName: 2 errors in empty disjunction:
//   caseFailD.metadata.resourceName: conflicting values "prod-big" and
//     "aaaa…" (254 a's)
//
// Both branches die (default by conflict with the explicit value, explicit
// by MaxRunes(253)) → empty disjunction → refusal. The MaxRunes violation
// itself is buried below the conflict line; same legibility note as A/B.
// ---------------------------------------------------------------------------
