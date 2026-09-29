// A game server whose world needs a quiesce around every capture, in the
// two shapes the design doc recommends: `module` (default; executor:
// module, the module runs the itzg mc-backup restic sidecar and the
// platform projects the policy into it) and `command` (the
// quiesce-tar-release sequence as one command the engine consumes;
// measured for the mechanics, not the cost).
package minecraft

import (
	"strings"

	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	id "testing.opmodel.dev/experiments/0015/exp02/minecraft/identity"
)

m.#Module
metadata: {
	_segments:   strings.Split(strings.SplitN(id.ModulePath, "@", 2)[0], "/")
	name:        _segments[len(_segments)-1]
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/02 consumer: a workload that backs itself up, or demands backup-command"
}

#config: {
	image: res.#Image & {repository: string | *"docker.io/itzg/minecraft-server", tag: string | *"java25", digest: string | *""}
	mode:  *"module" | "command"
}

debugValues: {
	image: {repository: "docker.io/itzg/minecraft-server", tag: "java25", digest: ""}
	mode: "module"
}
