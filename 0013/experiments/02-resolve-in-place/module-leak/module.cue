// The leak case, isolated. This module interpolates a secret into a rendered
// string. It is NOT expected to compile — that is the point of claim 5.
package leak

import c "opmodel.dev/core@v1"

theModule: c.#Module & {
	metadata: {
		modulePath: "example.com/modules"
		name:       "leak"
		version:    "0.1.0"
	}

	#config: db: password: c.#Secret @opm(secret)

	#components: {}

	// A secret cannot be interpolated: #Secret is a struct in BOTH arms, so this
	// is a plain CUE type error at `cue vet`, with no kernel and no OPM tooling
	// in the loop.
	debugValues: db: password: value: "hunter2"
	rendered: "password=\(debugValues.db.password)"
}
