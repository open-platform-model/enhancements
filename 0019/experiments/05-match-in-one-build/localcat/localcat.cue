// A tiny SYNTHETIC catalog carrying exactly the members the broken fixtures
// need, one per failure class. Nothing here is published or publishable; the
// fqns live under testing.opmodel.dev so they cannot collide with anything a
// subscribed catalog defines.
//
// The two transformers deliberately embed REAL catalog contracts (ConfigMaps,
// Container) so they enter the same buckets the real transformers occupy —
// each failure class fires inside an otherwise-healthy match, which is what
// makes attribution measurable.
package localcat

import (
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

_path: "testing.opmodel.dev/experiments/0019/match"

// ── broken/missing: a demanded contract with an EMPTY bucket ────────
// No transformer anywhere requires or optionally consumes this resource, so
// its demand is a rung-1 hard miss and a D28 unresolved resource.
#OrphanStoreResource: c.#Resource & {
	metadata: {
		name:           "orphan-store"
		modulePath:     "\(_path)/resources/v1"
		apiVersion:     "v1"
		catalogVersion: "0.0.1"
		fqn:            "\(_path)/resources/orphan-store@v1"
		description:    "A resource no transformer in any subscribed catalog handles"
	}
	spec: orphanStore: {
		size!:      string
		retention?: string
	}
}

// ── broken/unstated: a trait whose declaring catalog states NO posture ──
// core deliberately leaves #Trait.optional as a bare `bool` for the declaring
// catalog to answer with a default (D46). This catalog — wrongly, which is
// the point — does not answer it. Nothing consumes the trait, so an attaching
// component reaches D28's unhandled-trait rule with the posture unstated.
#UnstatedTrait: c.#Trait & {
	metadata: {
		name:           "unstated"
		modulePath:     "\(_path)/traits/v1"
		apiVersion:     "v1"
		catalogVersion: "0.0.1"
		fqn:            "\(_path)/traits/unstated@v1"
		description:    "A trait attached without its declaring catalog stating an optional posture"
	}
	// NO `optional:` line here — that absence is the fixture.
	spec: unstated: {
		note?: string
	}
}

// ── broken/conflict: a required copy that genuinely conflicts ───────
// Requires the real Container contract, NARROWED to a container name the
// component does not run. In the kernel this is the always-unify rung's
// disqualification case (a schema-level divergence, not a value-level one);
// here it must fall out of PLAIN `&`.
#ConflictingTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     "\(_path)/transformers"
		name:           "conflicting-transformer"
		catalogVersion: "0.0.1"
		fqn:            "\(_path)/transformers/conflicting-transformer@0.0.1"
		description:    "Requires Container narrowed to a name the component's copy excludes"
	}
	requiredLabels: {"core.opmodel.dev/workload-type": "stateless"}
	requiredResources: (res.#ContainerResource.metadata.fqn): res.#ContainerResource & {
		spec: container: name: "the-only-name-this-adapter-serves"
	}
	#transform: {
		#component: _
		#context:   c.#TransformerContext
		output: {
			unreachable: true
		}
	}
}

// ── broken/pair, failure style 1: output CONFLICTS at application ───
// Pairs with any ConfigMaps component (same bucket as the real
// configmap-transformer), and its output constrains the component name to a
// value it never has, so the pair's output is an empty disjunction — an
// ERROR, the detectable-as-data failure style.
#BrokenPairTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     "\(_path)/transformers"
		name:           "broken-pair-transformer"
		catalogVersion: "0.0.1"
		fqn:            "\(_path)/transformers/broken-pair-transformer@0.0.1"
		description:    "Output conflicts with its own inputs at application time"
	}
	requiredResources: (res.#ConfigMapsResource.metadata.fqn): res.#ConfigMapsResource
	#transform: {
		#component: _
		#context:   c.#TransformerContext
		output: {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: name: #context.#componentMetadata.name & "never-this-name"
		}
	}
}

// ── broken/pair, failure style 2: output stays INCOMPLETE ───────────
// Same bucket; its output carries a field the transformer never derives and
// nothing fills. Incomplete is NOT bottom (probed), so `== _|_` cannot see
// it — this transformer measures the hole in failure-as-data.
#IncompletePairTransformer: c.#ComponentTransformer & {
	metadata: {
		modulePath:     "\(_path)/transformers"
		name:           "incomplete-pair-transformer"
		catalogVersion: "0.0.1"
		fqn:            "\(_path)/transformers/incomplete-pair-transformer@0.0.1"
		description:    "Output carries a declared field nothing ever fills"
	}
	requiredResources: (res.#ConfigMapsResource.metadata.fqn): res.#ConfigMapsResource
	#transform: {
		#component: _
		#context:   c.#TransformerContext
		output: {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: name: string
		}
	}
}
