package s_sec_w2_optional

import core "x1a.example/s/corev2w2"

#config: {
	pw?: core.#Secret @opm(secret, group=api)
}
