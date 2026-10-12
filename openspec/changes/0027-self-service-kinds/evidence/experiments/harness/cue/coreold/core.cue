// Verbatim copy of core/src/schemas.cue (core 2.0.0-beta.2) #Secret family.
package coreold

#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$"

#Secret: #SecretLiteral | #SecretK8sRef

#SecretType: {
	$opm:          "secret"
	$secretName!:  #NameType
	$dataKey!:     string
	$description?: string
}

#SecretLiteral: {
	#SecretType
	value!: string
}

#SecretK8sRef: {
	#SecretType
	secretName!: string
	remoteKey!:  string
}
