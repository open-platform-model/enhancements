package core

// S1: both majors define the same FQNs, no providers
s1: #Platform & {
	metadata: name: "s1"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
	}
}
// S2: k8up@v2 built on opm@v4, k8up@v3 built on opm@v5
s2: #Platform & {
	metadata: name: "s2"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
		"opmodel.dev/catalogs/k8up@v2": #catalog: (#provider & {#path: "opmodel.dev/catalogs/k8up@v2", #ver: "2.0.0", #against: [_v4.backup]}).catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: (#provider & {#path: "opmodel.dev/catalogs/k8up@v3", #ver: "3.0.0", #against: [_v5.backup]}).catalog
	}
}
// S3: provider only for v4
s3: #Platform & {
	metadata: name: "s3"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
		"opmodel.dev/catalogs/k8up@v2": #catalog: (#provider & {#path: "opmodel.dev/catalogs/k8up@v2", #ver: "2.0.0", #against: [_v4.backup]}).catalog
	}
}
// S4: two provider majors both built on opm@v4 -> genuinely over-subscribed
s4: #Platform & {
	metadata: name: "s4"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/k8up@v2": #catalog: (#provider & {#path: "opmodel.dev/catalogs/k8up@v2", #ver: "2.0.0", #against: [_v4.backup]}).catalog
		"opmodel.dev/catalogs/k8up@v3": #catalog: (#provider & {#path: "opmodel.dev/catalogs/k8up@v3", #ver: "3.0.0", #against: [_v4.backup]}).catalog
	}
}
// S5: v5 ships a bridge transformer for v4's container
_v5b: #sMember & {
	#cv: "5.0.0"
	catalog: metadata: modulePath: "opmodel.dev/catalogs/opm@v5"
	#extraTransformers: "opmodel.dev/catalogs/opm/transformers/deployment-bridge-transformer@5.0.0": #ComponentTransformer & {
		metadata: {name: "deployment-bridge-transformer", fqn: "opmodel.dev/catalogs/opm/transformers/deployment-bridge-transformer@5.0.0", description: "bridge"}
		requiredLabels: "opm.opmodel.dev/workload-type": "stateless"
		requiredResources: (_v4.container.metadata.fqn): _v4.container
		#transform: output: {}
	}
}
s5: #Platform & {
	metadata: name: "s5"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5b.catalog
	}
}
// S6: ONE provider build serving both majors (two transformers, one per scope)
s6: #Platform & {
	metadata: name: "s6"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
		"opmodel.dev/catalogs/k8up@v4": #catalog: (#provider & {#path: "opmodel.dev/catalogs/k8up@v4", #ver: "4.0.0", #against: [_v4.backup, _v5.backup]}).catalog
	}
}
// S7: identity skew (path @v4, version 5.1.0): scope follows the version major
_skew: #sMember & {#cv: "5.1.0", catalog: metadata: modulePath: "opmodel.dev/catalogs/opm@v4"}
s7: #Platform & {
	metadata: name: "s7"
	type: "kubernetes"
	#registry: "opmodel.dev/catalogs/opm@v4": #catalog: _skew.catalog
}
