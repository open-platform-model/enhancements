// Example instance — proves the #ctx projection and per-component #release
// injection compile end-to-end on a concrete module + release. Lives in the
// same package as target.cue; `cue vet ./...` from this directory fails if
// the projection breaks.
//
// Two components ("api", "worker") with one resourceName override on api.
// Expected behaviour:
//   - api.#names.resourceName == "api-public"   (override flows in)
//   - worker.#names.resourceName == "worker"     (defaults to metadata.name)
//   - worker.#names.dns.fqdn == "worker.app-a-prod.svc.cluster.local"
//   - example_module.#ctx.components.api.dns.fqdn ==
//       "api-public.app-a-prod.svc.cluster.local"
//   - example_module.#ctx.components mirrors #components.<id>.#names
package schema

example_module: #Module & {
	metadata: {
		name:       "app-a"
		modulePath: "opmodel.dev/modules/app-a"
		version:    "1.0.0"
		uuid:       "00000000-0000-0000-0000-00000000a000"
	}
	#components: {
		api: {
			metadata: {
				name:         "api"
				resourceName: "api-public"
			}
			#resources: {}
			spec: {}
		}
		worker: {
			metadata: name: "worker"
			#resources: {}
			spec: {}
		}
	}
	#config:     {}
	debugValues: {}
	#ctx: release: {
		name:      "app-a-prod"
		namespace: "app-a-prod"
		uuid:      "00000000-0000-0000-0000-00000000b000"
		// clusterDomain falls back to default
	}
}

// Concrete checks — CUE fails the file if any unification mismatches.
_assertions: {
	_apiNames:    example_module.#components.api.#names
	_workerNames: example_module.#components.worker.#names

	// api override propagates into #names.resourceName and through DNS.
	apiResourceName: _apiNames.resourceName & "api-public"
	apiFqdn:         _apiNames.dns.fqdn & "api-public.app-a-prod.svc.cluster.local"

	// worker defaults to metadata.name.
	workerResourceName: _workerNames.resourceName & "worker"
	workerFqdn:         _workerNames.dns.fqdn & "worker.app-a-prod.svc.cluster.local"

	// Projection: #ctx.components.<id> equals #components.<id>.#names.
	projApiFqdn:    example_module.#ctx.components.api.dns.fqdn & "api-public.app-a-prod.svc.cluster.local"
	projWorkerFqdn: example_module.#ctx.components.worker.dns.fqdn & "worker.app-a-prod.svc.cluster.local"
}
