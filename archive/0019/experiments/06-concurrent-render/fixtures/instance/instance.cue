// The deployable artifact, copied from experiments/01-purecue-render-flow and
// made per-render distinct.
//
// __NAME__ is substituted by the harness during setup. It is the ONLY thing
// that differs between the N instance modules in a run: every arm therefore
// renders N genuinely different values against one identical platform, which
// is what stops CUE from answering render i+1 out of render i's evaluation
// state and turning the measurement into a cache reading.
package instance

import (
	c "opmodel.dev/core@v2"
	webapp "experiments.opmodel.dev/0019/render-build-cost/instance/web_app"
)

instance: c.#ModuleInstance & {
	metadata: {
		name:      "__NAME__"
		namespace: "default"
	}

	// The module enters by IMPORT, which is what keeps #config and #components
	// cross-references bound to the scope they were written in. Extracting
	// #components and re-injecting it into a fresh parent severs them; that is
	// the defect 02-design.md's "fixture that has to move first" section
	// describes, and reproducing it here would poison every arm equally.
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
