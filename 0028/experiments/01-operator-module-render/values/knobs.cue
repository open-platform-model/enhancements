// Exercises every #config knob (hack/run.sh renders it to out/rendered-knobs.yaml).
package values

values: {
	image: {tag: "v1.0.0-beta.6", digest: ""}
	registry:              "testing.opmodel.dev=opm-registry:5000+insecure,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works"
	defaultServiceAccount: "opm-applier"
	extraArgs: ["--max-concurrent-renders=2", "--zap-log-level=debug"]
	replicas:   2
	goMemLimit: "1638MiB"
	resources: {requests: {cpu: "50m", memory: "128Mi"}, limits: {cpu: 1, memory: "2Gi"}}
}
