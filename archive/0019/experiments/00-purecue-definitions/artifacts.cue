package purecue

import c "opmodel.dev/core@v2"

// ── The module ────────────────────────────────────────────────
#TestModule: c.#Module & {
	metadata: {
		name:       "web_app"
		modulePath: "scratch.example/modules/web_app@v0"
		version:    "0.1.0"
	}

	#config: image: string | *"nginx"

	debugValues: image: "nginx"

	#components: web: {
		metadata: name: "web"
		#resources: "scratch.example/cat/resources/container@v1": {
			kind: "Resource"
			metadata: {
				name:           "container"
				modulePath:     "scratch.example/cat/resources"
				apiVersion:     "v1"
				catalogVersion: "0.1.0"
				fqn:            "scratch.example/cat/resources/container@v1"
			}
			matchLabels: "opm.test/primitive": "container"
			spec: container: image: #config.image
		}
	}
}

// ── The instance ──────────────────────────────────────────────
#TestInstance: c.#ModuleInstance & {
	metadata: {
		name:      "web-inst"
		namespace: "prod"
	}
	#module: #TestModule
	values: image: "nginx"
}

