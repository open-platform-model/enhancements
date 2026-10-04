// Hermetic opm CLI config for this experiment. Copied from
// cli/hack/opm-config.cue (2026-10-04); registry and context changed.
package config

config: {
	registry: "testing.opmodel.dev=127.0.0.1:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"
	kubernetes: {
		kubeconfig: "~/.kube/config"
		context:    "kind-opm-handoff-id"
		namespace:  "default"
	}
	log: {
		timestamps: true
		kubernetes: apiWarnings: "debug"
	}
}
