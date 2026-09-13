// Catalog manifest for the OPM core catalog. Embeds bare c.#Catalog
// (modules pattern — no Catalog: wrapper), sources metadata from the sibling
// identity/ package, and enumerates every transformer keyed by its own
// metadata.fqn. The #Catalog pattern constraint stamps each entry's
// modulePath/version in lockstep (enhancement 0001 D19/D25).
//
// Resources, traits, and blueprints are not enumerated here — they surface
// transitively through each transformer's required/optional maps.
package opm

import (
	c "opmodel.dev/core@v2"
	id "opmodel.dev/catalogs/opm/identity"
	t "opmodel.dev/catalogs/opm/transformers"
)

c.#Catalog
metadata: {
	modulePath:  id.ModulePath
	version:     id.Version
	description: "OPM core catalog — Kubernetes resources, traits, blueprints, and transformers"
}

#transformers: {
	(t.#ConfigMapTransformer.metadata.fqn):              t.#ConfigMapTransformer
	(t.#CRDTransformer.metadata.fqn):                    t.#CRDTransformer
	(t.#CronJobTransformer.metadata.fqn):                t.#CronJobTransformer
	(t.#DaemonSetTransformer.metadata.fqn):              t.#DaemonSetTransformer
	(t.#DeploymentTransformer.metadata.fqn):             t.#DeploymentTransformer
	(t.#GrpcRouteTransformer.metadata.fqn):              t.#GrpcRouteTransformer
	(t.#HPATransformer.metadata.fqn):                    t.#HPATransformer
	(t.#HttpRouteTransformer.metadata.fqn):              t.#HttpRouteTransformer
	(t.#JobTransformer.metadata.fqn):                    t.#JobTransformer
	(t.#NetworkPolicyTransformer.metadata.fqn):          t.#NetworkPolicyTransformer
	(t.#PDBTransformer.metadata.fqn):                    t.#PDBTransformer
	(t.#PVCTransformer.metadata.fqn):                    t.#PVCTransformer
	(t.#RoleTransformer.metadata.fqn):                   t.#RoleTransformer
	(t.#SecretTransformer.metadata.fqn):                 t.#SecretTransformer
	(t.#ServiceAccountResourceTransformer.metadata.fqn): t.#ServiceAccountResourceTransformer
	(t.#ServiceTransformer.metadata.fqn):                t.#ServiceTransformer
	(t.#StatefulsetTransformer.metadata.fqn):            t.#StatefulsetTransformer
	(t.#TcpRouteTransformer.metadata.fqn):               t.#TcpRouteTransformer
	(t.#TlsRouteTransformer.metadata.fqn):               t.#TlsRouteTransformer

	// Experimental abstraction candidates (v1alpha1 contracts; ex
	// catalog_opm_experimental — 0010 D47).
	(t.#AdmissionPolicyTransformer.metadata.fqn):   t.#AdmissionPolicyTransformer
	(t.#MutatingWebhookTransformer.metadata.fqn):   t.#MutatingWebhookTransformer
	(t.#NamespaceTransformer.metadata.fqn):         t.#NamespaceTransformer
	(t.#ValidatingWebhookTransformer.metadata.fqn): t.#ValidatingWebhookTransformer
}
