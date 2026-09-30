package core

// Case C: shared keys, but only v4 lists the contracts; v5 ships its
// transformer alone. Sidesteps the defined/definedBy conflict of case A to
// show what the demand fold says about two majors' transformers on one key.
_v5TransformersOnly: #Catalog & {
	metadata: {
		modulePath: "opmodel.dev/catalogs/opm@v5"
		version:    "5.0.0"
	}
	#transformers: (_v5.deployment.metadata.fqn): _v5.deployment
}
oneListerBothTransformers: #Platform & {
	metadata: name: "two-majors-one-lister"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5TransformersOnly
	}
}

// Case D: both majors on record, v5 disabled. One major at a time.
oneMajorDisabled: #Platform & {
	metadata: name: "two-majors-one-disabled"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": {enable: false, #catalog: _v5.catalog}
	}
}

// Case E: one build per admitted major, the partition 0026 D9 requires.
perMajorV4: #Platform & {
	metadata: name: "per-major-v4"
	type: "kubernetes"
	#registry: "opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
}
perMajorV5: #Platform & {
	metadata: name: "per-major-v5"
	type: "kubernetes"
	#registry: "opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
}
