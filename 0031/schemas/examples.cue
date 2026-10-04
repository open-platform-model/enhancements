// Concrete example instances for the target.cue delta: the test.
//
// A jellyfin-shaped card (the shape experiment 02 wrote into twenty real
// modules) passes the card gate; a card with every field at its cap pins the
// size claim of D2; an index of two members and a platform presentation
// block exercise the remaining definitions. Refusals cannot be expressed as
// passing unifications; they are listed at the bottom with the error CUE
// gives for each.
package schema

import (
	"encoding/json"
	"strings"
)

// A real-sized card, as an author writes it in cue.mod/module.cue under
// custom."opmodel.dev@v0".listing.
jellyfinCard: #Listing & {
	schemaVersion: 1
	title:         "Jellyfin"
	summary:       "Free software media server for movies, shows and music"
	category:      "media"
	keywords: ["media-server", "streaming", "transcoding"]
	icon: "assets/icon.svg"
	screenshots: [{path: "assets/library.png", caption: "Library view"}]
	links: [
		{kind: "source", url: "https://github.com/emil-jacero/opm-modules/tree/main/jellyfin"},
		{kind: "issues", url: "https://github.com/emil-jacero/opm-modules/issues"},
	]
	maintainers: [{name: "Emil Larsson", url: "https://github.com/emil-jacero"}]
	vendor:  "emil-jacero"
	license: "Apache-2.0"
}

// The gate as publish applies it.
jellyfinGate: #ListingGate & {listing: jellyfinCard}

// Experiment 02 measured real cards at 471 to 585 bytes.
_assertRealCardSmall: jellyfinGate.size & <600

// A card with every field at its cap. Unicode-free ASCII, so runes equal
// bytes. It must pass the field caps AND the size line: the caps are chosen
// so that no card that passes them fails the size line.
_s: {
	#n:  int
	out: strings.Repeat("a", #n)
}
_url: "https://" + (_s & {#n: 256 - 8}).out
_word: (_s & {#n: 32}).out

maxCard: #Listing & {
	schemaVersion: 1
	title: (_s & {#n: 64}).out
	summary: (_s & {#n: 160}).out
	category: _word
	keywords: [for _ in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] {_word}]
	icon: "assets/" + (_s & {#n: 128 - 11}).out + ".svg"
	screenshots: [for _ in [1, 2, 3, 4] {
		path: "assets/" + (_s & {#n: 128 - 11}).out + ".png"
		caption: (_s & {#n: 120}).out
	}]
	readme: (_s & {#n: 128 - 3}).out + ".md"
	links: [for _ in [1, 2, 3, 4, 5, 6, 7, 8] {kind: "homepage", url: _url}]
	maintainers: [for _ in [1, 2, 3, 4, 5] {
		name: (_s & {#n: 64}).out
		email: (_s & {#n: 32}).out + "@" + (_s & {#n: 31}).out
		url: _url
	}]
	vendor: (_s & {#n: 64}).out
	license: (_s & {#n: 64}).out
	deprecated: {
		message: (_s & {#n: 200}).out
		replacement: (_s & {#n: 250}).out + "@v1"
	}
}

maxGate: #ListingGate & {listing: maxCard}

// Pinned: a card at every cap encodes to this many bytes, under 8192.
_assertMaxCardSize: maxGate.size & 7099
_assertMaxCardFits: len(json.Marshal(maxCard)) & <=#ListingSizeCap

// An index of two members, as an index builder writes it.
fleetIndex: #ListingIndex & {
	schemaVersion: 1
	entries: {
		"jacero.se/modules/jellyfin@v1": {
			version: "1.0.2"
			digest:  "sha256:9e53eda6a7e7e70f3a93cdf2c0816f54e7ca27ada945e7e7e4e162edef3474c4"
			listing: jellyfinCard
		}
		"jacero.se/modules/fileflows@v1": {
			version: "1.0.2"
			digest:  "sha256:fb8311946299f81f639b0dd25cbd13076e30fcdcb7b5a819497037b911bd61e5"
			listing: {
				schemaVersion: 1
				title:         "FileFlows"
				summary:       "Media processing and transcoding automation server"
				category:      "media"
				icon:          "assets/icon.svg"
			}
			thumbnail: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciLz4="
		}
	}
}
_assertIndexSize: len(fleetIndex.entries) & 2

// A platform's presentation of a jellyfin offering.
jellyfinPresentation: #OfferingPresentation & {
	displayName: "Media server"
	summary:     "Acme's approved media server, backed up nightly"
	category:    "media"
	tags: ["approved-for-internal"]
	weight:   10
	featured: true
	presets: [{
		name:  "small"
		title: "Small library"
		values: storage: "50Gi"
	}]
	fields: {
		storage: {title: "Library size", group: "Storage", order: 1}
		"publishedServerUrl": {advanced: true}
	}
}

// Refusals, each run by hand with `cue vet` against the definitions above
// (cue v0.17.1). Recorded, not compiled, because a failing unification
// cannot be part of a passing package.
//
//   #Listing & {schemaVersion: 1, title: "x", summary: "y", category: "media", locales: {}}
//     -> explicit error (_|_ literal) in source (the error names no field; see 07 OQ5)
//   #Listing & {schemaVersion: 1, title: "x", summary: "y", category: "media", icon: "https://example.com/i.svg"}
//     -> icon: invalid value (out of bound =~"^assets/[A-Za-z0-9._/-]+$")
//   #Listing & {schemaVersion: 1, title: "x", summary: "y", category: "Media"}
//     -> category: invalid value (out of bound =~"^[a-z0-9][a-z0-9-]*$")
//   #Listing & {schemaVersion: 2, title: "x", summary: "y", category: "media"}
//     -> schemaVersion: conflicting values 1 and 2
//   #Listing & {title: "x", summary: "y", category: "media"}
//     -> schemaVersion: field is required but not present
//   #Listing & {..., links: [{kind: "homepage", url: "https://" + 300 characters}]}
//     -> links.0.url: invalid value (does not satisfy strings.MaxRunes(256))
//   #ListingGate & {listing: <a card over 8192 bytes>}
//     -> unreachable through #Listing's caps today (maxCard above is 7099
//        bytes). The line exists so a later card version that adds fields
//        cannot outgrow the cap unnoticed. Measured on a 9000-byte struct:
//        size: invalid value 9008 (out of bound <=8192)
