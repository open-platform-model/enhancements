package core

// Case A of experiment 01 (both majors enabled, shared keys), now under the
// collision-tolerant fold.
twoMajorsShared: #Platform & {
	metadata: name: "two-majors-shared-keys"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
	}
}

// Three majors: two shared keys collide across all three, the v3-only
// volume key has one definer and is folded as before.
threeMajors: #Platform & {
	metadata: name: "three-majors"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v3": #catalog: _v3catalog
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": #catalog: _v5.catalog
	}
}

// Control: one major, no collision; the fold behaves as the shipped one.
oneMajor: #Platform & {
	metadata: name: "one-major"
	type: "kubernetes"
	#registry: "opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
}

// Control: the second major on record but disabled.
oneMajorDisabled: #Platform & {
	metadata: name: "one-major-disabled"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": #catalog: _v4.catalog
		"opmodel.dev/catalogs/opm@v5": {enable: false, #catalog: _v5.catalog}
	}
}
