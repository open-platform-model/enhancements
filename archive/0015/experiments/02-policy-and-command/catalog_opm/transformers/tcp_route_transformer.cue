package transformers

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
)

// TcpRouteTransformer creates Gateway API TCPRoutes from components with TcpRoute and Expose traits.
// Untyped struct output — see #HttpRouteTransformer for rationale.
#TcpRouteTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     id.kindPrefix.transformers
		name:           "tcp-route-transformer"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.transformers)/tcp-route-transformer@\(id.Version)"
		description:    "Creates Gateway API TCPRoutes for components with TcpRoute and Expose traits"

		labels: {
			"core.opmodel.dev/trait-type":    "network"
			"core.opmodel.dev/resource-type": "tcp-route"
		}
	}

	requiredLabels: {}
	requiredResources: {}
	optionalResources: {}

	// #ExposeTrait is required: a route without a Service has nothing to point
	// at, so that shape is refused at match time instead of rendering a
	// dangling backendRef.
	requiredTraits: {
		(tr.#TcpRouteTrait.metadata.fqn): tr.#TcpRouteTrait
		(tr.#ExposeTrait.metadata.fqn):   tr.#ExposeTrait
	}
	optionalTraits: {}

	#transform: {
		#component: _
		#context:   c.#TransformerContext

		_tcpRoute: #component.spec.tcpRoute
		_name:     #component.#names.resourceName
		// The backing Service has one authoritative name field (0019 D22), read
		// through #ServiceName so the reference cannot drift from the Service
		// transformer's output, legacy (<= alpha.5) expose shape included.
		_backendName: (#ServiceName & {#comp: #component}).out

		_tlsAnnotations: {
			if _tcpRoute.tls != _|_ {
				if _tcpRoute.tls.mode != _|_ {
					"route.opmodel.dev/tls-mode": _tcpRoute.tls.mode
				}
				if _tcpRoute.tls.certificateRef != _|_ {
					if _tcpRoute.tls.certificateRef.namespace != _|_ {
						"route.opmodel.dev/tls-certificate-ref": "\(_tcpRoute.tls.certificateRef.namespace)/\(_tcpRoute.tls.certificateRef.name)"
					}
					if _tcpRoute.tls.certificateRef.namespace == _|_ {
						"route.opmodel.dev/tls-certificate-ref": _tcpRoute.tls.certificateRef.name
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
			apiVersion: "gateway.networking.k8s.io/v1alpha2"
			kind:       "TCPRoute"
			metadata: {
				name:      _name
				namespace: #context.#moduleInstanceMetadata.namespace
				labels:    #context.labels
				if len(_routeAnnotations) > 0 {
					annotations: _routeAnnotations
				}
			}
			spec: {
				if _tcpRoute.gatewayRef != _|_ {
					parentRefs: [{
						name: _tcpRoute.gatewayRef.name
						if _tcpRoute.gatewayRef.namespace != _|_ {
							namespace: _tcpRoute.gatewayRef.namespace
						}
					}]
				}

				rules: [for rule in _tcpRoute.rules {
					backendRefs: [{
						name: _backendName
						port: rule.backendPort
					}]
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
_testTcpRouteContext: {
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

_testTcpRouteComponent: {
	res.#Container
	tr.#Expose
	tr.#TcpRoute

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
		tcpRoute: {
			gatewayRef: name: "edge"
			rules: [{backendPort: 80}]
		}
	}
}

_testTcpRouteTransformer: (#TcpRouteTransformer.#transform & {
	#component: _testTcpRouteComponent
	#context:   _testTcpRouteContext
}).output

// The route's own name follows the component's resourceName.
_testTcpRouteNameResolves: "\(_testTcpRouteTransformer.metadata.name)" & "shop-web"

// backendRefs must point at the Service the #ServiceTransformer renders for
// the same stub, whatever expose.name resolves to.
_testTcpRouteBackendResolves: "\(_testTcpRouteTransformer.spec.rules[0].backendRefs[0].name)" & "\((#ServiceTransformer.#transform & {
	#component: _testTcpRouteComponent
	#context:   _testTcpRouteContext
}).output.metadata.name)" & "shop-web"
