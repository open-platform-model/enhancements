package s_sec_w2

import core "x1a.example/s/corev2w2"

#config: {
	// Database password.
	pw: core.#Secret @opm(secret, group=db)
}
