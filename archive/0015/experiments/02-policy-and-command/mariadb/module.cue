// Copied shape: experiment 01 webapp/module.cue. ONE module for both
// engines: a command that streams the dump, plus a landing volume for
// engines that capture files.
package mariadb

import (
	"strings"

	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	id "testing.opmodel.dev/experiments/0015/exp02/mariadb/identity"
)

m.#Module
metadata: {
	_segments:   strings.Split(strings.SplitN(id.ModulePath, "@", 2)[0], "/")
	name:        _segments[len(_segments)-1]
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/02 consumer: a database that demands backup AND backup-command"
}

#config: {
	image: res.#Image & {repository: string | *"docker.io/library/mariadb", tag: string | *"12.3.2", digest: string | *""}
	rootSecretName: string | *"mariadb-root"
}

debugValues: {
	image: {repository: "docker.io/library/mariadb", tag: "12.3.2", digest: ""}
	rootSecretName: "mariadb-root"
}
