package core

// The measured fields, gathered so one `cue export -e report` prints them.
#summary: {
	#p:             _
	definedBy:      #p.#contracts.definedBy
	requiredBy:     #p.#contracts.requiredBy
	providedBy:     #p.#contracts.providedBy
	unfulfilled:    #p.#contracts.unfulfilled
	overSubscribed: #p.#contracts.overSubscribed
	comparable:     #p.#contracts.comparable
	fulfilled:      #p.#contracts.fulfilled
	routable:       #p.#contracts.routable
	discriminated:  #p.#contracts.discriminated
}

report: {
	scopes: {v4: scopeV4, v5: scopeV5, dev: scopeDev}
	gateAcceptsSharedKey: gateToday.declaredFQN
	S1: #summary & {#p: s1}
	S2: #summary & {#p: s2}
	S3: #summary & {#p: s3}
	S4: #summary & {#p: s4}
	S5: #summary & {#p: s5}
	S6: #summary & {#p: s6}
	S7: #summary & {#p: s7}
}
