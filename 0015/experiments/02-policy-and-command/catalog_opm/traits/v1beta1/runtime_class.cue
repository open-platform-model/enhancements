package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

// WHY: The motivating case is GPU workloads on Talos Linux: the
// `nvidia-container-toolkit` system extension registers an `nvidia` containerd
// runtime handler, and the NVIDIA device plugin only sees the GPU when its pod
// runs under it. Upstream installs the plugin with
// `--set=runtimeClassName=nvidia`, and Sidero deliberately does not make
// `nvidia` the node-wide default runtime, so per-pod selection is the
// supported path.
//
// core.#Trait forces the spec key to camelCase(name), so `runtime-class`
// carries `spec.runtimeClass`; each transformer maps it onto the pod's
// `runtimeClassName`, the same way `host-pid`/`hostPid` maps onto `hostPID`.
//
// Lives in the stable catalog rather than the experimental one by necessity:
// transformer matching is purely positive and multiple matches each render, so
// a second workload transformer supplying this field would double-render every
// workload rather than override anything. See
// https://github.com/open-platform-model/enhancements/issues/12.

// Selects the container runtime that executes the pod, by setting
// `runtimeClassName` on the pod spec. The named RuntimeClass object is NOT
// created by this trait — it is cluster-level configuration that must already
// exist, and its `handler` must name a runtime the node's containerd knows.
#RuntimeClassTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1beta1"
		name:           "runtime-class"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/runtime-class@v1beta1"
		description:    "Select the container runtime for the pod (runtimeClassName)"
		labels: {
			"trait.opmodel.dev/category": "runtime"
		}
	}

	// Advisory posture (0010 D46): a workload without this trait still
	// renders; a module may narrow the default at the attachment site.
	optional: bool | *true

	appliesTo: [res.#ContainerResource]

	// Name of an existing cluster RuntimeClass, e.g. "nvidia".
	spec: runtimeClass: string & !=""
}

#RuntimeClass: c.#Component & {
	#traits: (#RuntimeClassTrait.metadata.fqn): #RuntimeClassTrait
}
