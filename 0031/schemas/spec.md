# Specification changes: Module Presentation Contract

<!--
This document pre-drafts the core/SPEC.md co-update that the core slice
will need at implementation time (the `core-schema-edit` skill gates that
co-update via pre-commit hook + CI). It is required, with examples.cue,
from the draft → accepted gate.

One section per NEW or CHANGED construct, in core SPEC.md's four-part
format. For a CHANGED construct, frame each part as a delta against the
current section ("changes vs SPEC.md §N.M"); for a NEW construct, write
the full section draft ready to lift into core/SPEC.md.
-->

All four constructs are NEW. They sit beside the module-file block that entry 0022 adds, in the same part of SPEC.md: the block is the carrier, and these define one key in it, the gate that checks that key, the index that copies it, and the platform's override of it.

## `#Listing` (NEW)

### Definition

The author card: an optional struct a module carries at key `listing` inside its module-file block, `custom."opmodel.dev@v0"` in `cue.mod/module.cue`. It is what any UI shows to list and present the module without downloading the module zip or evaluating CUE. It is author-supplied, so it is validated rather than asserted, and it carries its own `schemaVersion`, independent of the block's `@v0` suffix.

### Shape

```cue
#Listing: {
	schemaVersion!: 1
	title!:         string            // 1-64 runes, one line
	summary!:       string            // 1-160 runes, one line
	category!:      #ListingLabel     // OQ2: enum or label
	keywords?:      [...#ListingKeyword]   // <= 10
	icon?:          #ListingAssetPath      // .svg or .png
	screenshots?:   [...{path!, caption?}] // <= 4
	readme?:        string                 // zip-relative .md
	links?:         [...{kind!, url!}]     // <= 8, https, <= 256 runes
	maintainers?:   [...{name!, email?, url?}] // <= 5
	vendor?:        string
	license?:       string
	deprecated?:    {message!, replacement?}
	locales?:       _|_               // reserved
}
```

The full surface, with every cap, is `target.cue`.

### Constraints

- Every value MUST be concrete. CUE reads the module file in data mode, and tidy canonicalises it (keys sorted, comments dropped), so no meaning MAY depend on key order or comments.
- `schemaVersion`, `title`, `summary` and `category` MUST be present.
- An image MUST be named by a path under `assets/` in the module zip. A URL, a data URI or image bytes MUST NOT appear in a card. What may sit at that path is 0031:OQ17.
- `locales` MUST NOT be present. The name is reserved for localisation.
- A reader MUST ignore a card it does not understand, and MUST show the fields it knows of a card whose `schemaVersion` is newer than it knows. A reader MUST NOT refuse a module for its card.
- A module without a card MUST be valid exactly as it is without this construct.

### Rationale

- **Why the module file.** It is the one part of a published module that is small, fetched without the zip, and readable without CUE evaluation, so listing N modules costs N small fetches.
- **Why a version of its own.** The block's `@v0` suffix versions the block's shape; a card change that breaks readers must not force the whole block to a new key.
- **Why paths and not URLs.** A URL breaks on an air-gapped or sovereign platform and can change after release; a path inside the immutable zip cannot.
- **Why `locales` is reserved.** Adding a localisation map later is additive only if no card has used the name for something else.

## `#ListingGate` (NEW)

### Definition

The card half of the publish gate. Publish unifies a module's card with `#ListingGate.listing`; the card's field caps and its total size are checked there. It runs beside 0022's block gate and reads only the `listing` key.

### Shape

```cue
#ListingSizeCap: 8192

#ListingGate: {
	listing!: #Listing
	size:     len(json.Marshal(listing)) & <=#ListingSizeCap
}
```

### Constraints

- Publish MUST refuse a module whose card fails `#Listing`, naming the field.
- Publish MUST refuse a module whose card's canonical JSON encoding exceeds 8192 bytes, naming the size.
- Publish MUST NOT edit the card.
- The size line MAY refuse a card that passes every field cap: the caps count runes and the line counts bytes. `examples.cue` pins an ASCII card at every cap at 7099 bytes and records a CJK card at every cap refused at 13641. Whether the caps count bytes instead is 0031:OQ18.

### Rationale

- **Why validated and not asserted.** 0022's gate asserts values the module file already implies. A card implies nothing, so the only honest check is validation.
- **Why a separate size line.** The field caps alone measured 8486 bytes at every cap with 512-rune links. Lowering links to 256 runes brings an ASCII card under the cap, but rune caps never bound bytes, so the line is the card's only byte bound.
- **Why a cap at all.** Every consumer of a module re-fetches the module file on every dependency resolve.

## `#ListingIndex` and `#ListingIndexEntry` (NEW)

### Definition

The data an index module holds: a CUE module whose package lists, per member module path with major, the newest version on that major, its module manifest digest, a verbatim copy of its card, and optionally a derived icon thumbnail. The first-party index lives at the reserved path `opmodel.dev/modules/index`; any other publisher's index lives at any path its publisher chooses.

### Shape

```cue
#ListingIndex: {
	schemaVersion!: 1
	entries!: [#ModulePathType]: #ListingIndexEntry
}

#ListingIndexEntry: {
	version!:   #VersionType
	digest!:    string             // sha256:<64 hex>
	listing!:   #ListingIndexCard  // #Listing, or a newer card unjudged
	thumbnail?: #ListingThumbnail  // data URI, <= 16 KiB
}
```

### Constraints

- An entry's `listing` MUST equal the card in the member's module file at `digest`, and `digest` MUST be the member's manifest digest at `version`.
- An index MUST NOT carry data its members do not: it is a snapshot, never an edit point.
- An entry's card MUST validate against `#Listing` when its `schemaVersion` is one the core knows, and MUST be copied unjudged when it is newer, so an index built under an older core never refuses a member for adopting a newer card.
- `thumbnail` MUST be derived from the member's `icon` asset, never authored.
- A reader MUST treat an index as a hint. It MUST check each member's tags for a newer version on the same major, and MUST mark an entry it cannot fetch (for example on a partial mirror) instead of failing the whole index.

### Rationale

- **Why a CUE module.** It is published, resolved and mirrored by the same tooling as its members, on every registry, with no registry extension.
- **Why the card is copied whole.** A list view then needs one fetch, and the publish check that every copy equals its source keeps the copy honest.
- **Why thumbnails are optional.** Measured on a 20-module fleet, thumbnails grew the published index zip 3.7 times and forced the builder to fetch every member zip.

## `#OfferingPresentation` (NEW)

### Definition

The platform's presentation of one offering, carried by the platform-owned definition of entry 0027 as its `presentation` field. Every field is optional and overrides the author's card or hints field by field; a field left unset falls through to the author. It is inert: it changes what a UI shows and nothing else.

### Shape

```cue
#OfferingPresentation: {
	displayName?: string    // overrides title
	summary?:     string    // overrides summary
	description?: string    // markdown, <= 4096 runes
	category?:    #ListingLabel
	tags?:        [...#ListingLabel]   // <= 10
	icon?:        #OfferingIcon        // data URI, <= 32 KiB
	weight?:      int
	featured?:    bool
	hidden?:      bool
	presets?:     [...{name!, title!, description?, values!}]   // <= 8
	fields?:      [#OfferingConfigPath]: {title?, group?, order?, advanced?, hidden?}
}
```

### Constraints

- A UI MUST show a set presentation field instead of the author's value, and MUST fall through to the author's value for an unset one.
- A change to presentation MUST NOT re-render, rebind or otherwise change an instance, and MUST NOT change the served schema.
- A definition MUST be refused at acceptance when a preset's values, unified with the definition's bound values through the 0027 projection, would be refused, naming the preset.
- `fields` MUST change layout only. It MUST NOT change a widget or any validation, and `hidden` or `advanced` MUST NOT be set on a required field.
- A `hidden` offering MUST NOT be listed by any marketplace, and its kind MUST keep serving.
- `icon` MUST pass the same SVG rules as an author's asset, once 0031:OQ17 settles them.

### Rationale

- **Why on the definition.** It is the one layer a platform can change without a module release, which is what "the logo is wrong today" needs.
- **Why inert.** A presentation edit that could re-render would make a label change an operational event.
- **Why presets are checked through the projection.** The served structural schema is a lossy subset of `#config`, so a preset that passes it can still fail every order made from it.
- **Why disagreement with the author is not reported.** Overriding the author is the purpose of the block, not drift.
