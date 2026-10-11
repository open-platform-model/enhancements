package s_sec_w1

import core "x1a.example/s/corev2"

#config: {
	// Database password.
	pw: core.#Secret @opm(secret, group=db)
}
