package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
	k8scorev1 "opmodel.dev/catalogs/opm/schemas/kubernetes/core/v1"
)

// ServiceTransformer creates Kubernetes Services from components with Expose trait
#ServiceTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "service-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/service-transformer@\(id.Version)"
		description:    "Creates Kubernetes Services for components with Expose trait"

		labels: {
			"core.opmodel.dev/trait-type":    "network"
			"core.opmodel.dev/resource-type": "service"
		}
	}

	requiredLabels: {} // No specific labels required; matches any component with Expose trait

	// Required resources - Container MUST be present to know which ports to expose
	requiredResources: {
		(res.#ContainerResource.metadata.fqn): res.#ContainerResource
	}

	// No optional resources
	optionalResources: {}

	// Required traits - Expose is mandatory for Service creation
	requiredTraits: {
		(tr.#ExposeTrait.metadata.fqn): tr.#ExposeTrait
	}

	// No optional traits
	optionalTraits: {}

	#transform: {
		#component: _ // Unconstrained; validated by matching, not by transform signature
		#context:   c.#TransformerContext

		// Extract required Container resource (will be bottom if not present)
		_container: #component.spec.container

		// Extract required Expose trait (will be bottom if not present)
		_expose: #component.spec.expose

		// Build port list from expose trait ports
		// Schema: targetPort = container port, exposedPort = optional external port
		// K8s Service: port = service port (external), targetPort = pod port
		_ports: [
			for portName, portConfig in _expose.ports {
				{
					name: portName
					// WHY: The list-index form is load-bearing. The obvious spelling,
					// `portConfig.exposedPort | *portConfig.targetPort`, reads as
					// "exposedPort, defaulting to targetPort" but means the
					// opposite: a default arm wins over a concrete one, so
					// `443 | *10250` resolves to 10250 and EVERY exposedPort was
					// silently discarded. Unification-based goldens cannot catch
					// it either — `(443 | *10250) & 443` succeeds — hence the
					// resolution guard in the test data below.

					// Service port: exposedPort when the author set one, else targetPort.
					port: [
						if portConfig.exposedPort != _|_ {portConfig.exposedPort},
						portConfig.targetPort,
					][0]
					targetPort: portConfig.targetPort
					// #PortSchema already defaults protocol to TCP; taking it
					// verbatim is what preserves an author's UDP/SCTP (the same
					// `| *"TCP"` bug forced every Service port back to TCP).
					protocol: portConfig.protocol
					if _expose.type == "NodePort" && portConfig.exposedPort != _|_ {
						nodePort: portConfig.exposedPort
					}
				}
			},
		]

		// Build Service resource
		output: k8scorev1.#Service & {
			apiVersion: "v1"
			kind:       "Service"
			metadata: {
				// WHY: the helper's fallback arm is what keeps a component
				// compiled against a build <= alpha.5 (expose.name?: string,
				// unset) rendering here (0010 D27); alpha.6 dropped it and every
				// older module lost its Services. The StatefulSet and route
				// transformers reference this name through the same helper, so
				// the cross-object references cannot drift.

				// Service name through #ServiceName (name_helpers.cue): expose.name
				// when the component set or defaulted it (0019 D22), else the
				// component's own #names.dns.short. See docs/name-constraints.md.
				name: (#ServiceName & {#comp: #component}).out
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
				// Include component annotations if present
				if len(#context.componentAnnotations) > 0 {
					annotations: #context.componentAnnotations
				}
			}
			spec: {
				type: _expose.type

				// Headless Service when clusterIP is pinned to "None" (no virtual
				// IP; DNS resolves to backing pods). Omitted otherwise so the API
				// server allocates a cluster IP as usual.
				if _expose.clusterIP != _|_ {
					clusterIP: _expose.clusterIP
				}

				selector: #context.componentLabels

				ports: _ports
			}
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// Default naming: Service renders instance-scoped, through the #Expose
// wrapper's default. Transformer fixtures never pass through #Module, so
// #instance is set by hand; without it the default is incomplete and a golden
// would unify vacuously against the type arm (see the resolution guard).
_testServiceDefaultNameComponent: {
	res.#Container
	tr.#Expose

	#instance: {name: "shop", namespace: "apps", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name: "web"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: {
			name: "web"
			image: {
				repository: "nginx"
				tag:        "1.27"
				digest:     ""
			}
			ports: http: {
				name:       "http"
				targetPort: 8080
			}
		}
		expose: {
			type: "ClusterIP"
			ports: http: {
				targetPort:  8080
				exposedPort: 80
			}
		}
	}
}

_testServiceDefaultNameTransformer: (#ServiceTransformer.#transform & {
	#component: _testServiceDefaultNameComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "shop"
			namespace: "apps"
			fqn:       "opmodel.dev/catalogs/opm/shop@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "web"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

_testServiceDefaultNameTransformer: metadata: name: "shop-web"

// Resolution guard: the interpolation collapses the wrapper's default to a
// string before comparison, so a missing or wrong default fails loudly.
_testServiceDefaultNameResolves: "\(_testServiceDefaultNameTransformer.metadata.name)" & "shop-web"

// Exact naming: expose.name renders verbatim. Golden mirrors the live istiod
// Service on an ambient mesh — istiod.<ns>.svc is hard-coded by its webhook
// configs, CA clients, and proxies, so the instance prefix cannot appear.
_testServiceExactNameComponent: {
	res.#Container
	tr.#Expose

	#instance: {name: "istio", namespace: "istio-system", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name: "istiod"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: {
			name: "discovery"
			image: {
				repository: "docker.io/istio/pilot"
				tag:        "1.28.10"
				digest:     ""
			}
			ports: "https-dns": {
				name:       "https-dns"
				targetPort: 15012
			}
		}
		expose: {
			name: "istiod"
			type: "ClusterIP"
			ports: {
				"grpc-xds": {targetPort: 15010}
				"https-dns": {targetPort: 15012}
				"https-webhook": {
					targetPort:  15017
					exposedPort: 443
				}
				"http-monitoring": {targetPort: 15014}
			}
		}
	}
}

_testServiceExactNameTransformer: (#ServiceTransformer.#transform & {
	#component: _testServiceExactNameComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "istio"
			namespace: "istio-system"
			fqn:       "opmodel.dev/catalogs/opm/istio@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "istiod"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// Golden: exact name, and each port keeps its upstream port/targetPort pair.
_testServiceExactNameTransformer: {
	apiVersion: "v1"
	kind:       "Service"
	metadata: {
		name:      "istiod"
		namespace: "istio-system"
	}
	spec: {
		type: "ClusterIP"
		ports: [
			{name: "grpc-xds", port: 15010, targetPort: 15010, protocol: "TCP"},
			{name: "https-dns", port: 15012, targetPort: 15012, protocol: "TCP"},
			{name: "https-webhook", port: 443, targetPort: 15017, protocol: "TCP"},
			{name: "http-monitoring", port: 15014, targetPort: 15014, protocol: "TCP"},
		]
	}
}

// Non-TCP protocol survives to the Service.
_testServiceUDPComponent: {
	res.#Container
	tr.#Expose

	#instance: {name: "coredns", namespace: "kube-system", uuid: "00000000-0000-0000-0000-000000000000"}

	metadata: {
		name: "coredns"
		labels: "core.opmodel.dev/workload-type": "stateless"
	}

	spec: {
		container: {
			name: "coredns"
			image: {
				repository: "registry.k8s.io/coredns/coredns"
				tag:        "v1.13.1"
				digest:     ""
			}
			ports: "dns-udp": {
				name:       "dns-udp"
				targetPort: 5353
				protocol:   "UDP"
			}
		}
		expose: {
			name: "kube-dns"
			type: "ClusterIP"
			ports: "dns-udp": {
				targetPort:  5353
				exposedPort: 53
				protocol:    "UDP"
			}
		}
	}
}

_testServiceUDPTransformer: (#ServiceTransformer.#transform & {
	#component: _testServiceUDPComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "coredns"
			namespace: "kube-system"
			fqn:       "opmodel.dev/catalogs/opm/coredns@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "coredns"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// Resolution guards — deliberately NOT written as a golden.
//
// A golden only unifies, and unification is blind to a wrong default arm:
// `(443 | *15017) & 443` succeeds and reports 443 while the exported value is
// 15017. That is exactly how the `exposedPort | *targetPort` bug survived the
// istiod golden above, which asserts port 443. Worse, the assertion can
// *repair* the value it is meant to check, so a golden on this component would
// be vacuous too.
//
// Arithmetic and string interpolation collapse the disjunction to its default
// before comparison, and neither is invertible — so these two fail loudly if
// the transformer ever regresses to `x | *y`.
_testServiceUDPPortResolves:     (_testServiceUDPTransformer.spec.ports[0].port + 0) & 53
_testServiceUDPProtocolResolves: "\(_testServiceUDPTransformer.spec.ports[0].protocol)" & "UDP"

// Must-fail record for the naming contract (0019 D21, D22, D23), measured on
// cue v0.17.1 against core v2.0.0-alpha.6 with the fixtures above (an
// #instance of prod/media). Each case is deliberately NOT in the package: a
// refusal would fail vet. Observed output is quoted verbatim.
//
//   Leading-digit resourceName on an Expose component (DNS-1035 via Expose):
//     metadata: resourceName: "1web"
//     -> _nameFits: invalid value "1web" (out of bound =~"^[a-z]([a-z0-9-]*[a-z0-9])?$")
//   Dotted resourceName on a raw stateful #Container (D23, key on the entry):
//     metadata: resourceName: "cache.internal"
//     -> _nameFits: invalid value "cache.internal" (out of bound =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")
//   64-rune resourceName on a #StatefulWorkload (blueprint path):
//     -> _nameFits: invalid value "aaaa…" (does not satisfy strings.MaxRunes(63))
//   64-rune resourceName on a #StatelessWorkload with Expose (Service cap):
//     -> _nameFits: invalid value "aaaa…" (does not satisfy strings.MaxRunes(63))
//   Dotted Service name on the trait field:
//     spec: expose: name: "a.b"
//     -> spec.expose.name: conflicting values "prod-web" and "a.b" (and the
//        #ServiceNameType arms refused in the same empty disjunction)
//   #ExposeTrait attached raw, without the #Expose wrapper:
//     -> spec.expose.name: field is required but not present
//        (reported by `cue vet -c`, export and the kernel's render; a bare
//        non-concrete `cue vet` admits an unset required field)
//   Dotted key on a #Namespaces component:
//     spec: namespaces: "a.b": {}
//     -> _namespaceNamesFit.0: invalid value "a.b" (out of bound =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")

// Legacy shape: a component compiled against a build <= alpha.5, whose
// #ExposeSchema carried `name?: string` and whose wrapper set no default. The
// kernel hands #transform the module's own evaluated value, so this is exactly
// what the transformer sees for such a module (0010 D27). Hand-built on purpose:
// embedding the current trait would give `name!` and cannot express "optional
// and unset". #names is set as core would derive it.
_testServiceLegacyExposeComponent: {
	#names: dns: short: "shop-web"
	metadata: name: "web"
	spec: {
		container: {
			name: "web"
			image: {
				repository: "nginx"
				tag:        "1.27"
				digest:     ""
			}
			ports: http: {
				name:       "http"
				targetPort: 8080
			}
		}
		expose: {
			type: "ClusterIP"
			ports: http: {targetPort: 8080, protocol: "TCP"}
			name?: string
		}
	}
}

_testServiceLegacyExposeTransformer: (#ServiceTransformer.#transform & {
	#component: _testServiceLegacyExposeComponent
	#context: {
		#moduleInstanceMetadata: {
			name:      "shop"
			namespace: "apps"
			fqn:       "opmodel.dev/catalogs/opm/shop@0.1.0"
			version:   "0.1.0"
			uuid:      "00000000-0000-0000-0000-000000000000"
		}
		#componentMetadata: name: "web"
		#runtimeName: "opm-test"
		componentAnnotations: {}
	}
}).output

// Resolution guard: the legacy component renders the same instance-scoped
// name the >= alpha.6 wrapper would have defaulted.
_testServiceLegacyExposeResolves: "\(_testServiceLegacyExposeTransformer.metadata.name)" & "shop-web"
