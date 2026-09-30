package core

// ── P1: cutover era. opm@v4 flat (legacy) + opm@v5 major keys; k8up@v2 on v4, k8up@v3 on v5 ──
_k8up2: #mikProvider & {#id: {ModulePath: "opmodel.dev/catalogs/k8up@v2", Version: "2.1.0"}, #against: [_opm4flat]}
_k8up3: #mikProvider & {#id: {ModulePath: "opmodel.dev/catalogs/k8up@v3", Version: "3.0.0"}, #against: [_opm5]}
P1: #Platform & {
	metadata: name: "cutover"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog:  _opm4flat.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog:  _opm5.catalog
		"opmodel.dev/catalogs/k8up@v2": #catalog: _k8up2.catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: _k8up3.catalog
	}
}

// ── P2: steady state. opm@v5 + opm@v6 both major-keyed; ONE k8up entry built against both ──
_k8up4both: #mikProvider & {#id: {ModulePath: "opmodel.dev/catalogs/k8up@v4", Version: "4.0.0"}, #against: [_opm5, _opm6]}
P2: #Platform & {
	metadata: name: "steady"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": #catalog:  _opm5.catalog
		"opmodel.dev/catalogs/opm@v6": #catalog:  _opm6.catalog
		"opmodel.dev/catalogs/k8up@v4": #catalog: _k8up4both.catalog
	}
}

// ── P3: bridge. opm@v6 ships a transformer for opm@v5's container key ──
_bridge: #ComponentTransformer & {
	metadata: {name: "deployment-bridge", fqn: "opmodel.dev/catalogs/opm/v6/transformers/deployment-bridge@6.0.0", description: "probe"}
	requiredLabels: "opm.opmodel.dev/workload-type":   "stateless"
	requiredResources: (_opm5.container.metadata.fqn): _opm5.container
	#transform: output: {}
}
P3: #Platform & {
	metadata: name: "bridge"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": #catalog: _opm5.catalog
		"opmodel.dev/catalogs/opm@v6": #catalog: _opm6.catalog & {#transformers: (_bridge.metadata.fqn): _bridge}
	}
}

// ── P4: provider's OWN major bump, same definer major: k8up@v3 and k8up@v4 both on opm@v5 ──
_k8up4on5: #mikProvider & {#id: {ModulePath: "opmodel.dev/catalogs/k8up@v4", Version: "4.0.0"}, #against: [_opm5]}
P4: #Platform & {
	metadata: name: "provider-swap"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v5": #catalog:  _opm5.catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: _k8up3.catalog
		"opmodel.dev/catalogs/k8up@v4": #catalog: _k8up4on5.catalog
	}
}
