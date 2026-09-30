package platform

import (
	c "opmodel.dev/core@v2"
	c1 "testing.opmodel.dev/library-render/maj@v1"
)

c.#Platform
metadata: name: "mplat-maj-v1"
type: "kubernetes"
#registry: {
	"testing.opmodel.dev/library-render/maj@v1": {enable: true, #catalog: c1}
}
