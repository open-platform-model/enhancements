package s_sec_w2_collections

import core "x1a.example/s/corev2w2"

#config: {
	extra: [string]: core.#Secret @opm(secret, group=extra)
	certs: [...core.#Secret] @opm(secret, group=certs)
	db: {
		user: string | *"app"
		password: core.#Secret @opm(secret, group=db)
	}
}
