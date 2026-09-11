// Copied shape: cli/tests/fixtures/modules/podinfo/module.cue. The consumer:
// one stateless workload with a persistent volume that declares the backup
// trait. `backupAdvisory` narrows the trait's posture at the attachment
// site (case D) without a second module.
package webapp

import (
	"strings"

	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	id "testing.opmodel.dev/experiments/0015/webapp/identity"
)

m.#Module
metadata: {
	_segments:   strings.Split(strings.SplitN(id.ModulePath, "@", 2)[0], "/")
	name:        _segments[len(_segments)-1]
	modulePath:  id.ModulePath
	version:     id.Version
	description: "Experiment 0015/01 consumer: a workload with a volume that demands the backup trait"
}

#config: {
	image: res.#Image & {repository: string | *"docker.io/library/nginx", tag: string | *"1.27", digest: string | *""}
	// true narrows the backup trait to optional at the attachment site.
	backupAdvisory: bool | *false
}

debugValues: {
	image: {repository: "docker.io/library/nginx", tag: "1.27", digest: ""}
	backupAdvisory: false
}
