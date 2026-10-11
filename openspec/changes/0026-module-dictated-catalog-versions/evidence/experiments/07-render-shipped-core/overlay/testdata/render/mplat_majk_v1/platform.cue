package platform

import (
	c "opmodel.dev/core@v2"
	c1 "testing.opmodel.dev/library-render/majk@v1"
)

c.#Platform
metadata: name: "mplat-majk-v1"
type: "kubernetes"
#registry: {
	"testing.opmodel.dev/library-render/majk@v1": {enable: true, #catalog: c1}
}
