package s_sec_w2_deep

import core "x1a.example/s/corev2w2"

#config: {
	tenants: [string]: {
		users: [...{name!: string, password: core.#Secret @opm(secret, group=users)}]
	}
}
