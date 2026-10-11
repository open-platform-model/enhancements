package core

// The measured fields, gathered so one `cue export -e report` prints them.
#summary: {
	#p:               _
	definedBy:        #p.#contracts.definedBy
	requiredBy:       #p.#contracts.requiredBy
	collisions:       #p.#contracts.collisions
	collidingEntries: #p.#contracts.collidingEntries
	unfulfilled:      #p.#contracts.unfulfilled
	overSubscribed:   #p.#contracts.overSubscribed
	fulfilled:        #p.#contracts.fulfilled
	routable:         #p.#contracts.routable
	discriminated:    #p.#contracts.discriminated
}

report: {
	caseA: #summary & {#p: twoMajorsShared}
	three: #summary & {#p: threeMajors}
	one: #summary & {#p: oneMajor}
	disabled: #summary & {#p: oneMajorDisabled}
}
