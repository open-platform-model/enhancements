# Design: Module Presentation Contract

The design answers one question: what must a module author and a platform declare so that any UI can list and present a module, and a platform's offering of it, without kind-specific code? The answer is three authored layers and one derived listing, each owned by one party and each read by a reader who can afford it.

## Design Goals

- A UI can show a module's title, summary, category, icon and links from the module file alone, without the zip and without CUE evaluation.
- A UI can lay out a form for any module's `#config` from published data alone: labels, groups, order, widgets, advanced and hidden fields, and help text.
- A platform team can change what its users see for an offering without a module release, and that change touches nothing but presentation.
- A UI can list a publisher's modules in a few requests, on any registry, mirrored or air-gapped.
- Every layer is additive: a module, a reader or a gate that predates a layer keeps working.
- No layer is a second source of truth for a constraint: a hint never changes which values `#config` accepts.

## Non-Goals

- **The served kind's schema.** How `#config` becomes a structural CRD schema, how `#Secret` fields and unions are encoded, and whether defaulted fields are required belong to entry 0027 (0027:OQ18 to 0027:OQ22). This entry consumes the answer.
- **The order flow.** What a UI may create for a tenant, under which identity, with which prefill and how errors are reported are 0027's questions (0027:OQ24 to 0027:OQ29).
- **A portal.** The opm-portal is one reader of this contract, not part of it.
- **A package format, a central registry or a central marketplace.** The module stays the only artifact; the index is a module too.
- **Localisation and badges.** Both are reserved or open (OQ5, OQ6), not designed here.

## High-Level Approach

Three authored layers and one derived listing (D1):

```text
 module author (in the release)        platform team (in the cluster)
 ------------------------------        ------------------------------
 author card   -> module file block    presentation -> 0027 definition
 images        -> assets/ in the zip      (overrides field by field,
 field hints   -> @opm(ui, ...) on        inert, presets checked
                  #config fields           through the projection)
 help text     -> doc comments
                 \                          /
                  \                        /
 publisher CI:  index module  ---->  readers: marketplace, admin browser,
 (a copy of every member's card)     CLI preview, MCP, Headlamp, Backstage
```

**Merge order for anything a user sees:** the platform's presentation wins field by field, then the author's card and hints, then what a reader derives from the schema (a label from a field name, a widget from a type).

1. **The author card (D2)** is an optional struct at key `listing` in 0022's module-file block. It is concrete data with its own `schemaVersion`, field caps, and a separate 8 KiB size line. Publish validates it and never edits it.
2. **Images (D3)** are files under `assets/` in the module zip, named by path from the card. The manifest keeps two layers. Publish refuses scripted SVG, and every OPM UI renders module images so that none can run.
3. **Field hints (D4)** are `@opm(ui, key=value, ...)` attributes on `#config` fields, from a closed vocabulary of nine keys at version 1 (`contracts/hints.cue`). A field may carry several `@opm` attributes, and readers dispatch on position 0 of every one, which amends 0013:D2.
4. **Help text (D5)** is the field's doc comment: the module author's first, then the catalog type's, and core's never. Hints a catalog type carries reach every field typed by it, because readers follow the field's references to the type.
5. **Platform curation (D6)** is `presentation` on the 0027 definition: display name, summary, description, category, tags, icon, weight, featured, hidden, presets and per-field layout. It overrides the author field by field and is inert.
6. **The index (D7)** is a CUE module at the reserved path `opmodel.dev/modules/index` for the first-party fleet. Any other publisher's index is read only when a reader is configured with its path. It is a snapshot and a hint: readers check each member's tags for newer releases.

## Schema / API Surface

The core-schema delta is in `schemas/target.cue`, specified in `schemas/spec.md` and exercised by `schemas/examples.cue`:

- `#Listing`: the author card. Required `schemaVersion`, `title`, `summary`, `category`; optional `keywords`, `icon`, `screenshots`, `readme`, `links`, `maintainers`, `vendor`, `license`, `deprecated`; `locales` reserved and refused.
- `#ListingGate`: the card half of the publish gate, with the size line `len(json.Marshal(listing)) <= 8192`.
- `#ListingIndex` and `#ListingIndexEntry`: the index module's data.
- `#OfferingPresentation`: the block 0027's definition carries as `presentation`.

The hint vocabulary is not core schema, because hints are read by tooling and never unified. It is a taxonomy in `contracts/hints.cue`: nine keys (`title`, `group`, `order`, `widget`, `advanced`, `hidden`, `placeholder`, `options`, `discriminator`), the widgets each field shape allows, the names deliberately left out, and the attribute forms the gate refuses.

A hint on a field reads like this:

```cue
#config: {
	// Size of the media library volume.
	//
	// Grows with the library; shrinking a PVC is not supported.
	storage: string | *"100Gi" @opm(ui, title="Library size", group="Storage", order=1, widget=quantity)

	apiToken?: #Secret @opm(secret, group=api) @opm(ui, group="Security", advanced)
}
```

## Affected Surfaces

- **core.** Ships `#Listing`, `#ListingGate`, `#ListingIndex` and `#OfferingPresentation`. A module carrying a card is accepted by a core that predates the card schema, through 0022's open block tail.
- **library.** A reader of a field's hints considers every `@opm` attribute on it and dispatches on position 0, and follows a field's references to collect the hints and doc comments of the catalog type it is typed by. It reports where each comment and hint came from (the module or a dependency), so no consumer has to guess from file paths.
- **cli.** Publish and vet refuse an invalid card, a card over the size line, a missing or oversized asset, a scripted SVG, and a malformed hint on the module's own fields; they warn on an inherited hint finding. The CLI builds and publishes an index for a publisher who asks for one.
- **opm-operator.** Accepts `presentation` on the 0027 definition, refuses a definition whose preset its projection refuses, and never re-renders an instance for a presentation change.
- **catalog.** Catalog types may carry default hints (for example a whole-field `image` widget on the image type) that every module field typed by them inherits.
- **modules.** The first-party fleet gains cards, icons and hints, and publishes the first-party index at its reserved path.
- **opmodel.dev.** Documents the card, the vocabulary and the index for authors and tool builders.
- **opm-portal.** Reads all of it: the card and index to list, the hints and doc comments to lay out forms, the presentation to override.

## Before / After

```text
After
  module file:  custom."opmodel.dev@v0".listing
                  {schemaVersion: 1, title: "Jellyfin", summary: "Free software media server ...",
                   category: "media", icon: "assets/icon.svg", links: [...]}
  zip:          assets/icon.svg (refused at publish if scripted)
  #config:      storage ... @opm(ui, title="Library size", group="Storage", order=1, widget=quantity)
  index module: opmodel.dev/modules/index  -> one fetch lists every first-party card
  Acme's definition:
                presentation: {displayName: "Media server", icon: <data URI>,
                               presets: [{name: "small", values: storage: "50Gi"}],
                               fields: publishedServerUrl: advanced: true}
     |
     v
  portal: "Media server" [Acme icon]  (falls through to the author's summary)
          form: "Storage" group first, "Library size" with a quantity widget,
                author's help text, advanced fields folded, a "small" preset
```

Measured cost on the 20-module fleet: a card is 471 to 585 bytes, the module file grows to 1,038 to 1,177 bytes with the full 0022 block plus a card, and a cards-only index of all 20 modules publishes as a 3,210-byte zip (`experiments/02-listing-card/`, `experiments/03-index-module/`).
