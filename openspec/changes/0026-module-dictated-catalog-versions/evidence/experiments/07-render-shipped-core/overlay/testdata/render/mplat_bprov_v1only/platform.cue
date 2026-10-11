package platform

import (
	c "opmodel.dev/core@v2"
	c1 "testing.opmodel.dev/library-render/maj@v0"
	c2 "testing.opmodel.dev/library-render/bprov@v0"
	c3 "testing.opmodel.dev/library-render/bprov@v1"
)

c.#Platform
metadata: name: "mplat-bprov-v1only"
type: "kubernetes"
#registry: {
	"testing.opmodel.dev/library-render/maj@v0": {enable: true, #catalog: c1}
	"testing.opmodel.dev/library-render/bprov@v0": {enable: false, #catalog: c2}
	"testing.opmodel.dev/library-render/bprov@v1": {enable: true, #catalog: c3}
}
