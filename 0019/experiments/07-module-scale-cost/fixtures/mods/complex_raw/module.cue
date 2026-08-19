// complex — the DEPTH fixture.
//
// The counterpart to `fleet`. Where fleet grows the NUMBER of components and
// keeps each one modest, complex keeps the number small and makes each one
// expensive: a runtime disjunction that drives the command, the probes and part
// of the environment; an environment assembled from a base set, a passthrough
// map and a dozen feature-guarded entries; four volumes with four different
// source kinds; an init container and two conditional sidecars; autoscaling and
// a disruption budget; and two ConfigMap entries, one folded from a settings
// map and one marshalled to JSON.
//
// Separating the two knobs is what makes either number mean anything: a single
// "big module" fixture that grew both at once would report a cost with no way
// to attribute it. Run the two at the same component count and the difference
// is per-component complexity; run fleet alone across its sweep and the slope
// is component count.
//
// Byte-identical between complex_bp and complex_raw except for the package
// clause, for the same reason fleet's is: nothing derived from module identity
// may differ between the two rendered outputs.
package complex_raw

import (
	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

m.#Module

metadata: {
	modulePath:  "testing.opmodel.dev/modules/complex@v1"
	name:        "complex"
	version:     "1.0.0"
	description: "Depth fixture: few components, each carrying a deep guarded configuration surface"
}

#config: {
	services: [Name=string]: {
		name: string | *Name

		// Drives the command, the probe shape and part of the environment.
		// A disjunction rather than a free string, so every render walks the
		// arms rather than reading a value.
		runtime: *"java" | "node" | "python" | "go" | "ruby"

		image: res.#Image & {
			repository: string | *"registry.example.test/app"
			tag:        string | *"1.0.0"
			digest:     string | *""
		}

		port:        int & >0 & <=65535 | *8080
		metricsPort: int & >0 & <=65535 | *9090

		cpu:    string | *"500m"
		memory: string | *"1Gi"

		storage: {
			size:         string | *"20Gi"
			storageClass: string | *"standard"
			cacheSize:    string | *"1Gi"
		}

		autoscale: {
			min:       int & >=1 | *2
			max:       int & >=1 | *10
			cpuTarget: int & >=1 & <=100 | *70
		}

		disruption: minAvailable: int | *1

		// Each flag opens a guarded block somewhere in the component: extra
		// env, an extra volume, a sidecar, an extra ConfigMap key.
		features: {
			metrics:   bool | *true
			tracing:   bool | *false
			cache:     bool | *true
			tls:       bool | *false
			profiling: bool | *false
			readOnly:  bool | *true
		}

		// Free-form passthrough, folded into the container environment.
		env: [string]: string

		// Folded into the ConfigMap, twice: once as a properties file and once
		// as JSON.
		settings: [string]: string
	}
}

debugValues: {
	services: api: {
		env: LOG_LEVEL:       "info"
		settings: "pool.max": "32"
	}
}
