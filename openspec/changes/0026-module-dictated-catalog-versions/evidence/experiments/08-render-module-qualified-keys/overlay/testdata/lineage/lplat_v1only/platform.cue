package platform

import (
	c "opmodel.dev/core@v2"
	c0 "testing.opmodel.dev/library-render/lin@v1"
	c1 "testing.opmodel.dev/library-render/lprov@v0"
)

c.#Platform
metadata: name: "lplat-v1only"
type: "kubernetes"
#registry: {
	"testing.opmodel.dev/library-render/lin@v1": {enable: true, #catalog: c0}
	"testing.opmodel.dev/library-render/lprov@v0": {enable: true, #catalog: c1}
}
