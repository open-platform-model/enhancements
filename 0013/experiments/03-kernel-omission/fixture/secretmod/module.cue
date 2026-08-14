// secretmod — a minimal core@v2 #Module whose #config carries the narrowed
// two-arm #Secret that enhancement 0013 D10 proposes. The disjunction is
// defined LOCALLY in this module: core@v2 still ships the old $-field
// vocabulary, and this experiment measures the kernel build path, not the
// core schema slice. #config is author-defined (`#config: _` in core), so a
// module-local contract type is legal today.
//
// Shape copied from enhancements/0013/schemas/target.cue (#Secret /
// #SecretLiteral / #SecretRef) and testdata/synth/fixture.cue of
// github.com/open-platform-model/library@v1.0.0-alpha.12 (minimal #Module).
package secretmod

import m "opmodel.dev/core@v2"

m.#Module

#Secret:        #SecretLiteral | #SecretRef
#SecretLiteral: {value!: string}
#SecretRef:     {ref!: string, key!: string}

metadata: {
	name:       "secretmod"
	modulePath: "testing.opmodel.dev/modules/secretmod@v0"
	version:    "0.1.0"
}

#components: {}

#config: {
	db: password: #Secret
	tls: cert:    #Secret
}

debugValues: {
	db: password: {value: "debug-only"}
	tls: cert: {value: "debug-cert"}
}
