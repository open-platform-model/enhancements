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
	memberKeys: keys
	gate: {
		v5ContainerFQN:   gateV5Container.declaredFQN
		v5MinorSameKey:   gateV5MinorSameKey.declaredFQN
		v5TransformerFQN: gateV5Transformer.declaredFQN
	}
	txgate: {
		ownMajorAndOtherCatalogs:   txOK.offending
		providerRequiringTwoMajors: txProv.offending
	}
	p1: #summary & {#p: P1}
	p2: #summary & {#p: P2}
	p3: #summary & {#p: P3}
	p4: #summary & {#p: P4}
}
