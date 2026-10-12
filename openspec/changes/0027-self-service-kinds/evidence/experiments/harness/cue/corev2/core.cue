// 0013 target.cue wave 1: two arms, hidden core tag (0013:D10, D12, D33).
package corev2

import "strings"

#ObjectNameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" & strings.MinRunes(1) & strings.MaxRunes(253)
#SecretKeyType: string & =~"^[-._a-zA-Z0-9]+$" & !~"^\\.$" & !~"^\\.\\." & strings.MaxRunes(253)

#Secret: #SecretLiteral | #SecretRef

#SecretLiteral: {
	_opmSecret: "v2"
	value!:     string
}

#SecretRef: {
	_opmSecret: "v2"
	ref!:       #ObjectNameType
	key!:       #SecretKeyType
}
