// A module written the way an author would write it under enhancement 0013,
// against the real core schema.
//
// The ROUTING lives in the attribute. The FULFILMENT slot is the field's type.
// The author never states where a secret's data comes from — that is the
// deployer's answer, and it differs per environment (see valuesDev/valuesProd).
package wiring

import c "opmodel.dev/core@v1"

// A minimal resource so the component has a real spec to hang wiring off. A
// production module would use catalog_opm's #Container; this experiment must be
// self-contained, so it declares its own.
#WiringResource: c.#Resource & {
	metadata: {
		modulePath:  "example.com/wiring/resources"
		version:     "1.0.0"
		name:        "wiring"
		description: "Minimal env surface for the resolve-in-place experiment"
	}
	spec: wiring: env: [string]: {
		value?: string
		from?: {ref: string, key: string}
	}
}

theModule: c.#Module & {
	metadata: {
		modulePath: "example.com/modules"
		name:       "wiring"
		version:    "0.1.0"
	}

	#config: {
		db: {
			password: c.#Secret @opm(secret)   // everything derived
			host:     string                   // unmarked sibling
		}
		auth: {
			username: c.#Secret @opm(secret, group=basic-auth, key=username, type="kubernetes.io/basic-auth")
			password: c.#Secret @opm(secret, group=basic-auth, key=password, type="kubernetes.io/basic-auth")
		}
		tls: {
			cert: c.#Secret @opm(secret, group=tls, key="tls.crt", type="kubernetes.io/tls", immutable)
			key:  c.#Secret @opm(secret, group=tls, key="tls.key", type="kubernetes.io/tls", immutable)
		}
	}

	#components: web: {
		metadata: name: "web"
		#resources: (#WiringResource.metadata.fqn): #WiringResource

		// The author's wiring is UNCHANGED from what they write today: a plain
		// reference. Resolution is what makes it carry the object and key.
		spec: wiring: env: {
			DB_PASSWORD: from: #config.db.password
			TLS_KEY: from:     #config.tls.key
			DB_HOST: value:    #config.db.host
		}
	}
}

inst: c.#ModuleInstance & {
	metadata: {
		name:      "myapp"
		namespace: "prod"
	}
	#module: theModule
}

// Two environments, one module. In production the kernel receives values from
// an instance file or a ModuleInstance CR; the experiment holds both here so it
// can build the graph on RESOLVED values rather than on the supplied ones.

// dev: everything supplied inline. No managed certificate exists.
valuesDev: {
	db: {password: {value: "hunter2"}, host: "db.internal"}
	auth: {username: {value: "admin"}, password: {value: "s3cr3t"}}
	tls: {
		cert: value: "-----BEGIN CERTIFICATE-----\nDEV\n-----END CERTIFICATE-----"
		key: value:  "-----BEGIN PRIVATE KEY-----\nDEV\n-----END PRIVATE KEY-----"
	}
}

// prod: the TLS pair points at a wildcard certificate the platform team owns.
valuesProd: {
	db: {password: {value: "hunter2"}, host: "db.internal"}
	auth: {username: {value: "admin"}, password: {value: "s3cr3t"}}
	tls: {
		cert: {ref: "wildcard-example-com", key: "tls.crt"}
		key: {ref:  "wildcard-example-com", key: "tls.key"}
	}
}
