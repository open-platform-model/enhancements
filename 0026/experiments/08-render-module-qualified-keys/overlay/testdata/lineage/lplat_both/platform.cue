package platform

import (
	c "opmodel.dev/core@v2"
	c0 "testing.opmodel.dev/library-render/lin@v0"
	c1 "testing.opmodel.dev/library-render/lin@v1"
	c2 "testing.opmodel.dev/library-render/lprov@v0"
)

c.#Platform
metadata: name: "lplat-both"
type: "kubernetes"
#registry: {
	"testing.opmodel.dev/library-render/lin@v0": {enable: true, #catalog: c0}
	"testing.opmodel.dev/library-render/lin@v1": {enable: true, #catalog: c1}
	"testing.opmodel.dev/library-render/lprov@v0": {enable: true, #catalog: c2}
}
