// fleet, BLUEPRINT authoring.
//
// Every workload is attached as a Blueprint (`bp.#StatefulWorkload`,
// `bp.#StatelessWorkload`) and its configuration is written under the
// blueprint's own spec field, from which the blueprint propagates it onto the
// primitive fields the transformers actually read.
//
// The paired file is fleet_raw/components.cue, which attaches the primitives
// directly and writes the same values onto those same fields. The two are
// required to render byte-identical output; the harness compares digests and
// fails the run if they diverge. Everything that differs between them is
// therefore authoring style, and the cost difference is what that style costs.
//
// What the blueprint adds here, beyond the indirection:
//
//	res.#ContainerResource, res.#VolumesResource      also attached by raw
//	tr.#ScalingTrait, #RestartPolicyTrait,
//	tr.#UpdateStrategyTrait                            also attached by raw
//	tr.#SidecarContainersTrait, #InitContainersTrait   NOT used by this module
//
// The last line is the point of the fleet half of the style comparison: a
// blueprint carries the whole workload vocabulary whether the module uses it or
// not. The `complex` fixture uses sidecars and init containers, so there the
// raw variant attaches the identical set and the comparison isolates the
// blueprint wrapper alone.
package fleet_bp

import (
	"strings"

	bp "opmodel.dev/catalogs/opm/blueprints/v1beta1"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#components: {
	let _domain = #config.domain
	let _servers = #config.servers

	// One component per fleet member.
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
			}

			bp.#StatefulWorkload
			tr.#Expose
			res.#ConfigMaps

			spec: {
				statefulWorkload: {
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

					// A disabled server stays in the fleet with zero replicas
					// rather than disappearing, which is what makes `enabled`
					// a scaling decision instead of a component-set decision.
					if _s.enabled {
						scaling: count: 1
					}
					if !_s.enabled {
						scaling: count: 0
					}

					restartPolicy: "Always"
					updateStrategy: type: "RollingUpdate"
				}

				// Headless: the governing Service for a StatefulSet's stable
				// per-pod identity.
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

	// The aggregating component. Its args are a fold over the whole fleet, so
	// no server component can be evaluated independently of the others.
	router: {
		metadata: {
			name: "router"
		}

		bp.#StatelessWorkload
		tr.#Expose
		tr.#HttpRoute

		spec: {
			statelessWorkload: {
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
			}

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
