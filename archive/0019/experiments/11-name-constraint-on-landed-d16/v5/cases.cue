// The demonstration cases. `cue vet -c ./...` passes with the must-fail
// cases commented out; uncommenting any one of them reproduces the exact
// error quoted beside it (observed on cue v0.17.1).
//
// Hidden assertions in the style of core's _matchLabelsAreDerived pin every
// derived value, so a regression fails vet rather than drifting silently.
package e0019x11v5

_instance: #InstanceIdentity & {
	name:      "prod"
	namespace: "media"
}

// The workload-type key is REQUIRED on the container resource (mirrors
// container.cue:29); the original cases answer it "stateless", which
// contributes top and leaves their results untouched.
_stateless: matchLabels: "core.opmodel.dev/workload-type": "stateless"
_stateful: matchLabels:  "core.opmodel.dev/workload-type": "stateful"

// ---------------------------------------------------------------------------
// CASE 1 — dot-neutral component, default name. The baseline: nothing
// tightens, the D16 qualified default renders, DNS projects from it.
// ---------------------------------------------------------------------------

case1: #Component & {
	metadata: name: "web"
	#resources: container: #ContainerResource & _stateless
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
	#resources: container: #ContainerResource & _stateless
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
	#resources: container: #ContainerResource & _stateless
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
	#resources: container: #ContainerResource & _stateless
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
//   	#resources: container: #ContainerResource & _stateless
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
//   	#resources: container: #ContainerResource & _stateless
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
//   	#resources: container: #ContainerResource & _stateless
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
//   	#resources: container: #ContainerResource & _stateless
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

// ===========================================================================
// EXTENSION 2026-08-24 — resource-owned CONDITIONAL constraint.
// A raw #Container answers workload-type on the resource entry (no blueprint
// attached). The resource reads its OWN label and contributes #NameType only
// when it is "stateful".
// ===========================================================================

// ---------------------------------------------------------------------------
// CASE 5 — raw stateful container, default name. The constraint arrives from
// the resource itself; the qualified default satisfies it.
// ---------------------------------------------------------------------------

case5: #Component & {
	metadata: name: "cache"
	#resources: container: #ContainerResource & _stateful
	#instance: _instance
}

_case5RawStatefulDefault: case5.#names.resourceName == "prod-cache"
_case5RawStatefulDefault: true

// ---------------------------------------------------------------------------
// CASE 6 — raw STATELESS container, dotted override. The conditional falls
// through to top, so the #ObjectNameType ceiling stays: the dots survive.
// This is the control that proves the condition is read, not the constant.
// ---------------------------------------------------------------------------

case6: #Component & {
	metadata: {
		name:         "exporter2"
		resourceName: "metrics.internal.example"
	}
	#resources: container: #ContainerResource & _stateless
	#instance: _instance
}

_case6StatelessKeepsDots: case6.#names.resourceName == "metrics.internal.example"
_case6StatelessKeepsDots: true

// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Cases added by experiment 11 (the D16-landed spelling). Pass cases are live;
// must-fail cases are commented with the observed cue v0.17.1 output.
// ---------------------------------------------------------------------------

// PASS G — a 66-rune default on a stateless component: admitted, because the
// default branch's ceiling is now #ObjectNameType (253) and no attached
// primitive narrows it.
caseG: #Component & {
	metadata: name: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	#resources: container: #ContainerResource & _stateless
	#instance: _instance
}

_caseGLongDefaultAdmitted: caseG.#names.resourceName == "prod-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
_caseGLongDefaultAdmitted: true

// PASS I — dotted override, no dot-hostile primitive: admitted.
caseI: #Component & {
	metadata: {
		name:         "x"
		resourceName: "a.b.c"
	}
	#resources: container: #ContainerResource & _stateless
	#instance: _instance
}

_caseIDotsAdmitted: caseI.#names.resourceName == "a.b.c"
_caseIDotsAdmitted: true

// PASS J — an override that satisfies Expose's DNS-1035 constraint.
caseJ: #Component & {
	metadata: {
		name:         "x"
		resourceName: "istiod"
	}
	#resources: container: #ContainerResource & _stateless
	#traits: expose: #ExposeTrait
	#instance: _instance
}

_caseJExactServiceName: caseJ.#names.resourceName == "istiod"
_caseJExactServiceName: true

// MUST FAIL B — leading-digit instance + Expose. The default "1prod-web" is
// a valid DNS-1123 label but not a DNS-1035 one.
//
//   caseFailB: #Component & {
//   	metadata: name: "web"
//   	#resources: container: #ContainerResource & _stateless
//   	#traits: expose: #ExposeTrait
//   	#instance: {name: "1prod", namespace: "media"}
//   }
//
// Observed:
//   caseFailB._nameFits: invalid value "1prod-web"
//     (out of bound =~"^[a-z]([a-z0-9-]*[a-z0-9])?$"):
//       ./types.cue:66:28
//       ./component.cue:47:13
//
// MUST FAIL F — 66-rune default on a raw STATEFUL container (D23's
// resource-owned conditional constraint).
//
//   caseFailF: #Component & {
//   	metadata: name: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
//   	#resources: container: #ContainerResource & _stateful
//   	#instance: _instance
//   }
//
// Observed:
//   caseFailF._nameFits: invalid value "prod-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
//     (does not satisfy strings.MaxRunes(63)):
//       ./types.cue:50:81
//       ./component.cue:47:13
//
// MUST FAIL A / E — dotted override + Expose / + raw stateful: refused naming
// the string and the DNS-1035 / DNS-1123 label regex respectively.
// MUST FAIL K — 254-rune override, no primitive: refused by the error() arm
// (D16's mechanism, unchanged), naming the string.
