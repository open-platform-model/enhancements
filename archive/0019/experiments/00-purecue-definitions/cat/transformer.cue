package cat

import c "opmodel.dev/core@v2"

// ── The transformer ───────────────────────────────────────────
#TestTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     "scratch.example/cat/transformers"
		name:           "deployment-transformer"
		catalogVersion: "0.1.0"
		fqn:            "scratch.example/cat/transformers/deployment-transformer@0.1.0"
	}

	requiredResources: "scratch.example/cat/resources/container@v1": {
		kind: "Resource"
		metadata: {
			name:           "container"
			modulePath:     "scratch.example/cat/resources"
			apiVersion:     "v1"
			catalogVersion: "0.1.0"
			fqn:            "scratch.example/cat/resources/container@v1"
		}
		matchLabels: "opm.test/primitive": "container"
		spec: container: _
	}

	#transform: {
		#moduleInstance: _
		#component:      _
		#context:        c.#TransformerContext

		output: {
			kind: "Deployment"

			// regular fields (work today)
			image: #component.spec.container.image

			// DEFINITION fields (stripped by the kernel today)
			rName:     #component.#names.resourceName
			fqdn:      #component.#names.dns.fqdn
			resources: [for k, _ in #component.#resources {k}]
			ns:        #component.#instance.namespace

			// the never-filled slot
			instName: #moduleInstance.metadata.name
			instFQN:  #moduleInstance.metadata.fqn
		}
	}
}
