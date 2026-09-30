package judge

import "list"

#registry: [string]: {enable: bool, resources: [string]: {metadata: catalogVersion: string, spec: _}}

#registry: {
	"x.dev/catalogs/opm@v3": {enable: true, resources: {
		"x.dev/catalogs/opm/resources/container@v1": {metadata: catalogVersion: "3.1.0", spec: {image: string}}
		"x.dev/catalogs/opm/resources/volume@v1": {metadata: catalogVersion: "3.1.0", spec: {size: string}}
	}}
	"x.dev/catalogs/opm@v4": {enable: true, resources: {
		"x.dev/catalogs/opm/resources/container@v1": {metadata: catalogVersion: "4.4.1", spec: {image: string}}
	}}
	"x.dev/catalogs/opm@v5": {enable: true, resources: {
		"x.dev/catalogs/opm@v5/resources/container@v1": {metadata: catalogVersion: "5.0.0", spec: {image: string}}
	}}
}

contracts: {
	_definers: {
		for path, e in #registry if e.enable for fqn, _ in e.resources {(fqn): (path): true}
	}
	defined: {
		for fqn, ds in _definers if len(ds) == 1 for path, _ in ds {(fqn): #registry[path].resources[fqn]}
	}
	definedBy: {
		for fqn, ds in _definers if len(ds) == 1 for path, _ in ds {(fqn): path}
	}
	collisions: list.Sort([for fqn, ds in _definers if len(ds) > 1 {fqn}], list.Ascending)
	collidingEntries: {for fqn, ds in _definers if len(ds) > 1 {(fqn): list.Sort([for p, _ in ds {p}], list.Ascending)}}
	routable: len(collisions) == 0
}
