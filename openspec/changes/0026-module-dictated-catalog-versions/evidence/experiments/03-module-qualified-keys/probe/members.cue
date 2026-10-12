package core

// Members for the module-qualified-key probe. A module-scope catalog major
// keys its contracts under its complete module path,
// "<path>@vN/<kind>/<name>@<apiVersion>"; a registry-scope (legacy) major keeps
// today's "<path>/<kind>/<name>@<apiVersion>". opm@v3 and opm@v4 are legacy,
// opm@v5 and opm@v6 module-scoped. k8up is a provider catalog.

#mk: {
	#path:  string
	#major: string
	#cv:    string
	#scope: *"module" | "registry"
	_kb: [if #scope == "module" {#path + "@" + #major}, #path][0]
	container: #Resource & {
		metadata: {name: "container", apiVersion: "v1beta1", fqn: "\(_kb)/resources/container@v1beta1"}
		matchLabels: "opm.opmodel.dev/workload-type": "stateless"
		spec: container: image: string
	}
	expose: #Trait & {
		metadata: {name: "expose", apiVersion: "v1beta1", fqn: "\(_kb)/traits/expose@v1beta1"}
		appliesTo: [container]
		spec: expose: port: int | *80
	}
	backup: #Trait & {
		metadata: {name: "backup", apiVersion: "v1alpha1", fqn: "\(_kb)/traits/backup@v1alpha1"}
		appliesTo: [container]
		fulfilment: "provider"
		spec: backup: schedule: string
	}
	deployment: #ComponentTransformer & {
		metadata: {name: "deployment-transformer", fqn: "\(#path)/transformers/deployment-transformer@\(#cv)", description: "probe"}
		requiredLabels: "opm.opmodel.dev/workload-type": "stateless"
		requiredResources: (container.metadata.fqn):     container
		optionalTraits: (expose.metadata.fqn):           expose
		#transform: output: {}
	}
	catalog: #Catalog & {
		metadata: {modulePath: "\(#path)@\(#major)", version: #cv}
		#resources: (container.metadata.fqn): container
		#traits: {
			(expose.metadata.fqn): expose
			(backup.metadata.fqn): backup
		}
		#transformers: (deployment.metadata.fqn): deployment
	}
}

_opm3r: #mk & {#path: "opmodel.dev/catalogs/opm", #major: "v3", #cv: "3.1.0", #scope: "registry"}
_opm4r: #mk & {#path: "opmodel.dev/catalogs/opm", #major: "v4", #cv: "4.4.2", #scope: "registry"}
_opm5: #mk & {#path: "opmodel.dev/catalogs/opm", #major: "v5", #cv: "5.0.0"}
_opm6: #mk & {#path: "opmodel.dev/catalogs/opm", #major: "v6", #cv: "6.0.0"}

#sched: {
	#name: string
	#cv:   string

	#on: _ // a #mk
	out: #ComponentTransformer & {
		metadata: {name: #name, fqn: "opmodel.dev/catalogs/k8up/transformers/\(#name)@\(#cv)", description: "probe"}
		requiredTraits: (#on.backup.metadata.fqn): #on.backup
		#transform: output: {}
	}
}

// One provider major serving BOTH definer majors: it imports opm@v4 and
// opm@v5 (two deps of one path) and ships one transformer per key.
_k8up3both: #Catalog & {
	metadata: {modulePath: "opmodel.dev/catalogs/k8up@v3", version: "3.0.0"}
	_a: (#sched & {#name: "schedule-opm-v4", #cv: "3.0.0", #on: _opm4r}).out
	_b: (#sched & {#name: "schedule-opm-v5", #cv: "3.0.0", #on: _opm5}).out
	#transformers: {(_a.metadata.fqn): _a, (_b.metadata.fqn): _b}
}
// Two provider majors, one per definer major.
_k8up3on5: #Catalog & {
	metadata: {modulePath: "opmodel.dev/catalogs/k8up@v3", version: "3.0.0"}
	_a: (#sched & {#name: "schedule", #cv: "3.0.0", #on: _opm5}).out
	#transformers: (_a.metadata.fqn): _a
}
_k8up4on6: #Catalog & {
	metadata: {modulePath: "opmodel.dev/catalogs/k8up@v4", version: "4.0.0"}
	_a: (#sched & {#name: "schedule", #cv: "4.0.0", #on: _opm6}).out
	#transformers: (_a.metadata.fqn): _a
}
_k8up4on5: #Catalog & {
	metadata: {modulePath: "opmodel.dev/catalogs/k8up@v4", version: "4.0.0"}
	_a: (#sched & {#name: "schedule", #cv: "4.0.0", #on: _opm5}).out
	#transformers: (_a.metadata.fqn): _a
}
