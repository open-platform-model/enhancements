package purecue

import "scratch.example/purecue/cat"

// The glue a plain CUE wrapper writes: transformer arrives by IMPORT from
// another package, instance is local. One build, plain unification.
_inst: #TestInstance

applied: cat.#TestTransformer.#transform & {
	#moduleInstance: _inst
	#component:      _inst.components.web
	#context: {
		#moduleInstanceMetadata: {
			name:      _inst.metadata.name
			namespace: _inst.metadata.namespace
			fqn:       _inst.metadata.fqn
			version:   _inst.#moduleMetadata.version
			uuid:      _inst.metadata.uuid
		}
		#componentMetadata: name: "web"
		#runtimeName: "pure-cue"
	}
}

result: applied.output
