// Registry-resolved instance of the experiment fixture. Copied from
// cli/tests/e2e/testdata/operator-owned/instance.cue (2026-10-04): the module
// is imported from the registry (no local-module.cue), so the CLI records a
// registry-resolvable spec.module and no source: local annotation.
package c6

import (
	core "opmodel.dev/core@v2"
	multi "testing.opmodel.dev/modules/experiments/handoff-id/multi@v0"
)

core.#ModuleInstance

metadata: {
	name:      "multi"
	namespace: "c6"
}

#module: multi

values: {
	image: {repository: "ghcr.io/stefanprodan/podinfo", tag: "6.7.1", digest: ""}
	replicas: 1
	extra:    true
	message:  "hello from multi"
	readerName: "multi-reader-c6"
	note:       ""
}
