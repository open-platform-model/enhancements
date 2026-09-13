package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// HttpRouteTransformer creates Gateway API HTTPRoutes from components with HttpRoute and Expose traits.
// Output is an untyped struct literal — no Gateway API schema lives in modules/opm/schemas/,
// and the renderer dispatches on cue.Kind.
#HttpRouteTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "http-route-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/http-route-transformer@\(id.Version)"
		description:    "Creates Gateway API HTTPRoutes for components with HttpRoute and Expose traits"

		labels: {
			"core.opmodel.dev/trait-type":    "network"
			"core.opmodel.dev/resource-type": "http-route"
		}
	}

	requiredLabels: {}
	requiredResources: {}
	optionalResources: {}

	// #ExposeTrait is required: a route without a Service has nothing to point
	// at, so that shape is refused at match time instead of rendering a
	// dangling backendRef.
	requiredTraits: {
		(tr.#HttpRouteTrait.metadata.fqn): tr.#HttpRouteTrait
		(tr.#ExposeTrait.metadata.fqn):    tr.#ExposeTrait
	}
	optionalTraits: {}

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		_httpRoute: #component.spec.httpRoute
		_name:      #component.#names.resourceName
		// The backing Service has one authoritative name field (0019 D22), read
		// through #ServiceName so the reference cannot drift from the Service
		// transformer's output, legacy (<= alpha.5) expose shape included.
		_backendName: (#ServiceName & {#comp: #component}).out

		// TLS hints: Gateway API HTTPRoute has no tls field (TLS lives on the
		// Gateway listener), so surface the trait's tls attachment as
		// annotations downstream controllers can read.
		_tlsAnnotations: {
			if _httpRoute.tls != _|_ {
				if _httpRoute.tls.mode != _|_ {
					"route.opmodel.dev/tls-mode": _httpRoute.tls.mode
				}
				if _httpRoute.tls.certificateRef != _|_ {
					if _httpRoute.tls.certificateRef.namespace != _|_ {
						"route.opmodel.dev/tls-certificate-ref": "\(_httpRoute.tls.certificateRef.namespace)/\(_httpRoute.tls.certificateRef.name)"
					}
					if _httpRoute.tls.certificateRef.namespace == _|_ {
						"route.opmodel.dev/tls-certificate-ref": _httpRoute.tls.certificateRef.name
					}
				}
			}
		}

		_routeAnnotations: {
			if len(#context.componentAnnotations) > 0 {
				#context.componentAnnotations
			}
			_tlsAnnotations
		}

		output: {
			apiVersion: "gateway.networking.k8s.io/v1"
			kind:       "HTTPRoute"
			metadata: {
				name:      _name
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
				if len(_routeAnnotations) > 0 {
					annotations: _routeAnnotations
				}
			}
			spec: {
				if _httpRoute.gatewayRef != _|_ {
					parentRefs: [{
						name: _httpRoute.gatewayRef.name
						if _httpRoute.gatewayRef.namespace != _|_ {
							namespace: _httpRoute.gatewayRef.namespace
						}
					}]
				}

				if _httpRoute.hostnames != _|_ {
					hostnames: _httpRoute.hostnames
				}

				rules: [for rule in _httpRoute.rules {
					backendRefs: [{
						name: _backendName
						port: rule.backendPort
					}]
					if rule.matches != _|_ {
						matches: [for m in rule.matches {
							if m.path != _|_ {
								path: {
									type:  m.path.type
									value: m.path.value
								}
							}
							if m.method != _|_ {
								method: m.method
							}
							if m.headers != _|_ {
								headers: [for h in m.headers {
									name:  h.name
									value: h.value
								}]
							}
						}]
					}
				}]
			}
		}
	}
}

/////////////////////////////////////////////////////////////////
//// Test Data
/////////////////////////////////////////////////////////////////

// Transformer fixtures never pass through #Module, so #instance is set by hand
// on the component stub; without it the resourceName default (and the #Expose
// wrapper's expose.name default) is incomplete and a golden would unify
// vacuously (see docs/name-constraints.md).
_testHttpRouteContext: {
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

_testHttpRouteComponent: {
	res.#Container
	tr.#Expose
	tr.#HttpRoute

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
		httpRoute: {
			gatewayRef: name: "edge"
			rules: [{backendPort: 80}]
		}
	}
}

_testHttpRouteTransformer: (#HttpRouteTransformer.#transform & {
	#component: _testHttpRouteComponent
	#context:   _testHttpRouteContext
}).output

// The route's own name follows the component's resourceName.
_testHttpRouteNameResolves: "\(_testHttpRouteTransformer.metadata.name)" & "shop-web"

// backendRefs must point at the Service the #ServiceTransformer renders for
// the same stub, whatever expose.name resolves to.
_testHttpRouteBackendResolves: "\(_testHttpRouteTransformer.spec.rules[0].backendRefs[0].name)" & "\((#ServiceTransformer.#transform & {
	#component: _testHttpRouteComponent
	#context:   _testHttpRouteContext
}).output.metadata.name)" & "shop-web"

// Legacy shape: a routed component compiled against a build <= alpha.5, whose
// expose carries `name?: string` unset. expose is hand-written on purpose
// (embedding tr.#Expose gives `name!`); container, route and #instance are
// current, their shapes did not move. Covers grpc/tcp/tls too: they read the
// backend name through the same #ServiceName line.
_testHttpRouteLegacyExposeComponent: {
	res.#Container
	tr.#HttpRoute

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
			ports: http: {name: "http", targetPort: 8080, exposedPort: 80, protocol: "TCP"}
			name?: string
		}
		httpRoute: {
			gatewayRef: name: "edge"
			rules: [{backendPort: 80}]
		}
	}
}

_testHttpRouteLegacyExposeTransformer: (#HttpRouteTransformer.#transform & {
	#component: _testHttpRouteLegacyExposeComponent
	#context:   _testHttpRouteContext
}).output

// backendRefs must point at the Service the #ServiceTransformer renders for
// the same legacy stub: the instance-scoped default.
_testHttpRouteLegacyExposeBackendResolves: "\(_testHttpRouteLegacyExposeTransformer.spec.rules[0].backendRefs[0].name)" & "\((#ServiceTransformer.#transform & {
	#component: _testHttpRouteLegacyExposeComponent
	#context:   _testHttpRouteContext
}).output.metadata.name)" & "shop-web"
