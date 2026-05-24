// Three releases pinning different container SemVers. Each component
// declares the FQN(s) it requires; the matcher in match.cue does the lookup.
package match

#Release: {
	name!: #NameType
	components: [Id=#NameType]: {
		requires: [...#FQNType]
	}
}

releases: [Id=#NameType]: #Release & {name: Id}

releases: {
	"app-a": components: api: requires: ["opmodel.dev/modules/opm/container@1.0.4"]
	"app-b": components: api: requires: ["opmodel.dev/modules/opm/container@1.4.0"]
	// App C pins out-of-range — MUST surface as MissingFQN.
	"app-c": components: api: requires: ["opmodel.dev/modules/opm/container@2.0.0"]
}
