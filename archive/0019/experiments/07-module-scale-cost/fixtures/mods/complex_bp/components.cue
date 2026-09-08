// complex, BLUEPRINT authoring.
//
// One component per service, each carrying the whole guarded surface described
// in module.cue. The workload is attached as `bp.#StatefulWorkload` and its
// configuration written under `spec.statefulWorkload`.
//
// The paired file is complex_raw/components.cue. Unlike the fleet pair, the raw
// variant here attaches EXACTLY the set the blueprint composes — Container and
// Volumes, plus Scaling, RestartPolicy, UpdateStrategy, SidecarContainers and
// InitContainers — because this module genuinely uses all of them. The delta
// between the two is therefore the blueprint wrapper alone: one `#blueprints`
// entry carrying the blueprint definition (with its composedResources and
// composedTraits lists), the `spec.statefulWorkload` copy of every value, and
// the six guards that propagate it onto the primitive fields.
//
// Both must render byte-identical output; the harness compares digests.
package complex_bp

import (
	"encoding/json"
	"strings"

	bp "opmodel.dev/catalogs/opm/blueprints/v1beta1"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

#components: {
	for _n, _s in #config.services {

		// --- storage ------------------------------------------------------
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
			config: {
				name: "config"
				configMapRef: {
					name:     "\(_n)-extra"
					optional: true
				}
				readOnly: true
			}
			if _s.features.cache {
				cache: {
					name: "cache"
					emptyDir: {
						medium:    "memory"
						sizeLimit: _s.storage.cacheSize
					}
					readOnly: false
				}
			}
			if _s.features.tls {
				tls: {
					name: "tls"
					secretRef: {
						name:     "\(_n)-tls"
						optional: false
					}
					readOnly: true
				}
			}
		}

		// --- runtime arm --------------------------------------------------
		// A disjunction the render must WALK rather than read: the command and
		// both probe paths are decided by which arm matches.
		let _rt = {
			cmd: [...string]
			healthPath: string
			readyPath:  string

			if _s.runtime == "java" {
				cmd: ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
				healthPath: "/actuator/health/liveness"
				readyPath:  "/actuator/health/readiness"
			}
			if _s.runtime == "node" {
				cmd: ["node", "--enable-source-maps", "/app/server.js"]
				healthPath: "/healthz"
				readyPath:  "/readyz"
			}
			if _s.runtime == "python" {
				cmd: ["python3", "-m", "app.server"]
				healthPath: "/health"
				readyPath:  "/ready"
			}
			if _s.runtime == "go" {
				cmd: ["/app/server"]
				healthPath: "/livez"
				readyPath:  "/readyz"
			}
			if _s.runtime == "ruby" {
				cmd: ["bundle", "exec", "puma", "-C", "/app/puma.rb"]
				healthPath: "/health"
				readyPath:  "/health"
			}
		}

		// --- environment --------------------------------------------------
		// Three sources unified: a base set including four downward-API
		// references, a runtime-dependent set, a feature-guarded set, and the
		// module's own passthrough map. A key collision between them is a
		// build error rather than a silent override, which is the behaviour a
		// module of this shape wants.
		let _env = {
			SERVICE_NAME: {name: "SERVICE_NAME", value: _s.name}
			SERVICE_PORT: {name: "SERVICE_PORT", value: "\(_s.port)"}
			RUNTIME: {name: "RUNTIME", value: _s.runtime}
			POD_NAME: {name: "POD_NAME", fieldRef: fieldPath: "metadata.name"}
			POD_IP: {name: "POD_IP", fieldRef: fieldPath: "status.podIP"}
			NODE_NAME: {name: "NODE_NAME", fieldRef: fieldPath: "spec.nodeName"}
			CPU_LIMIT: {name: "CPU_LIMIT", resourceFieldRef: {resource: "limits.cpu", containerName: "app"}}
			MEM_LIMIT: {name: "MEM_LIMIT", resourceFieldRef: {resource: "limits.memory", containerName: "app"}}

			if _s.runtime == "java" {
				JAVA_OPTS: {name: "JAVA_OPTS", value: "-Dfile.encoding=UTF-8"}
				JAVA_TOOL_OPTIONS: {name: "JAVA_TOOL_OPTIONS", value: "-XX:+UseContainerSupport"}
			}
			if _s.runtime == "node" {
				NODE_ENV: {name: "NODE_ENV", value: "production"}
				NODE_OPTIONS: {name: "NODE_OPTIONS", value: "--max-old-space-size=768"}
			}
			if _s.runtime == "python" {
				PYTHONUNBUFFERED: {name: "PYTHONUNBUFFERED", value: "1"}
				PYTHONHASHSEED: {name: "PYTHONHASHSEED", value: "0"}
			}
			if _s.runtime == "go" {
				GOMAXPROCS: {name: "GOMAXPROCS", value: "2"}
				GOMEMLIMIT: {name: "GOMEMLIMIT", value: "768MiB"}
			}
			if _s.runtime == "ruby" {
				RUBY_YJIT_ENABLE: {name: "RUBY_YJIT_ENABLE", value: "1"}
				RAILS_ENV: {name: "RAILS_ENV", value: "production"}
			}

			if _s.features.metrics {
				METRICS_ENABLED: {name: "METRICS_ENABLED", value: "true"}
				METRICS_PORT: {name: "METRICS_PORT", value: "\(_s.metricsPort)"}
				METRICS_PATH: {name: "METRICS_PATH", value: "/metrics"}
			}
			if _s.features.tracing {
				OTEL_SERVICE_NAME: {name: "OTEL_SERVICE_NAME", value: _s.name}
				OTEL_TRACES_SAMPLER: {name: "OTEL_TRACES_SAMPLER", value: "parentbased_traceidratio"}
				OTEL_EXPORTER_OTLP_ENDPOINT: {name: "OTEL_EXPORTER_OTLP_ENDPOINT", value: "http://localhost:4317"}
			}
			if _s.features.cache {
				CACHE_DIR: {name: "CACHE_DIR", value: "/var/cache/app"}
				CACHE_SIZE: {name: "CACHE_SIZE", value: _s.storage.cacheSize}
			}
			if _s.features.tls {
				TLS_CERT_FILE: {name: "TLS_CERT_FILE", value: "/etc/tls/tls.crt"}
				TLS_KEY_FILE: {name: "TLS_KEY_FILE", value: "/etc/tls/tls.key"}
				TLS_MIN_VERSION: {name: "TLS_MIN_VERSION", value: "1.3"}
			}
			if _s.features.profiling {
				PPROF_ENABLED: {name: "PPROF_ENABLED", value: "true"}
			}
			if _s.features.readOnly {
				READ_ONLY_ROOT: {name: "READ_ONLY_ROOT", value: "true"}
			}

			for _k, _v in _s.env {
				(_k): {name: _k, value: _v}
			}
		}

		(_n): {
			metadata: {
				name: _n
				annotations: "app.example.test/runtime": _s.runtime
			}

			bp.#StatefulWorkload
			tr.#Expose
			tr.#DisruptionBudget
			tr.#GracefulShutdown
			tr.#PodMetadata
			res.#ConfigMaps

			spec: {
				statefulWorkload: {
					container: {
						name:    "app"
						image:   _s.image
						command: _rt.cmd
						args: ["--port=\(_s.port)", "--config=/etc/app/config.yaml"]

						ports: {
							app: {name: "app", targetPort: _s.port}
							if _s.features.metrics {
								metrics: {name: "metrics", targetPort: _s.metricsPort}
							}
						}

						env: _env

						resources: {
							requests: {cpu: _s.cpu, memory: _s.memory}
							limits: memory: _s.memory
						}

						volumeMounts: {
							data: _vols.data & {mountPath: "/var/lib/app"}
							config: _vols.config & {mountPath: "/etc/app"}
							if _s.features.cache {
								cache: _vols.cache & {mountPath: "/var/cache/app"}
							}
							if _s.features.tls {
								tls: _vols.tls & {mountPath: "/etc/tls"}
							}
						}

						livenessProbe: {
							httpGet: {path: _rt.healthPath, port: _s.port}
							initialDelaySeconds: 30
							periodSeconds:       10
							failureThreshold:    3
						}
						readinessProbe: {
							httpGet: {path: _rt.readyPath, port: _s.port}
							initialDelaySeconds: 5
							periodSeconds:       5
						}
						startupProbe: {
							httpGet: {path: _rt.healthPath, port: _s.port}
							periodSeconds:    2
							failureThreshold: 30
						}

						securityContext: {
							runAsNonRoot:             true
							runAsUser:                1000
							runAsGroup:               1000
							allowPrivilegeEscalation: false
							readOnlyRootFilesystem:   _s.features.readOnly
							capabilities: drop: ["ALL"]
						}

						preStopCommand: ["/bin/sh", "-c", "sleep 5"]
					}

					volumes: _vols

					initContainers: [{
						name:  "migrate"
						image: _s.image
						command: ["/bin/sh", "-c", "echo migrating \(_n) && sleep 1"]
						env: {
							SERVICE_NAME: {name: "SERVICE_NAME", value: _s.name}
							MIGRATE_ONLY: {name: "MIGRATE_ONLY", value: "true"}
						}
						volumeMounts: data: _vols.data & {mountPath: "/var/lib/app"}
					}]

					sidecarContainers: [
						if _s.features.metrics {
							{
								name: "exporter"
								image: {
									repository: "registry.example.test/exporter"
									tag:        "0.9.0"
									digest:     ""
								}
								ports: metrics: {name: "metrics", targetPort: _s.metricsPort}
								args: ["--scrape=http://localhost:\(_s.port)/metrics"]
								resources: requests: {cpu: "50m", memory: "64Mi"}
							}
						},
						if _s.features.tracing {
							{
								name: "otel-agent"
								image: {
									repository: "registry.example.test/otel-agent"
									tag:        "0.108.0"
									digest:     ""
								}
								ports: otlp: {name: "otlp", targetPort: 4317}
								resources: requests: {cpu: "50m", memory: "96Mi"}
							}
						},
					]

					// `auto` is set, so the workload transformer omits
					// `replicas` and the HPA owns the count. `count` still has
					// to be concrete: the schema requires it.
					scaling: {
						count: _s.autoscale.min
						auto: {
							min: _s.autoscale.min
							max: _s.autoscale.max
							metrics: [{
								type: "cpu"
								target: averageUtilization: _s.autoscale.cpuTarget
							}]
						}
					}

					restartPolicy: "Always"
					updateStrategy: {
						type: "RollingUpdate"
						rollingUpdate: partition: 0
					}
				}

				expose: {
					type: "ClusterIP"
					ports: {
						app: {name: "app", targetPort: _s.port}
						if _s.features.metrics {
							metrics: {name: "metrics", targetPort: _s.metricsPort}
						}
					}
				}

				disruptionBudget: minAvailable: _s.disruption.minAvailable

				gracefulShutdown: terminationGracePeriodSeconds: 60

				podMetadata: {
					labels: "app.example.test/tier": "backend"
					annotations: {
						"app.example.test/config-hash": "\(len(_s.settings))"
						if _s.features.metrics {
							"prometheus.io/scrape": "true"
							"prometheus.io/port":   "\(_s.metricsPort)"
						}
					}
				}

				configMaps: {
					"app-config": {
						immutable: false
						data: {
							"config.properties": strings.Join([
								for _k, _v in _s.settings {"\(_k)=\(_v)"},
							], "\n")
							"config.json": json.Marshal(_s.settings)
							"runtime.txt": _s.runtime
						}
					}
					if _s.features.tracing {
						"tracing-config": {
							immutable: false
							data: "otel.yaml": "exporters:\n  otlp:\n    endpoint: localhost:4317\n"
						}
					}
				}
			}
		}
	}
}
