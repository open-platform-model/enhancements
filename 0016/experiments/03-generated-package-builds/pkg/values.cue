package instance

values: {
	image: {
		repository: "quay.io/jetstack"
		tag:        "v1.21.0"
		digest:     ""
		pullPolicy: "IfNotPresent"
	}
	controller: {
		logLevel: 2
		replicas: 1
		resources: {
			requests: {cpu: "10m", memory: "32Mi"}
			limits: {cpu: "100m", memory: "128Mi"}
		}
	}
	webhook: {
		logLevel:   2
		replicas:   1
		securePort: 10250
		resources: {
			requests: {cpu: "10m", memory: "32Mi"}
			limits: {cpu: "100m", memory: "128Mi"}
		}
	}
	cainjector: {
		logLevel: 2
		replicas: 1
		resources: {
			requests: {cpu: "10m", memory: "32Mi"}
			limits: {cpu: "100m", memory: "128Mi"}
		}
	}
	leaderElection: {
		namespace: "cert-manager"
	}
}
