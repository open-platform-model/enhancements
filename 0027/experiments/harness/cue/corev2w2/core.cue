// 0013 target.cue wave 2: three arms incl. the open source arm (0013:D18, D29, D31).
package corev2w2

import "strings"

#ObjectNameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" & strings.MinRunes(1) & strings.MaxRunes(253)
#SecretKeyType: string & =~"^[-._a-zA-Z0-9]+$" & !~"^\\.$" & !~"^\\.\\." & strings.MaxRunes(253)
#ContractFQNType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*/[a-z0-9]([a-z0-9-]*[a-z0-9])?@v[0-9]+((alpha|beta)[0-9]+)?$"

#Secret: #SecretLiteral | #SecretRef | #SecretSource

#SecretLiteral: {
	_opmSecret: "v2"
	value!:     string
}

#SecretRef: {
	_opmSecret: "v2"
	ref!:       #ObjectNameType
	key!:       #SecretKeyType
}

#SecretSource: {
	_opmSecret: "v2"
	source!:    #ContractFQNType
	settings?: {...}
	spec?: {...}
}
