// Hermetic CLI config for experiment 0029/01 (copied in shape from
// cli/hack/opm-config.cue). testing.opmodel.dev resolves from the local
// registry container on the host; opmodel.dev from GHCR.
package config

config: {
	registry: "testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"

	kubernetes: {
		kubeconfig: "~/.kube/config"
		context:    "kind-opm-handoff-src"
		namespace:  "default"
	}

	log: timestamps: true
}
