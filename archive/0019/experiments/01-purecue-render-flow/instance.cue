// The deployable artifact. This is the authored form a user writes: it names
// the module by import and supplies concrete values. Nothing here is special
// to the experiment: an on-disk instance package in any repo looks like this,
// and it is the shape library/opm/helper/synth.Instance synthesizes.
package render

import (
	c "opmodel.dev/core@v2"
	webapp "experiments.opmodel.dev/0019/purecue-render-flow/web_app"
)

instance: c.#ModuleInstance & {
	metadata: {
		name:      "web-app-demo"
		namespace: "default"
	}

	// The module enters by IMPORT, not by a value copied in from elsewhere.
	// That is what keeps `#config` and `#components` cross-references bound to
	// the scope they were written in; extracting `#components` and re-injecting
	// it into a fresh parent severs them, which is the defect the workspace's
	// module-construction experiment measured and which the kernel's own flow
	// fixture still reproduces.
	#module: webapp

	values: {
		image: {
			repository: "nginx"
			tag:        "1.27"
			digest:     ""
		}
		replicas: 2
		port:     8080
		hostnames: ["web.example.test"]
	}
}
