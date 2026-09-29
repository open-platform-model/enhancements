package probe

import core "experiment05.local/x/core"

// A module whose #config is a non-struct, with a matching non-struct debugValues.
mod: core.#Module & {
	metadata: {
		name:       "probe"
		modulePath: "example.com/modules/probe@v0"
		version:    "0.1.0"
	}
	#config:     string
	debugValues: "x"
	#components: {}
}

// The instance init would generate: values rendered verbatim from debugValues.
inst: core.#ModuleInstance & {
	metadata: {
		name:      "probe"
		namespace: "default"
	}
	#module: mod
	values:  "x"
}
