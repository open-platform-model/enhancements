package v1beta1

import (
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

/////////////////////////////////////////////////////////////////
//// Blueprint + trait attachment
////
//// This exists because the failure it guards against is invisible until a
//// module tries it, and cost a release to discover.
////
//// #NetworkPolicyTrait originally shipped in catalog_opm_experimental.
//// Attaching it to a component built from a blueprint defined HERE failed
//// outright:
////
////   field not allowed
////     ...spec.networkPolicy
////     > core component.cue:80   (spec: close({_allFields}))
////
//// A blueprint's spec is CLOSED, and CUE will not admit a field contributed by
//// a trait from a FOREIGN CUE MODULE — even though OPM's own transformer
//// matching handles cross-catalog attachment perfectly well. #DisruptionBudget
//// worked only because it ships in this catalog alongside the blueprint.
////
//// The rule that follows: a standalone RESOURCE may incubate in the
//// experimental catalog, but a TRAIT that has to ride a stable blueprint must
//// live here. These assertions fail the moment that is violated again.
/////////////////////////////////////////////////////////////////

_testNetPolOnStateless: #StatelessWorkload & {
	tr.#NetworkPolicy

	metadata: name: "istiod"

	spec: {
		statelessWorkload: container: {
			name: "discovery"
			image: {repository: "docker.io/istio/pilot", tag: "1.30.3"}
		}
		networkPolicy: {
			policyTypes: ["Ingress", "Egress"]
			ingress: [{ports: [{protocol: "TCP", port: 15012}]}]
			egress: [{}]
		}
	}
}

// Arithmetic forces resolution. An unresolved trait field is merely incomplete,
// which plain `cue vet` accepts — so a bare reference would not prove
// attachment even if the field were never admitted.
_testNetPolStatelessAttached: (len(_testNetPolOnStateless.spec.networkPolicy.policyTypes) + 0) & 2

// The daemon blueprint is the other one that carries a NetworkPolicy in
// practice (ztunnel, istio-cni), so cover it too rather than assuming the
// closedness behaviour is uniform across blueprints.
_testNetPolOnDaemon: #DaemonWorkload & {
	tr.#NetworkPolicy

	metadata: name: "ztunnel"

	spec: {
		daemonWorkload: container: {
			name: "istio-proxy"
			image: {repository: "docker.io/istio/ztunnel", tag: "1.30.3"}
		}
		networkPolicy: policyTypes: ["Ingress"]
	}
}

_testNetPolDaemonAttached: (len(_testNetPolOnDaemon.spec.networkPolicy.policyTypes) + 0) & 1

// spec.networkPolicy must appear ONLY where the trait is explicitly attached —
// a bare blueprint must not grow it, or every component in every module would
// carry the field. Attachment stays opt-in, per the #HostNetwork /
// #SecurityContext precedent.
//
// Note this concerns the trait's spec-LEVEL field. A blueprint's own
// composedTraits contribute fields inside spec.statelessWorkload rather than at
// spec level, so they are a different mechanism and cannot trip this guard.
_testNetPolNotComposedStateless: [
	if (#StatelessWorkload & {metadata: name: "x"}).spec.networkPolicy != _|_ {"leaked"},
] & []
