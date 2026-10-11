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
	L1: #summary & {#p: lineageL1}
	L2: #summary & {#p: lineageL2}
	L3: #summary & {#p: lineageL3}
	L3b: #summary & {#p: lineageL3b}
	L6: #summary & {#p: lineageL6}
	keys: {
		legacyKeyAccepted:            typeLegacy
		qualifiedKeyAccepted:         typeQualified
		slashMajorIsAValidModulePath: typeSlashMajorIsAModulePath
		qualifiedRef: {
			qualified:       refQualified.qualified
			declaringModule: refQualified.declaringModule
			lineage:         refQualified.lineage
			lineageKey:      refQualified.lineageKey
		}
		legacyRefQualified:        refLegacy.qualified
		gateV5QualifiedFQN:        gateV5Qualified.declaredFQN
		gateV4LegacyFQN:           gateV4Legacy.declaredFQN
		gateV5TransformerFQN:      gateV5Transformer.declaredFQN
		oneMajorPerLineageOK:      mixOK.by
		lineageKeyEqualsLegacyKey: lineageHint
	}
}
