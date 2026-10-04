// Experiment 0029/01 case (iii): the CLI resolves testing.opmodel.dev from a
// repository prefix (cli-only/) the operator mapping never reads, standing in
// for a private mirror or credentials only the CLI has.
package config

config: {
	registry: "testing.opmodel.dev=127.0.0.1:5000/cli-only+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"

	kubernetes: {
		kubeconfig: "~/.kube/config"
		context:    "kind-opm-handoff-src"
		namespace:  "default"
	}

	log: timestamps: true
}
