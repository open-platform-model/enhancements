package v1beta1

import (
	id "opmodel.dev/catalogs/opm/identity"
	"crypto/sha256"
	"encoding/hex"
	"list"
	"strings"

	c "opmodel.dev/core@v2"
)

/////////////////////////////////////////////////////////////////
//// ConfigMaps Resource
/////////////////////////////////////////////////////////////////

#ConfigMapsResource: c.#Resource & {
	metadata: {
		modulePath:     "\(id.kindPrefix.resources)/v1beta1"
		name:           "config-maps"
		apiVersion:     "v1beta1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.resources)/config-maps@v1beta1"
		description:    "A ConfigMap definition for external configuration"
		labels: {
			"resource.opmodel.dev/category": "config"
		}
	}

	spec: configMaps: [cmName=string]: #ConfigMapSchema & {name: string | *cmName}
}

#ConfigMaps: c.#Component & {
	#resources: (#ConfigMapsResource.metadata.fqn): #ConfigMapsResource
}

/////////////////////////////////////////////////////////////////
//// ConfigMap Schema
/////////////////////////////////////////////////////////////////

// ConfigMap specification.
// `name` is auto-populated from the map key in the resource spec.
#ConfigMapSchema: {
	name!: string
	// Default false so a module that omits `immutable` still renders a
	// concrete value — a bare `bool` leaves the field non-concrete and the
	// instance fails to compile ("incomplete value bool").
	immutable: bool | *false

	// WHY: Exact names are not instance-safe:
	// two instances of the same module in one namespace would collide, so
	// the default stays prefixed.

	// Render `name` verbatim instead of the instance-scoped
	// {instance}-{component}-{name}. Opt-in, and only correct when the name
	// is a contract with something OUTSIDE the module — a controller that
	// reads a well-known ConfigMap (istiod reads mesh config from the
	// ConfigMap literally named `istio`).
	exactName: bool | *false

	// An exact-name ConfigMap cannot also be immutable: immutability appends
	// a content-hash suffix, which is precisely the name instability the
	// external reader cannot tolerate. Setting both is a conflict error
	// rather than a silently-ignored field.
	if exactName {
		immutable: false
	}

	data: [string]: string
}

/////////////////////////////////////////////////////////////////
//// Content Hash Helpers
////
//// Regular fields (not #-prefixed) carry concrete values through
//// unification chains; definition fields lose them when forwarded.
/////////////////////////////////////////////////////////////////

// Deterministic 10-character hex hash of a string data map. Used by
// ConfigMapTransformer.
#ContentHash: {
	data: [string]: string

	let _keys = [for k, _ in data {k}]
	let _sorted = list.SortStrings(_keys)
	let _pairs = [for _, k in _sorted {"\(k)=\(data[k])"}]
	let _concat = strings.Join(_pairs, "\n")

	out: hex.Encode(sha256.Sum256(_concat)[:5])
}

// K8s resource name for a ConfigMap. Appends content-hash suffix when immutable.
// `let _d = data` captures concrete entries — without it CUE only forwards
// the [string]:string pattern.
#ImmutableName: {
	baseName: string
	data: [string]: string
	immutable: bool | *false

	let _d = data
	_hash: (#ContentHash & {data: _d}).out

	if immutable {
		out: "\(baseName)-\(_hash)"
	}
	if !immutable {
		out: baseName
	}
}
