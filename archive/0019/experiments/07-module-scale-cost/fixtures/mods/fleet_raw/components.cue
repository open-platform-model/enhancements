// fleet, RAW authoring.
//
// The same fleet as fleet_bp/components.cue, attached as primitives: the
// Container and Volumes RESOURCES and the Scaling / RestartPolicy /
// UpdateStrategy TRAITS, with their configuration written directly onto the
// spec fields the transformers read.
//
// Three differences from the blueprint variant, and nothing else:
//
//  1. no `#blueprints` entry on the component (and so no embedded
//     composedResources / composedTraits lists);
//  2. no `spec.statefulWorkload` / `spec.statelessWorkload` wrapper, and so no
//     propagation guards from it onto the primitive fields;
//  3. the SidecarContainers and InitContainers traits are absent, because this
//     module does not use them and an author writing primitives would not
//     attach them.
//
// (3) is a real part of what choosing a blueprint costs, not a flaw in the
// comparison: a blueprint is all-or-nothing. The `complex` fixture is the
// controlled half — it uses sidecars and init containers, so its raw variant
// attaches the identical set and the delta there is (1) and (2) alone.
//
// `metadata.labels."core.opmodel.dev/workload-type"` is written by hand here.
// It is required by res.#ContainerResource's matchLabels (0010 D36) and is
// supplied by the blueprint wrapper in the other variant, so writing it is
// part of the raw authoring cost rather than an addition to the fixture.
package fleet_raw

import (
	"strings"

	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#components: {
	let _domain = #config.domain
	let _servers = #config.servers

	for _n, _s in _servers {
		let _vols = {
			data: {
				name: "data"
				persistentClaim: {
					size:         _s.storage.size
					accessMode:   "ReadWriteOnce"
					storageClass: _s.storage.storageClass
				}
				readOnly: false
			}
		}

		"server-\(_n)": {
			metadata: {
				name: "server-\(_n)"
				labels: "core.opmodel.dev/workload-type": "stateful"
			}

			// Answered at the ATTACHMENT SITE, not on the component.
			// res.#ContainerResource declares this as a REQUIRED matching key
			// with a disjunction for a value (0010 D36), and core derives
			// `matchLabels` from the attached primitives with
			// `_matchLabelsAreDerived` refusing any key the component adds
			// itself. So a raw author cannot write `matchLabels:` directly;
			// the key is answered by narrowing the resource that owns it.
			// This is precisely the work a workload blueprint exists to do.
			#resources: (res.#ContainerResource.metadata.fqn): matchLabels: "core.opmodel.dev/workload-type": "stateful"

			res.#Container
			res.#Volumes
			res.#ConfigMaps
			tr.#Scaling
			tr.#RestartPolicy
			tr.#UpdateStrategy
			tr.#Expose

			spec: {
				container: {
					name:  "server"
					image: _s.image
					ports: game: {
						name:       "game"
						targetPort: _s.port
					}
					env: {
						EULA: {name: "EULA", value: "true"}
						TYPE: {name: "TYPE", value: "PAPER"}
						MEMORY: {name: "MEMORY", value: _s.memory}
						MOTD: {name: "MOTD", value: _s.motd}
						SERVER_NAME: {name: "SERVER_NAME", value: _s.name}
						SERVER_PORT: {name: "SERVER_PORT", value: "\(_s.port)"}
					}
					resources: {
						requests: {cpu: "500m", memory: _s.memory}
						limits: memory: _s.memory
					}
					volumeMounts: data: _vols.data & {mountPath: "/data"}
				}

				volumes: _vols

				if _s.enabled {
					scaling: count: 1
				}
				if !_s.enabled {
					scaling: count: 0
				}

				restartPolicy: "Always"
				updateStrategy: type: "RollingUpdate"

				expose: {
					type:      "ClusterIP"
					clusterIP: "None"
					ports: game: {
						name:       "game"
						targetPort: _s.port
					}
				}

				configMaps: "server-props": {
					immutable: false
					data: {
						"server.properties": strings.Join([
							for _k, _v in _s.settings {"\(_k)=\(_v)"},
						], "\n")
						"motd.txt": _s.motd
					}
				}
			}
		}
	}

	router: {
		metadata: {
			name: "router"
			labels: "core.opmodel.dev/workload-type": "stateless"
		}

		#resources: (res.#ContainerResource.metadata.fqn): matchLabels: "core.opmodel.dev/workload-type": "stateless"

		res.#Container
		tr.#Scaling
		tr.#RestartPolicy
		tr.#UpdateStrategy
		tr.#Expose
		tr.#HttpRoute

		spec: {
			container: {
				name:  "router"
				image: #config.router.image
				ports: proxy: {
					name:       "proxy"
					targetPort: #config.router.port
				}
				args: [
					for _n, _s in _servers if _s.enabled {
						"--mapping=\(_n).\(_domain)=server-\(_n):\(_s.port)"
					},
				]
				env: {
					IN_KUBE_CLUSTER: {name: "IN_KUBE_CLUSTER", value: "true"}
					API_BINDING: {name: "API_BINDING", value: ":8080"}
				}
				resources: {
					requests: {cpu: "100m", memory: "128Mi"}
					limits: memory: "256Mi"
				}
			}

			scaling: count: #config.router.replicas
			restartPolicy: "Always"
			updateStrategy: type: "RollingUpdate"

			expose: {
				type: "LoadBalancer"
				ports: proxy: {
					name:       "proxy"
					targetPort: #config.router.port
				}
			}

			httpRoute: {
				hostnames: [_domain]
				rules: [{
					backendPort: #config.router.port
					matches: [{path: {type: "PathPrefix", value: "/"}}]
				}]
			}
		}
	}
}
