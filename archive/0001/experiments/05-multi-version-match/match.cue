// Pure-CUE matcher: for each release, walk its components and look up each
// required FQN in `composed`. Found → matched; missing → MissingFQN with
// adjacent-SemVer hint computed by prefix-matching composed keys.
package match

import "strings"

// `_primPrefix(fqn)` returns the modulePath/name portion of an FQN — the
// substring before "@". Used to compute alternatives within the same primitive.
_primPrefix: {
	fqn: string
	out: strings.SplitN(fqn, "@", 2)[0]
}

// Matched lookups, per release per component.
matched: {
	for relId, rel in releases {
		(relId): {
			for compId, comp in rel.components {
				(compId): [
					for fqn in comp.requires
					if composed[fqn] != _|_ {composed[fqn].metadata.fqn},
				]
			}
		}
	}
}

// Missing FQNs with adjacent-SemVer alternatives.
missing: [...#MissingFQN]
missing: [
	for relId, rel in releases
	for compId, comp in rel.components
	for fqn in comp.requires
	if composed[fqn] == _|_ {
		let prefix = (_primPrefix & {"fqn": fqn}).out
		{
			release:   relId
			component: compId
			"fqn":     fqn
			alternatives: [
				for k, _ in composed
				if strings.HasPrefix(k, prefix+"@") {k},
			]
		}
	},
]
