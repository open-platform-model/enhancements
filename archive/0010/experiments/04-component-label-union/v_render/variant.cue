// Variant 3, render half — whether matchLabels can be folded into rendered
// output behind an opt-in flag defaulting to OFF.
//
// The componentLabels block mirrors core/src/transformer.cue:147-157 as of
// 2026-08-01, including its transformer.opmodel.dev/ exclusion, so the shape
// under test is the real one rather than a simplification.
package v_render

import (
	"strings"

	p "enhancements.opmodel.dev/0010/exp04/prim"
)

#ComponentMeta: {
	name!:        string
	labels?:      p.#LabelsType
	matchLabels?: p.#LabelsType
}

#TransformerContext: {
	#componentMetadata!:      #ComponentMeta
	#moduleInstanceMetadata!: {name!: string}
	#runtimeName!:            string

	// Opt-in, default OFF. Rendered output is unchanged unless a caller asks
	// for the matching labels — the flag exists for "why did this become a
	// StatefulSet", not for steady-state manifests.
	#renderMatchLabels: bool | *false

	componentLabels: {
		"app.kubernetes.io/name":           #componentMetadata.name
		"module-instance.opmodel.dev/name": #moduleInstanceMetadata.name
		if #componentMetadata.labels != _|_ {
			for k, v in #componentMetadata.labels {
				if !strings.HasPrefix(k, "transformer.opmodel.dev/") {
					(k): "\(v)"
				}
			}
		}
		if #renderMatchLabels {
			if #componentMetadata.matchLabels != _|_ {
				for k, v in #componentMetadata.matchLabels {
					(k): "\(v)"
				}
			}
		}
	}
}

_meta: #ComponentMeta & {
	name: "jellyfin"
	labels: "example.opmodel.dev/team": "media"
	matchLabels: {
		"opm.opmodel.dev/workload-type": "stateful"
		"opm.opmodel.dev/tier":          "data"
	}
}

// Default — the flag is not set at all.
outDefault: (#TransformerContext & {
	#componentMetadata:      _meta
	#moduleInstanceMetadata: name: "jellyfin"
	#runtimeName:            "opm-cli"
}).componentLabels

// Explicitly off.
outOff: (#TransformerContext & {
	#componentMetadata:      _meta
	#moduleInstanceMetadata: name: "jellyfin"
	#runtimeName:            "opm-cli"
	#renderMatchLabels:      false
}).componentLabels

// Opted in.
outOn: (#TransformerContext & {
	#componentMetadata:      _meta
	#moduleInstanceMetadata: name: "jellyfin"
	#runtimeName:            "opm-cli"
	#renderMatchLabels:      true
}).componentLabels
