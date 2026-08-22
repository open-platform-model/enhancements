// Concrete instances for enhancement 0020's core-schema delta.
//
// Unification IS the test: `cue vet ./...` fails if any instance below stops
// satisfying target.cue. Every NEW and CHANGED definition is exercised.
//
// Negative cases cannot be written as failing unifications in the same
// package — they would fail the vet they are meant to demonstrate. They are
// instead written as assertions over the RANKS the gate compares, so the
// file states "the gate would refuse this" as a checked fact rather than a
// comment.
package schema

// ---------------------------------------------------------------------------
// #LevelRank — the ladder orders as 0010 D34 describes it.
// ---------------------------------------------------------------------------

_rankAlpha1: #LevelRank & {apiVersion: "v1alpha1"}
_rankBeta1:  #LevelRank & {apiVersion: "v1beta1"}
_rankBeta2:  #LevelRank & {apiVersion: "v1beta2"}
_rankGA1:    #LevelRank & {apiVersion: "v1"}
_rankGA2:    #LevelRank & {apiVersion: "v2"}

// alpha < beta1 < beta2 < GA within a major, and a major dominates.
_ladderOrders: true & (
	_rankAlpha1.rank < _rankBeta1.rank &&
	_rankBeta1.rank < _rankBeta2.rank &&
	_rankBeta2.rank < _rankGA1.rank &&
	_rankGA1.rank < _rankGA2.rank)

// The decomposition itself, spelled out once so a reader can see the shape.
_beta2Decomposes: true & (
	_rankBeta2.major == 1 &&
	_rankBeta2.tier == 1 &&
	_rankBeta2.seq == 2)

// A bare vN is GA, which is the case a tier-from-suffix reading gets wrong.
_bareIsGA: true & (_rankGA1.tier == 2 && _rankGA1.seq == 0)

// ---------------------------------------------------------------------------
// #ContractMetadata — D1's promotedFrom, absent and present.
// ---------------------------------------------------------------------------

// A contract born at beta. No promotedFrom: nothing to compare against, and
// 0011 D9's within-level gate is the only one that fires.
ContainerBornAtBeta: #ContractMetadata & {
	name:           "container"
	apiVersion:     "v1beta1"
	catalogVersion: "1.4.0"
	fqn:            "opmodel.dev/catalogs/opm/resources/container@v1beta1"
}

// The same contract after promotion. promotedFrom is what makes D2's
// cross-level comparison fire, and it stays on the member permanently.
ContainerPromotedToGA: #ContractMetadata & {
	name:           "container"
	apiVersion:     "v1"
	catalogVersion: "1.5.0"
	fqn:            "opmodel.dev/catalogs/opm/resources/container@v1"
	promotedFrom:   "v1beta1"
}

// D4's alias: the outgoing level, re-keyed, still shipping in the same build.
// One definition backs both keys, so the two cannot drift; here only the
// metadata differs, which is the part the key is built from.
ContainerAliasAtBeta: #ContractMetadata & {
	name:           "container"
	apiVersion:     "v1beta1"
	catalogVersion: "1.5.0"
	fqn:            "opmodel.dev/catalogs/opm/resources/container@v1beta1"
}

// ---------------------------------------------------------------------------
// #PromotionGate — D1/D2/D5, the half one build can check.
// ---------------------------------------------------------------------------

// Legal: beta to GA.
PromoteBetaToGA: #PromotionGate & {
	name:         "container"
	apiVersion:   "v1"
	promotedFrom: "v1beta1"
}

// Legal: D5 permits skipping a rung. alpha promises nothing, so there is no
// intermediate promise for the skipped rung to protect.
PromoteAlphaToGA: #PromotionGate & {
	name:         "volumes"
	apiVersion:   "v1"
	promotedFrom: "v1alpha1"
}

// Legal: beta to a later beta is upward movement too.
PromoteBetaToBeta: #PromotionGate & {
	name:         "scaling"
	apiVersion:   "v1beta2"
	promotedFrom: "v1beta1"
}

// REFUSED — a downgrade. The ladder has no downward movement, and naming a
// higher origin is how an author would try to express one.
_downgradeIsRefused: true & (
	(#LevelRank & {apiVersion: "v1beta1"}).rank <
	(#LevelRank & {apiVersion: "v1"}).rank)

// REFUSED — promotedFrom naming the member's own level. Not a promotion, and
// under 0011 D9 it would compare a member against itself.
_selfPromotionIsRefused: true & (
	(#LevelRank & {apiVersion: "v1beta1"}).rank ==
	(#LevelRank & {apiVersion: "v1beta1"}).rank)

// ---------------------------------------------------------------------------
// #Tombstone — D6/D9, with and without a successor.
// ---------------------------------------------------------------------------

// The promotion's other end: the origin level retired, pointing at the key
// that replaced it. This is the supersession edge D4 deferred following at
// match time and records as data regardless.
RetiredAfterPromotion: #Tombstone & {
	fqn:        "opmodel.dev/catalogs/opm/resources/container@v1beta1"
	since:      "1.9.0"
	reason:     "promoted to GA; superseded by the v1 contract"
	replacedBy: "opmodel.dev/catalogs/opm/resources/container@v1"
}

// D9's other case: a contract retired as a mistake has no successor, and
// forcing one would make replacedBy's presence meaningless everywhere else.
RetiredAsMistake: #Tombstone & {
	fqn:    "opmodel.dev/catalogs/opm/traits/legacy-probe@v1beta1"
	since:  "1.6.0"
	reason: "superseded in practice by the health trait; never adopted by any published module"
}

// ---------------------------------------------------------------------------
// #CatalogRemoved — D7/D8, the cumulative map on #Catalog.
// ---------------------------------------------------------------------------

// The key stamps itself onto each value, so filing and key cannot drift. The
// map is cumulative: this build carries BOTH records, including the older
// one, because D7 makes the history travel with every build rather than only
// the release that removed something.
CatalogRemovedMap: #CatalogRemoved & {
	#removed: {
		"opmodel.dev/catalogs/opm/traits/legacy-probe@v1beta1": {
			since:  "1.6.0"
			reason: "superseded in practice by the health trait; never adopted by any published module"
		}
		"opmodel.dev/catalogs/opm/resources/container@v1beta1": {
			since:      "1.9.0"
			reason:     "promoted to GA; superseded by the v1 contract"
			replacedBy: "opmodel.dev/catalogs/opm/resources/container@v1"
		}
	}
}

// The stamp is real: neither entry authored its own fqn above, and both
// carry the key.
_keysAreStamped: true & (
	CatalogRemovedMap.#removed["opmodel.dev/catalogs/opm/resources/container@v1beta1"].fqn ==
	"opmodel.dev/catalogs/opm/resources/container@v1beta1")

// ---------------------------------------------------------------------------
// #TombstoneGate — D6/D9/D11.
// ---------------------------------------------------------------------------

TombstoneWithSuccessor: #TombstoneGate & {
	tombstone: RetiredAfterPromotion
}

TombstoneWithoutSuccessor: #TombstoneGate & {
	tombstone: RetiredAsMistake
}

// REFUSED — an alpha member. D11 inherits 0010 D34's carve-out: alpha
// promises nothing, so requiring a record there is ceremony enforcing a
// promise the label denies.
_alphaIsNotTombstoned: true & (
	(#LevelRank & {apiVersion: "v1alpha1"}).tier == 0)
