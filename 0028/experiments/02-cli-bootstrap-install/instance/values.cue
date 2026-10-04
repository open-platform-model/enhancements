// Operator-side registry mapping. Inside kind the local registry is
// opm-registry:5000 on the docker network. On this host the kind nodes and
// pods have no internet egress, so opmodel.dev and registry.cue.works go
// through two pull-through mirrors run on the host network (hack/mirrors.sh),
// reached at the kind network gateway 172.18.0.1. On a host with egress the
// value would be
//   "testing.opmodel.dev=opm-registry:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"
package instance

values: {
	registry: "testing.opmodel.dev=opm-registry:5000+insecure,opmodel.dev=172.18.0.1:5055/open-platform-model+insecure,172.18.0.1:5056+insecure"
}
