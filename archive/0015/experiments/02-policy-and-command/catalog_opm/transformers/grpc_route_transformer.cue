package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// GrpcRouteTransformer creates Gateway API GRPCRoutes from components with GrpcRoute and Expose traits.
// Untyped struct output — see #HttpRouteTransformer for rationale.
#GrpcRouteTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "grpc-route-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/grpc-route-transformer@\(id.Version)"
		description:    "Creates Gateway API GRPCRoutes for components with GrpcRoute and Expose traits"

		labels: {
			"core.opmodel.dev/trait-type":    "network"
			"core.opmodel.dev/resource-type": "grpc-route"
		}
	}

	requiredLabels: {}
	requiredResources: {}
	optionalResources: {}

	// #ExposeTrait is required: a route without a Service has nothing to point
	// at, so that shape is refused at match time instead of rendering a
	// dangling backendRef.
	requiredTraits: {
		(tr.#GrpcRouteTrait.metadata.fqn): tr.#GrpcRouteTrait
		(tr.#ExposeTrait.metadata.fqn):    tr.#ExposeTrait
	}
	optionalTraits: {}

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		_grpcRoute: #component.spec.grpcRoute
		_name:      #component.#names.resourceName
		// The backing Service has one authoritative name field (0019 D22), read
		// through #ServiceName so the reference cannot drift from the Service
		// transformer's output, legacy (<= alpha.5) expose shape included.
		_backendName: (#ServiceName & {#comp: #component}).out

		_tlsAnnotations: {
			if _grpcRoute.tls != _|_ {
				if _grpcRoute.tls.mode != _|_ {
					"route.opmodel.dev/tls-mode": _grpcRoute.tls.mode
				}
				if _grpcRoute.tls.certificateRef != _|_ {
					if _grpcRoute.tls.certificateRef.namespace != _|_ {
						"route.opmodel.dev/tls-certificate-ref": "\(_grpcRoute.tls.certificateRef.namespace)/\(_grpcRoute.tls.certificateRef.name)"
					}
					if _grpcRoute.tls.certificateRef.namespace == _|_ {
						"route.opmodel.dev/tls-certificate-ref": _grpcRoute.tls.certificateRef.name
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
			kind:       "GRPCRoute"
			metadata: {
				name:      _name
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
				if len(_routeAnnotations) > 0 {
					annotations: _routeAnnotations
				}
			}
			spec: {
				if _grpcRoute.gatewayRef != _|_ {
					parentRefs: [{
						name: _grpcRoute.gatewayRef.name
						if _grpcRoute.gatewayRef.namespace != _|_ {
							namespace: _grpcRoute.gatewayRef.namespace
						}
					}]
				}

				if _grpcRoute.hostnames != _|_ {
					hostnames: _grpcRoute.hostnames
				}

				rules: [for rule in _grpcRoute.rules {
					backendRefs: [{
						name: _backendName
						port: rule.backendPort
					}]
					if rule.matches != _|_ {
						matches: [for m in rule.matches {
							if m.service != _|_ || m.method != _|_ {
								method: {
									if m.service != _|_ {
										service: m.service
									}
									if m.method != _|_ {
										method: m.method
									}
								}
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
_testGrpcRouteContext: {
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

_testGrpcRouteComponent: {
	res.#Container
	tr.#Expose
	tr.#GrpcRoute

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
		grpcRoute: {
			gatewayRef: name: "edge"
			rules: [{backendPort: 80}]
		}
	}
}

_testGrpcRouteTransformer: (#GrpcRouteTransformer.#transform & {
	#component: _testGrpcRouteComponent
	#context:   _testGrpcRouteContext
}).output

// The route's own name follows the component's resourceName.
_testGrpcRouteNameResolves: "\(_testGrpcRouteTransformer.metadata.name)" & "shop-web"

// backendRefs must point at the Service the #ServiceTransformer renders for
// the same stub, whatever expose.name resolves to.
_testGrpcRouteBackendResolves: "\(_testGrpcRouteTransformer.spec.rules[0].backendRefs[0].name)" & "\((#ServiceTransformer.#transform & {
	#component: _testGrpcRouteComponent
	#context:   _testGrpcRouteContext
}).output.metadata.name)" & "shop-web"
