// Core-schema delta for enhancement 0031: Module Presentation Contract.
//
// Delta manifest (vs opmodel.dev/core@v2):
//
//   - #Listing: NEW. The author card a module carries at key `listing` of
//     the 0022 module-file block, custom."opmodel.dev@v0" (D2). Concrete
//     data only, because CUE reads the module file in data mode. Carries
//     its own schemaVersion, independent of the block's @v0 suffix.
//   - #ListingAssetPath, #ListingLabel, #ListingKeyword: NEW. The scalar
//     types the card uses (D2).
//   - #ListingSizeCap: NEW. 8192, the cap on the canonical JSON encoding
//     of a card (D2).
//   - #ListingGate: NEW. The card half of the publish gate: the card
//     validates against #Listing and its canonical encoding stays under
//     the cap. Validated, never asserted: the card is the first value in
//     the block that duplicates nothing (D2).
//   - #ListingThumbnail: NEW. The optional derived icon an index entry may
//     carry (D7).
//   - #ListingIndex, #ListingIndexEntry, #ListingIndexCard: NEW. The data
//     an index module holds (D7). An entry's card is checked against
//     #Listing when its schemaVersion is one this core knows, and copied
//     unjudged when it is newer (D2:R5).
//   - #OfferingPresentation: NEW. The platform's presentation block that
//     the 0027 definition carries as `presentation` (D6). Core has no
//     definition shape yet; 0027's core delta embeds this one.
//
// Not in this delta, on purpose:
//
//   - #ModuleFileCustom stays 0022's. 0022 admits keys it does not define
//     (its open tail), so an older core's gate passes a block that carries
//     a card; this delta adds the card's own gate beside it rather than
//     restating 0022's block.
//   - The hint vocabulary is not core schema: hints are attributes, read
//     by tooling, never unified. It lives in ../contracts/ as data.
//
// The two core types restated below (#ModulePathType, #VersionType) are
// verbatim mirrors of core's, so the delta vets on its own; the real change
// imports them.
//
// Fields gated on an Open Question carry an `// OQN:` marker pointing at
// ../07-questions.md.
package schema

import (
	"encoding/json"
	"list"
	"strings"
)

// Mirrors of core's types; not part of the delta.
#ModulePathType: string & =~"^[a-z0-9._-]+(/[a-z0-9._-]+)*@v[0-9]+$" & strings.MinRunes(1) & strings.MaxRunes(254)
#VersionType:    string & =~"^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?$"

// #ListingAssetPath: a zip-relative path under the module's top-level
// assets/ directory. Never a URL and never a data URI (D2).
// OQ17: what may sit at the path (formats, caps, SVG rules).
#ListingAssetPath: string & =~"^assets/[A-Za-z0-9._/-]+$" & !~"\\.\\." & strings.MaxRunes(128)

// #ListingLabel: one lowercase kebab-case word group, used for the
// category.
#ListingLabel: string & =~"^[a-z0-9][a-z0-9-]*$" & strings.MaxRunes(32)

// #ListingKeyword: a search keyword. Search only, never grouping.
#ListingKeyword: string & =~"^[a-z0-9][a-z0-9-]*$" & strings.MaxRunes(32)

// #ListingHTTPSURL: a link a UI shows and never fetches.
#ListingHTTPSURL: string & =~"^https://" & strings.MaxRunes(256)

// #Listing: the author card.
#Listing: {
	// The card's own version. A breaking card change bumps it, never the
	// block's @v0 suffix.
	schemaVersion!: 1

	// Display name. A module name is snake_case and not a title.
	title!: string & strings.MinRunes(1) & strings.MaxRunes(64) & !~"\n"

	// The card line, plain text.
	summary!: string & strings.MinRunes(1) & strings.MaxRunes(160) & !~"\n"

	// Exactly one, so a grid groups deterministically.
	// OQ2: a closed core enum or a free label; the type narrows if an enum
	// is chosen.
	category!: #ListingLabel

	keywords?: [...#ListingKeyword] & list.MaxItems(10)

	icon?: #ListingAssetPath & =~"\\.(svg|png)$"

	screenshots?: [...{
		path!:    #ListingAssetPath & =~"\\.(png|jpe?g|webp)$"
		caption?: string & strings.MaxRunes(120) & !~"\n"
	}] & list.MaxItems(4)

	// Long description, zip-relative; a UI renders it sanitised on a detail
	// page only. Absent means README.md at the zip root.
	readme?: string & =~"\\.md$" & !~"^/" & !~"\\.\\." & strings.MaxRunes(128)

	links?: [...{
		kind!: "homepage" | "source" | "docs" | "support" | "issues" | "chat"
		url!:  #ListingHTTPSURL
	}] & list.MaxItems(8)

	maintainers?: [...{
		name!:  string & strings.MinRunes(1) & strings.MaxRunes(64)
		email?: string & =~"^[^@ ]+@[^@ ]+$" & strings.MaxRunes(64)
		url?:   #ListingHTTPSURL
	}] & list.MaxItems(5)

	// The organisation behind the module.
	vendor?: string & strings.MaxRunes(64)

	// An SPDX expression, displayed only.
	license?: string & strings.MaxRunes(64)

	// A statement against the author's own interest, so the author may
	// make it.
	deprecated?: {
		message!:     string & strings.MinRunes(1) & strings.MaxRunes(200)
		replacement?: #ModulePathType
	}

	// Reserved for additive localisation and refused when present.
	// OQ5: the locale shape.
	locales?: _|_
}

// #ListingSizeCap: bytes in the canonical JSON encoding of one card.
#ListingSizeCap: 8192

// #ListingGate: what publish unifies a module's card against. The block's
// other keys stay 0022's gate; this gate reads only `listing`.
#ListingGate: {
	// The card as authored, from custom."opmodel.dev@v0".listing.
	listing!: #Listing

	// The size line. It is a separate check from the field caps, so a
	// refusal names the size, not a field. The caps count runes and the
	// line counts bytes, so it can refuse a card within every field cap.
	size: len(json.Marshal(listing)) & <=#ListingSizeCap
}

// #ListingThumbnail: the icon an index builder derives from a member's
// asset, as a data URI. Never authored.
// OQ15: whether the builder rasterises SVG icons to PNG.
// OQ17: an SVG thumbnail is bound by the same SVG and rendering rules.
#ListingThumbnail: string & =~"^data:image/(png|svg\\+xml);base64,[A-Za-z0-9+/]+=*$" & strings.MaxRunes(16384)

// #ListingIndexEntry: one member module on one major, at the newest version
// the builder saw.
#ListingIndexEntry: {
	version!: #VersionType

	// The member's module manifest digest at that version.
	digest!: string & =~"^sha256:[0-9a-f]{64}$"

	// A copy of the member's card at that digest, never edited.
	listing!: #ListingIndexCard

	thumbnail?: #ListingThumbnail
}

// #ListingIndexCard: a member's card as an index carries it. A card at a
// schemaVersion this core knows validates against #Listing; a newer one is
// copied unjudged, so an index built or vetted under an older core does not
// refuse a member that adopted a newer card (D2:R5).
#ListingIndexCard: #Listing | {
	schemaVersion!: int & >1
	...
}

// #ListingIndex: the data an index module's package holds.
// OQ8: whether an index is an artifact kind of its own in 0022's block,
// and which publish path it takes.
#ListingIndex: {
	schemaVersion!: 1

	// Keyed by member module path with major.
	entries!: [#ModulePathType]: #ListingIndexEntry
}

// #OfferingConfigPath: a dotted path into the bound module's #config.
#OfferingConfigPath: string & =~"^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*$"

// #OfferingIcon: a platform icon as a data URI.
// OQ17: checked by the same SVG rules as an author asset, once settled.
#OfferingIcon: string & =~"^data:image/(png|svg\\+xml);base64,[A-Za-z0-9+/]+=*$" & strings.MaxRunes(32768)

// #OfferingPresentation: the platform's presentation of one offering. Every
// field is optional; a field left unset falls through to the author's
// card and hints (D6).
#OfferingPresentation: {
	// Overrides the card's title.
	displayName?: string & strings.MinRunes(1) & strings.MaxRunes(64) & !~"\n"

	// Overrides the card's summary.
	summary?: string & strings.MinRunes(1) & strings.MaxRunes(160) & !~"\n"

	// Markdown shown above the README on a detail page.
	description?: string & strings.MaxRunes(4096)

	// The platform's own taxonomy; defaults to the author's category.
	category?: #ListingLabel

	// Platform filters.
	tags?: [...#ListingLabel] & list.MaxItems(10)

	// Overrides the author's icon.
	icon?: #OfferingIcon

	// Order within a category, higher first.
	weight?: int & >=-1000 & <=1000

	// Pinned at the top of a marketplace.
	featured?: bool

	// Listed by no marketplace. Curation, not access control: the kind
	// keeps serving.
	hidden?: bool

	// Named starting points. Values are checked through the definition's
	// projection at acceptance, which no schema here can express.
	presets?: [...{
		name!:        #ListingLabel
		title!:       string & strings.MinRunes(1) & strings.MaxRunes(64) & !~"\n"
		description?: string & strings.MaxRunes(200)
		values!: {...}
	}] & list.MaxItems(8)

	// Per-field layout overrides. Layout only: no widget, no validation.
	// `hidden` and `advanced` are accepted only on optional or defaulted
	// fields, which only the projection can check.
	fields?: [#OfferingConfigPath]: {
		title?:    string & strings.MinRunes(1) & strings.MaxRunes(64)
		group?:    string & strings.MinRunes(1) & strings.MaxRunes(32)
		order?:    int & >=0 & <=999
		advanced?: bool
		hidden?:   bool
	}
}
