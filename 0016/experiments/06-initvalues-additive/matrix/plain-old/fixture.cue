package fixture

import core "experiment06.local/x/schemaold:core"

// Hand-written fixture mirroring the #config / debugValues shape of
// modules/cert_manager (modules commit 7c946b0) with the catalog imports
// removed so the experiment stays self-contained.
certManager: core.#Module & {
	metadata: {
		name:       "cert_manager"
		modulePath: "example.com/modules/cert_manager@v2"
		version:    "2.0.1"
	}
	#config: {
		image: {repository: string | *"quay.io/jetstack", tag: string | *"v1.21.0", digest: string | *""}
		controller: {logLevel: int & >=1 & <=10 | *2, replicas: int & >=1 | *1}
		webhook: {logLevel: int & >=1 & <=10 | *2, replicas: int & >=1 | *1, securePort: int & >=1 & <=65535 | *10250}
		cainjector: {logLevel: int & >=1 & <=10 | *2, replicas: int & >=1 | *1}
		leaderElection: namespace: string | *"cert-manager"
	}
	debugValues: {
		image: {repository: "quay.io/jetstack", tag: "v1.21.0", digest: ""}
		controller: {logLevel: 2, replicas: 1}
		webhook: {logLevel: 2, replicas: 1, securePort: 10250}
		cainjector: {logLevel: 2, replicas: 1}
		leaderElection: namespace: "cert-manager"
	}
	#components: {}
}

// Second fixture mirroring modules/metallb's shape (same commit).
metallb: core.#Module & {
	metadata: {
		name:       "metallb"
		modulePath: "example.com/modules/metallb@v2"
		version:    "2.0.1"
	}
	#config: {
		image: {repository: string | *"quay.io/metallb/controller", tag: string | *"v0.16.1", digest: string | *""}
		controller: {logLevel: "debug" | *"info" | "warn" | "error", replicas: int & >=1 | *1}
		speaker: logLevel: "debug" | *"info" | "warn" | "error"
	}
	debugValues: {
		image: {repository: "quay.io/metallb/controller", tag: "v0.16.1", digest: ""}
		controller: {logLevel: "info", replicas: 1}
		speaker: logLevel: "info"
	}
	#components: {}
}
