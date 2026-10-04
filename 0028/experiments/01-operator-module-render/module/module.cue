// Package opm_operator is an experiment: the opm-operator's whole install
// (4 CRDs, Namespace, ServiceAccount, 7 ClusterRoles, 2 ClusterRoleBindings,
// leader-election Role + RoleBinding, metrics Service, Deployment) authored
// as an OPM module against opmodel.dev/core@v2 and opmodel.dev/catalogs/opm@v4.
//
//   module.cue               metadata, #config, debugValues
//   components.cue           the components (catalog resources + objects)
//   zz_generated_crds.cue    CRDs, cue-imported from config/crd/bases
//   zz_generated_rbac.cue    ClusterRoles, cue-imported from config/rbac
//
// Every object name is "<instance>-<suffix>" and every namespaced object
// lands in the instance namespace, so an instance named `opm-operator` in
// namespace `opm-operator-system` reproduces the kustomize install's names
// (kustomize namePrefix "opm-operator-" == instance name + "-").
// The module is a cluster singleton: CRD names never carry the instance name.
package opm_operator

import (
	"strings"

	m "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"

	id "testing.opmodel.dev/modules/experiments/opm-operator-render/opm_operator/identity"
)

m.#Module

// Re-declared so components.cue can read the instance name and namespace:
// a field of the embedded #Module is not in lexical scope otherwise.
#ctx: _

metadata: {
	_segments:   strings.Split(strings.SplitN(id.ModulePath, "@", 2)[0], "/")
	name:        _segments[len(_segments)-1]
	modulePath:  id.ModulePath
	version:     id.Version
	description: "The opm-operator: CRDs, RBAC, metrics Service and controller Deployment"
}

#config: {
	// Operator image. The digest default reproduces the beta.5 install.yaml;
	// a released module could only default the tag (the digest exists after
	// the image job, not when the release PR is cut).
	image: res.#Image & {
		repository: string | *"ghcr.io/open-platform-model/opm-operator"
		tag:        string | *"v1.0.0-beta.5"
		digest:     string | *"sha256:cd48321b1ffb17481fc6818c0afa324ce0312bea4af11f36d44f8b91e63b34b1"
	}

	// --registry: the operator's CUE registry mapping
	// (e.g. "testing.opmodel.dev=opm-registry:5000+insecure,registry.cue.works").
	// Unset: the flag is omitted and the operator uses its built-in default.
	registry?: string & !=""

	// --default-service-account: the identity the operator applies as when
	// a ModuleInstance names none. Unset: the flag is omitted.
	defaultServiceAccount?: string & !=""

	// Appended verbatim after every flag above.
	extraArgs: [...string] | *[]

	replicas: int & >=1 | *1

	// GOMEMLIMIT for the Go runtime; keep it ~80% of the memory limit.
	goMemLimit: string | *"3276MiB"

	// cpu as a number of cores: the schema admits the string "2" but the
	// catalog's #NormalizeCPU only converts "<n>m" strings (finding).
	resources: res.#ResourceRequirementsSchema | *{
		requests: {cpu: "100m", memory: "256Mi"}
		limits: {cpu: 2, memory: "4Gi"}
	}
}

// debugValues = the defaults: `opm module build` renders install.yaml's twin.
debugValues: {}
