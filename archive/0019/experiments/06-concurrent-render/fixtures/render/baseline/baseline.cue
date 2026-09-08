// ARM D's one-time build: the platform WITHOUT any instance.
//
// It exists because the baseline arm is the shape this enhancement exists to
// remove: build the platform and its catalog once, hold the value, and fill a
// separately-built instance into it per render. That fill happens in Go
// (arms.go), mirroring library/opm/compile/execute.go, so this package only
// has to expose the transformer map the fill targets.
//
// Same module as ./..., so arm D pays exactly the same resolution and load
// cost for the catalog that the other arms pay. Only the reuse differs.
package baseline

import (
	platform "experiments.opmodel.dev/0019/render-build-cost/platform@v0"
)

transformers: platform.#composedTransformers
