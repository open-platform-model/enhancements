package s_sec_old

import core "x1a.example/s/coreold"

#config: {
	pw: core.#Secret & {$secretName: "db", $dataKey: "password"}
}
