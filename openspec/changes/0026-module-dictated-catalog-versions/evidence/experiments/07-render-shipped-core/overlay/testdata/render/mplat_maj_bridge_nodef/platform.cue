package platform

import (
	c "opmodel.dev/core@v2"
	c1 "testing.opmodel.dev/library-render/maj@v0"
	c2 "testing.opmodel.dev/library-render/maj@v1"
)

c.#Platform
metadata: name: "mplat-maj-bridge-nodef"
type: "kubernetes"
#registry: {
	"testing.opmodel.dev/library-render/maj@v0": {enable: true, #catalog: c1}
	"testing.opmodel.dev/library-render/maj@v1": {enable: true, #catalog: c2}
}
