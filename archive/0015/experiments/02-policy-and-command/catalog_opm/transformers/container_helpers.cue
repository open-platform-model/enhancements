package transformers

import (
	"strconv"

	k8scorev1 "opmodel.dev/catalogs/opm/schemas/kubernetes/core/v1"
	schemas "opmodel.dev/catalogs/opm/schemas"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

// WHY: Env var dispatch:
//   value?            -> { name, value }
//   fieldRef?         -> { name, valueFrom: { fieldRef: ... } }
//   resourceFieldRef? -> { name, valueFrom: { resourceFieldRef: ... } }
//
// Usage:
//   (#ToK8sContainer & {"in": _container}).out

// #ToK8sContainer converts an OPM #ContainerSchema to a Kubernetes #Container.
// OPM uses struct-keyed env/ports/volumeMounts; Kubernetes expects lists.
#ToK8sContainer: {
	X="in": res.#ContainerSchema

	out: k8scorev1.#Container & {
		name:            X.name
		image:           X.image.reference
		imagePullPolicy: X.image.pullPolicy
		if X.command != _|_ {
			command: X.command
		}
		if X.args != _|_ {
			args: X.args
		}
		if X.ports != _|_ {
			ports: [for _, p in X.ports {
				name:          p.name
				containerPort: p.targetPort
				protocol:      p.protocol
				if p.hostIP != _|_ {hostIP: p.hostIP}
				if p.hostPort != _|_ {hostPort: p.hostPort}
			}]
		}

		// Env var dispatch: map OPM source types to K8s env entries
		if X.env != _|_ {
			env: [for _, e in X.env {
				// Literal value — inline string
				if e.value != _|_ {
					name:  e.name
					value: e.value
				}

				// Downward API — pod/container metadata
				if e.fieldRef != _|_ {
					name: e.name
					valueFrom: fieldRef: {
						fieldPath: e.fieldRef.fieldPath
						if e.fieldRef.apiVersion != _|_ {
							apiVersion: e.fieldRef.apiVersion
						}
					}
				}

				// Container resource limits/requests
				if e.resourceFieldRef != _|_ {
					name: e.name
					valueFrom: resourceFieldRef: {
						resource: e.resourceFieldRef.resource
						if e.resourceFieldRef.containerName != _|_ {
							containerName: e.resourceFieldRef.containerName
						}
						if e.resourceFieldRef.divisor != _|_ {
							divisor: e.resourceFieldRef.divisor
						}
					}
				}
			}]
		}

		// Bulk injection from ConfigMaps/Secrets
		if X.envFrom != _|_ {
			envFrom: X.envFrom
		}

		if X.resources != _|_ {
			resources: {
				if X.resources.requests != _|_ {
					requests: {
						if X.resources.requests.cpu != _|_ {
							cpu: (schemas.#NormalizeCPU & {in: X.resources.requests.cpu}).out
						}
						if X.resources.requests.memory != _|_ {
							memory: (schemas.#NormalizeMemory & {in: X.resources.requests.memory}).out
						}
					}
				}

				if X.resources.limits != _|_ {
					limits: {
						if X.resources.limits.cpu != _|_ {
							cpu: (schemas.#NormalizeCPU & {in: X.resources.limits.cpu}).out
						}
						if X.resources.limits.memory != _|_ {
							memory: (schemas.#NormalizeMemory & {in: X.resources.limits.memory}).out
						}
					}
				}

				// GPU extended resource: emitted to both requests and limits.
				// Kubernetes requires extended resource requests == limits (no overcommit).
				if X.resources.gpu != _|_ {
					let _gpuVal = strconv.FormatInt(X.resources.gpu.count, 10)
					requests: {"\(X.resources.gpu.resource)": _gpuVal}
					limits: {"\(X.resources.gpu.resource)": _gpuVal}
				}

				// Same rule per entry, for a container claiming devices from more
				// than one plugin. The map key is a local label only — `resource`
				// is the name that reaches Kubernetes, so two entries may share a
				// resource and will unify rather than overwrite.
				if X.resources.gpus != _|_ {
					for _, _g in X.resources.gpus {
						let _gVal = strconv.FormatInt(_g.count, 10)
						requests: {"\(_g.resource)": _gVal}
						limits: {"\(_g.resource)": _gVal}
					}
				}
			}
		}

		// Container-level security context
		if X.securityContext != _|_ {
			let _sc = X.securityContext
			securityContext: {
				if _sc.privileged != _|_ {
					privileged: _sc.privileged
				}
				if _sc.runAsNonRoot != _|_ {
					runAsNonRoot: _sc.runAsNonRoot
				}
				if _sc.runAsUser != _|_ {
					runAsUser: _sc.runAsUser
				}
				if _sc.runAsGroup != _|_ {
					runAsGroup: _sc.runAsGroup
				}
				if _sc.readOnlyRootFilesystem != _|_ {
					readOnlyRootFilesystem: _sc.readOnlyRootFilesystem
				}
				if _sc.allowPrivilegeEscalation != _|_ {
					allowPrivilegeEscalation: _sc.allowPrivilegeEscalation
				}
				if _sc.capabilities != _|_ {
					capabilities: {
						if _sc.capabilities.add != _|_ {add: _sc.capabilities.add}
						if _sc.capabilities.drop != _|_ {drop: _sc.capabilities.drop}
					}
				}
			}
		}

		// Volume mounts: extract only K8s-valid fields (strip embedded volume source data)
		if X.volumeMounts != _|_ {
			volumeMounts: [for _, vm in X.volumeMounts {
				name:      vm.name
				mountPath: vm.mountPath
				if vm.subPath != _|_ {subPath: vm.subPath}
				if vm.readOnly == true {readOnly: vm.readOnly}

				// Guarded, not defaulted: emitting an explicit "None" on every
				// mount would be noise on the ~100% of mounts that want the
				// Kubernetes default.
				if vm.mountPropagation != _|_ {mountPropagation: vm.mountPropagation}
			}]
		}

		if X.startupProbe != _|_ {
			startupProbe: X.startupProbe
		}
		if X.livenessProbe != _|_ {
			livenessProbe: X.livenessProbe
		}
		if X.readinessProbe != _|_ {
			readinessProbe: X.readinessProbe
		}

		// Pre-stop lifecycle hook
		if X.preStopCommand != _|_ {
			lifecycle: preStop: exec: command: X.preStopCommand
		}
	}
}

// #ToK8sContainers converts a list of OPM containers to Kubernetes containers.
//
// Usage:
//   (#ToK8sContainers & {"in": _initContainers}).out
#ToK8sContainers: {
	X="in": [...res.#ContainerSchema]
	out: [for c in X {
		(#ToK8sContainer & {"in": c}).out
	}]
}

// #ToK8sKeyToPath converts OPM key/path/mode items to K8s KeyToPath entries.
// Shared by the inline-secret, external-object, and projection branches of
// #ToK8sVolumes.
#ToK8sKeyToPath: {
	X="in": [...res.#SecretVolumeItemSchema]
	out: [for item in X {
		key:  item.key
		path: item.path
		if item.mode != _|_ {
			mode: item.mode
		}
	}]
}

// #ToK8sObjectProjection converts an OPM object projection (configMap or
// secret source inside a projected volume) to its K8s shape. Both K8s
// projection types are LocalObjectReference-based, so both use `name`.
#ToK8sObjectProjection: {
	X="in": res.#ObjectProjectionSchema
	out: {
		name: X.name
		if X.items != _|_ {
			items: (#ToK8sKeyToPath & {"in": X.items}).out
		}
		if X.optional != _|_ {
			optional: X.optional
		}
	}
}

// WHY: For secret volumes, from is a #SecretSchema (carrying name, immutable, data).
// The K8s secret name is computed via #ImmutableName, so mutable (stable name)
// and immutable (content-hash suffix) secrets both resolve correctly without
// any extra wiring in the component.
//
// Usage:
//   (#ToK8sVolumes & {"in": _component.spec.volumes, #instancePrefix: "my-instance"}).out

// #ToK8sVolumes converts OPM volumes map to Kubernetes volumes list.
// Handles all volume source types: emptyDir, persistentClaim, configMap, secret.
#ToK8sVolumes: {
	X="in": [string]: res.#VolumeSchema
	_prefix=#instancePrefix?: string

	out: [for vName, vol in X {
		name: vol.name | *vName
		if vol.emptyDir != _|_ {
			emptyDir: {
				if vol.emptyDir.medium != _|_ if vol.emptyDir.medium == "memory" {
					medium: "Memory"
				}
				if vol.emptyDir.sizeLimit != _|_ {
					sizeLimit: vol.emptyDir.sizeLimit
				}
			}
		}
		if vol.persistentClaim != _|_ {
			persistentVolumeClaim: claimName: "\(_prefix)-\(vName)"
		}
		if vol.configMap != _|_ {
			// Compute the same K8s name the configmap-transformer will generate:
			//   {instancePrefix}-{configmap.name}[-{contenthash}]
			// #ImmutableName handles both mutable (stable name) and
			// immutable (content-hash suffix) ConfigMaps transparently.
			// exactName short-circuits both (same branch the transformer takes).
			//
			// Note: `let _cmData` captures concrete field values before the
			// definition boundary — same reason #ImmutableName uses `let _d = data`
			// internally. Without this, CUE loses concrete entries through the
			// open [string]: string pattern.
			let _cmData = vol.configMap.data
			let _k8sName = [
				if vol.configMap.exactName {vol.configMap.name},
				(res.#ImmutableName & {
					baseName:  "\(_prefix)-\(vol.configMap.name)"
					data:      _cmData
					immutable: vol.configMap.immutable
				}).out,
			][0]
			configMap: name: _k8sName
		}

		// External ConfigMap — exact name, module does not own the object.
		if vol.configMapRef != _|_ {
			configMap: {
				name: vol.configMapRef.name
				if vol.configMapRef.items != _|_ {
					items: (#ToK8sKeyToPath & {"in": vol.configMapRef.items}).out
				}
				if vol.configMapRef.defaultMode != _|_ {
					defaultMode: vol.configMapRef.defaultMode
				}
				if vol.configMapRef.optional != _|_ {
					optional: vol.configMapRef.optional
				}
			}
		}

		// External Secret — exact name, module does not own the object.
		if vol.secretRef != _|_ {
			secret: {
				secretName: vol.secretRef.name
				if vol.secretRef.items != _|_ {
					items: (#ToK8sKeyToPath & {"in": vol.secretRef.items}).out
				}
				if vol.secretRef.defaultMode != _|_ {
					defaultMode: vol.secretRef.defaultMode
				}
				if vol.secretRef.optional != _|_ {
					optional: vol.secretRef.optional
				}
			}
		}

		// Projected volume — several sources combined into one directory.
		// Object references inside a projection are always external/exact-name
		// and use `name` (K8s SecretProjection uses `name`, not `secretName`).
		if vol.projected != _|_ {
			projected: {
				if vol.projected.defaultMode != _|_ {
					defaultMode: vol.projected.defaultMode
				}
				sources: [for s in vol.projected.sources {
					if s.serviceAccountToken != _|_ {
						serviceAccountToken: {
							audience: s.serviceAccountToken.audience
							path:     s.serviceAccountToken.path
							if s.serviceAccountToken.expirationSeconds != _|_ {
								expirationSeconds: s.serviceAccountToken.expirationSeconds
							}
						}
					}
					if s.configMap != _|_ {
						configMap: (#ToK8sObjectProjection & {"in": s.configMap}).out
					}
					if s.secret != _|_ {
						secret: (#ToK8sObjectProjection & {"in": s.secret}).out
					}
				}]
			}
		}
		if vol.secret != _|_ {
			secret: {
				// Compute the same K8s name the secret-transformer will generate:
				//   {instancePrefix}-{secret.name}[-{contenthash}]
				// #ImmutableName handles both mutable (stable name) and
				// immutable (content-hash suffix) secrets transparently.
				let _k8sName = (res.#ImmutableName & {
					baseName:  "\(_prefix)-\(vol.secret.from.name)"
					data:      vol.secret.from.data
					immutable: vol.secret.from.immutable
				}).out
				secretName: _k8sName
				if vol.secret.items != _|_ {
					items: (#ToK8sKeyToPath & {"in": vol.secret.items}).out
				}
				if vol.secret.defaultMode != _|_ {
					defaultMode: vol.secret.defaultMode
				}
				if vol.secret.optional != _|_ {
					optional: vol.secret.optional
				}
			}
		}
		if vol.hostPath != _|_ {
			hostPath: {
				path: vol.hostPath.path
				if vol.hostPath.type != _|_ {
					type: vol.hostPath.type
				}
			}
		}
		if vol.nfs != _|_ {
			nfs: {
				server: vol.nfs.server
				path:   vol.nfs.path
				if vol.nfs.readOnly != _|_ {
					readOnly: vol.nfs.readOnly
				}
			}
		}
	}]
}

// Non-immutable secret: K8s name = {prefix}-{secret.name}, no hash suffix.
_testToK8sVolumesSecret: {
	in: {
		auth: {
			name: "auth"
			secret: {
				from: {
					name:      "zot-htpasswd"
					immutable: false
					data: {
						htpasswd: "admin:hashed"
					}
				}
				items: [{
					key:  "htpasswd"
					path: "auth/htpasswd"
					mode: 256
				}]
				defaultMode: 420
			}
		}
	}

	out: (#ToK8sVolumes & {
		"in":            in
		#instancePrefix: "registry"
	}).out

	out: [{
		name: "auth"
		secret: {
			secretName:  "registry-zot-htpasswd"
			defaultMode: 420
			items: [{
				key:  "htpasswd"
				path: "auth/htpasswd"
				mode: 256
			}]
		}
	}]
}

// Immutable secret: K8s name = {prefix}-{secret.name}-{contenthash}.
_testToK8sVolumesSecretImmutable: {
	in: {
		config: {
			name: "config"
			secret: {
				from: {
					name:      "my-config"
					immutable: true
					data: {
						"config.json": "hello"
					}
				}
				items: [{key: "config.json", path: "config.json"}]
			}
		}
	}

	out: (#ToK8sVolumes & {
		"in":            in
		#instancePrefix: "myapp-mycomponent"
	}).out

	out: [{
		name: "config"
		secret: {
			secretName: (res.#ImmutableName & {
				baseName: "myapp-mycomponent-my-config"
				data: {"config.json": "hello"}
				immutable: true
			}).out
			items: [{key: "config.json", path: "config.json"}]
		}
	}]
}

// Exact-name configMap: K8s name = the authored name, no instance prefix and
// no content hash (istiod reads mesh config from the ConfigMap named `istio`).
_testToK8sVolumesConfigMapExactName: {
	in: {
		config: {
			name: "config"
			configMap: {
				name:      "istio"
				exactName: true
				data: mesh: "defaultConfig: {}"
			}
		}
	}

	out: (#ToK8sVolumes & {
		"in":            in
		#instancePrefix: "istio-instance-istiod"
	}).out

	out: [{
		name: "config"
		configMap: name: "istio"
	}]
}

// External/exact-name volume sources + a projected serviceAccountToken.
// Golden values transcribed from the live ztunnel DaemonSet on a running
// ambient mesh (istio 1.28.10): the CA-root ConfigMap is created by istiod at
// runtime, so it can only be referenced by exact name, and the token is
// audience-bound to istio-ca.
_testToK8sVolumesExternalAndProjected: {
	in: {
		"istio-token": {
			name: "istio-token"
			projected: {
				defaultMode: 420
				sources: [{
					serviceAccountToken: {
						audience:          "istio-ca"
						expirationSeconds: 43200
						path:              "istio-token"
					}
				}]
			}
		}
		"istiod-ca-cert": {
			name: "istiod-ca-cert"
			configMapRef: {
				name:        "istio-ca-root-cert"
				defaultMode: 420
			}
		}
		cacerts: {
			name: "cacerts"
			secretRef: {
				name:        "cacerts"
				defaultMode: 420
				optional:    true
			}
		}
	}

	out: (#ToK8sVolumes & {
		"in":            in
		#instancePrefix: "istio-instance-istiod"
	}).out

	// Order follows the authored map's declaration order.
	out: [
		{
			name: "istio-token"
			projected: {
				defaultMode: 420
				sources: [{
					serviceAccountToken: {
						audience:          "istio-ca"
						path:              "istio-token"
						expirationSeconds: 43200
					}
				}]
			}
		},
		{
			name: "istiod-ca-cert"
			configMap: {
				name:        "istio-ca-root-cert"
				defaultMode: 420
			}
		},
		{
			name: "cacerts"
			secret: {
				secretName:  "cacerts"
				defaultMode: 420
				optional:    true
			}
		},
	]
}

// Projected volume combining a token with configMap/secret projections —
// both use `name` (K8s projection types are LocalObjectReference-based) and
// carry no per-source defaultMode.
_testToK8sVolumesProjectedMultiSource: {
	in: {
		bundle: {
			name: "bundle"
			projected: sources: [
				{serviceAccountToken: {audience: "vault", path: "token"}},
				{configMap: {name: "trust-bundle", items: [{key: "ca.crt", path: "ca.crt", mode: 292}]}},
				{secret: {name: "client-cert", optional: true}},
			]
		}
	}

	out: (#ToK8sVolumes & {"in": in}).out

	out: [{
		name: "bundle"
		projected: sources: [
			{serviceAccountToken: {audience: "vault", path: "token"}},
			{configMap: {name: "trust-bundle", items: [{key: "ca.crt", path: "ca.crt", mode: 292}]}},
			{secret: {name: "client-cert", optional: true}},
		]
	}]
}

// Immutable configMap: K8s name = {configmap.name}-{contenthash}.
_testToK8sVolumesConfigMapImmutable: {
	in: {
		config: {
			name: "config"
			configMap: {
				name:      "wolf-config-toml"
				immutable: true
				data: {
					"wolf.toml": "[wolf]\nenabled = true"
				}
			}
		}
	}

	out: (#ToK8sVolumes & {
		"in":            in
		#instancePrefix: "wolf-instance-wolf"
	}).out

	out: [{
		name: "config"
		configMap: name: (res.#ImmutableName & {
			baseName: "wolf-instance-wolf-wolf-config-toml"
			data: {"wolf.toml": "[wolf]\nenabled = true"}
			immutable: true
		}).out
	}]
}

_testToK8sContainer: {
	// Example input container
	in: {
		name: "example-container"
		image: {
			repository: "example-image"
			tag:        "latest"
			digest:     ""
		}
		command: ["/bin/example"]
		args: ["--example-arg"]
		ports: {
			http: {
				name:       "http"
				targetPort: 8080
				protocol:   "TCP"
			}
		}
		env: {
			EXAMPLE_ENV_VAR: {
				name:  "EXAMPLE_ENV_VAR"
				value: "example-value"
			}
		}
		resources: {
			requests: {
				cpu:    "100m"
				memory: "128Mi"
			}
			limits: {
				cpu:    "200m"
				memory: "256Mi"
			}
		}
		volumeMounts: {
			exampleVolumeMount: {
				name:      "example-volume"
				mountPath: "/data/example"
			}
		}
	}

	out: (#ToK8sContainer & {"in": in}).out
}

_testToK8sContainers: {
	// Example list of input containers
	in: [
		{
			name: "example-container-1"
			image: {
				repository: "example-image-1"
				tag:        "latest"
				digest:     ""
			}
		},
		{
			name: "example-container-2"
			image: {
				repository: "example-image-2"
				tag:        "latest"
				digest:     ""
			}
		},
	]

	out: (#ToK8sContainers & {"in": in}).out
}

// Test: preStopCommand produces lifecycle.preStop.exec.command
_testToK8sContainerPreStop: {
	in: {
		name: "graceful"
		image: {
			repository: "app"
			tag:        "v1"
			digest:     ""
		}
		preStopCommand: ["/bin/sh", "-c", "sleep 5"]
	}

	out: (#ToK8sContainer & {"in": in}).out

	out: {
		name:  "graceful"
		image: "app:v1"
		lifecycle: preStop: exec: command: ["/bin/sh", "-c", "sleep 5"]
	}
}
