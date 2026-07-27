// A module written the way an author would write it under enhancement 0013.
// Note what is absent: no secret contract type is imported, no $-fields are
// written, and every secret field is typed as the string it is.
package attrtest

import (
	c "opmodel.dev/core@v1"
	frag "example.com/frag@v1"
)

theModule: c.#Module & {
	metadata: {
		modulePath: "example.com/modules"
		name:       "attrtest"
		version:    "0.1.0"
	}

	#config: {
		db: {
			password: string @opm(secret)   // everything derived
			host:     string                // unmarked sibling
		}
		tls: cert: string @opm(secret, group=tls, key="tls.crt", type="kubernetes.io/tls")

		// Marks declared in a different CUE module.
		auth: frag.#BasicAuth

		// Twelve levels — the pyramid this replaces stopped at ten.
		a: b: c: d: e: f: g: h: i: j: k: l: token: string @opm(secret, group=deep)
	}

	#components: {}
}

inst: c.#ModuleInstance & {
	metadata: {
		name:      "myapp"
		namespace: "prod"
	}
	#module: theModule
	values: {
		db: {password: "hunter2", host: "db.internal"}
		tls: cert: "PEMDATA"
		auth: {username: "admin", password: "s3cr3t"}
		a: b: c: d: e: f: g: h: i: j: k: l: token: "tok-123"
	}
}
