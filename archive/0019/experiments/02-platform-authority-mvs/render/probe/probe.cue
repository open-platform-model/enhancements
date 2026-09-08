// TIER 1 READOUT. Imports ONLY the platform.
//
// This mirrors what a kernel-generated render glue actually imports: the
// instance and the platform. It has no reason to import the catalog directly,
// because the transformers reach it through the platform. That matters more
// than it looks: cue/load resolves an import by first consulting the MAIN
// module's own dependency list (modpkgload/import.go:96, RootSelected) and only
// falls back to the full module graph (where Minimal Version Selection picks
// the maximum across every requirement) for paths the main module does not
// list (import.go:98, mg.Selected). So whether the generated render module
// LISTS the catalog decides which of the two mechanisms answers, and therefore
// decides whether the platform or the consumer wins.
//
// This package stays evaluable when the consumer fails to build under version
// skew, which is why the primary readout lives here rather than in `full`.
package probe

import (
	platform "experiments.opmodel.dev/0019/authority/platform@v0"
)

// What the build resolved for the catalog path, read off the catalog's own
// stamped metadata via the platform. run.sh compares this against the pin it
// wrote into the platform module's cue.mod; nothing here restates a version
// as data.
catalogVersionResolved: platform.#catalogVersionResolved

// The same answer read a second, independent way. A #ComponentTransformer's
// FQN carries the SemVer of the catalog build it shipped in (#ImplFQNType,
// core/src/types.cue), so this key names which transformer BYTES would
// execute, without trusting any metadata field.
transformerFQNSample: [
	for fqn, _ in platform.#composedTransformers if fqn =~ "deployment-transformer" {fqn},
][0]

transformerCount: len([for fqn, _ in platform.#composedTransformers {fqn}])
