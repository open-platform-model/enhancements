// multi — experiment fixture for 0029 experiment 02. Built from copies of the
// opm-operator podinfo and hello fixtures (test/fixtures/modules, 2026-10-04)
// plus a cluster-scoped Role component in the style of modules/metallb.
// Renders, with extra=true: Deployment + Service (web), ConfigMap (extra),
// ServiceAccount (reader-sa), ClusterRole + ClusterRoleBinding (reader-rbac).
package multi

import (
	"strings"

	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"

	id "testing.opmodel.dev/modules/experiments/handoff-id/multi/identity"
)

m.#Module

metadata: {
	_segments:   strings.Split(strings.SplitN(id.ModulePath, "@", 2)[0], "/")
	name:        _segments[len(_segments)-1]
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Handoff experiment fixture: namespaced and cluster-scoped objects"
}

#config: {
	image: res.#Image & {repository: string | *"ghcr.io/stefanprodan/podinfo", tag: string | *"6.7.1", digest: string | *""}
	replicas: int | *1
	// extra gates the ConfigMap component; flipping it to false is the prune probe.
	extra:   bool | *true
	message: string | *"hello from multi"
}

debugValues: {
	image: {repository: "ghcr.io/stefanprodan/podinfo", tag: "6.7.1", digest: ""}
	replicas: 1
	extra:    true
	message:  "hello from multi"
}
