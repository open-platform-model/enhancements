// Copied shape: cli/hack/platform/platform.cue. #registry keys are the
// catalogs' own metadata.modulePath (0019 D5 binds them structurally).
package platform

import (
	core "opmodel.dev/core@v2"
	opm "opmodel.dev/catalogs/opm@v4"
	contracts "testing.opmodel.dev/experiments/0015/contracts@v0"
	k8up "testing.opmodel.dev/experiments/0015/k8up@v0"
	velero "testing.opmodel.dev/experiments/0015/velero@v0"
)

core.#Platform
metadata: name: "two-providers"
type: "kubernetes"

#registry: {
	"opmodel.dev/catalogs/opm@v4": #catalog: opm
	"testing.opmodel.dev/experiments/0015/contracts@v0": #catalog: contracts
	"testing.opmodel.dev/experiments/0015/k8up@v0": #catalog: k8up
	"testing.opmodel.dev/experiments/0015/velero@v0": #catalog: velero
}
