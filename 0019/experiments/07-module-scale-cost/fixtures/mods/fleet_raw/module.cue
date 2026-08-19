// fleet — the BREADTH fixture.
//
// Inspired by (not copied from) a real 2200-line OPM v0 module,
// `mc_java_fleet`: a map of N servers, one workload plus one Service plus one
// ConfigMap per entry, and a single router component whose arguments are a
// comprehension over every server in the map. That last part is why the fixture
// is a fleet rather than N independent modules — growing the map grows one
// component that the other N cannot be evaluated without.
//
// Per-component work is deliberately MODEST here. This fixture answers "what
// does a module with many components cost"; the `complex` fixture answers "what
// does a module with expensive components cost". Keeping the two knobs in
// separate fixtures is what makes either number interpretable.
//
// This file is byte-identical between fleet_bp and fleet_raw except for the
// package clause. Authoring style is expressed entirely in components.cue, and
// metadata is identical in both so that nothing derived from module identity
// can differ between the two rendered outputs.
package fleet_raw

import (
	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

m.#Module

metadata: {
	modulePath:  "testing.opmodel.dev/modules/fleet@v1"
	name:        "fleet"
	version:     "1.0.0"
	description: "Breadth fixture: N stateful servers behind one aggregating router"
}

#config: {
	// Base domain the router routes on.
	domain: string | *"fleet.example.test"

	// The fleet. One entry becomes one component; the router folds over all
	// of them.
	servers: [Name=string]: {
		name:    string | *Name
		enabled: bool | *true

		image: res.#Image & {
			repository: string | *"itzg/minecraft-server"
			tag:        string | *"java21"
			digest:     string | *""
		}

		port:   int & >0 & <=65535 | *25565
		memory: string | *"2Gi"
		motd:   string | *"a server"

		storage: {
			size:         string | *"8Gi"
			storageClass: string | *"standard"
		}

		// Rendered into the server's ConfigMap as a properties file, so the
		// per-server data body is assembled rather than copied.
		settings: [string]: string
	}

	router: {
		image: res.#Image & {
			repository: string | *"itzg/mc-router"
			tag:        string | *"1.32"
			digest:     string | *""
		}
		port:     int & >0 & <=65535 | *25565
		replicas: int | *2
	}
}

debugValues: {
	servers: alpha: {
		settings: {
			"max-players": "20"
			"difficulty":  "normal"
		}
	}
}
