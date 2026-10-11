package core

// Platforms that evaluate under module-qualified keys.

// L1: legacy opm@v4 + module-scoped opm@v5 + one k8up serving both.
lineageL1: #Platform & {
	metadata: name: "l1-legacy-v4-qualified-v5"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog:  _opm4r.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog:  _opm5.catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: _k8up3both
	}
}

// L2: two module-scoped majors, two provider majors, one per definer major.
lineageL2: #Platform & {
	metadata: name: "l2-qualified-v5-v6"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": #catalog:  _opm5.catalog
		"opmodel.dev/catalogs/opm@v6": #catalog:  _opm6.catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: _k8up3on5
		"opmodel.dev/catalogs/k8up@v4": #catalog: _k8up4on6
	}
}

// L3: opm@v6 ships a bridge transformer for opm@v5's container key.
_bridge: #ComponentTransformer & {
	metadata: {name: "deployment-bridge", fqn: "opmodel.dev/catalogs/opm/transformers/deployment-bridge@6.0.0", description: "probe"}
	requiredLabels: "opm.opmodel.dev/workload-type":   "stateless"
	requiredResources: (_opm5.container.metadata.fqn): _opm5.container
	#transform: output: {}
}
_opm6bridge: catalog: _opm6.catalog & {#transformers: (_bridge.metadata.fqn): _bridge}
lineageL3: #Platform & {
	metadata: name: "l3-bridge"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": #catalog: _opm5.catalog
		"opmodel.dev/catalogs/opm@v6": #catalog: _opm6bridge.catalog
	}
}

// L3b: the bridge alone (v5 disabled): v5-built modules keep rendering on v6.
lineageL3b: #Platform & {
	metadata: name: "l3b-bridge-only"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": {enable: false, #catalog: _opm5.catalog}
		"opmodel.dev/catalogs/opm@v6": #catalog: _opm6bridge.catalog
	}
}

// L6: two provider majors on ONE definer major: still over-subscribed.
lineageL6: #Platform & {
	metadata: name: "l6-two-providers-one-definer"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": #catalog:  _opm5.catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: _k8up3on5
		"opmodel.dev/catalogs/k8up@v4": #catalog: _k8up4on5
	}
}
