# 06-presentation-metadata: Self-Service Kinds from Published Modules

Status: Concluded

## Hypothesis

The author-side presentation metadata OQ17 lists as candidates (a card under the `listing` key of entry 0022's module-file block, `@opm(ui, ...)` field hints with doc-comment help text, and a publisher index module) survives tidy, publish and kernel acquisition on real modules (card, index) and a module derived from a real one (hints), while presentation keys inside a served CRD do not. Evidence for OQ17 only; it decides nothing.

## Setup

Measured 2026-10-04, copied here from a withdrawn proposal's write-ups so the evidence lives with the question that uses it.

- cue v0.17.1 (CLI and Go API); the library at beta.3 main; core v2.0.0-beta.1 and the opm catalog v4.4.4 from GHCR; `crane`; `k8s.io/apiextensions-apiserver` v0.37.1 schema types.
- Two throwaway in-memory OCI registries on localhost. Nothing was pushed outside localhost and no repository was edited.
- The 20-module fleet of experiment 01 (12 personal, 8 first-party), each module file given the full 0022 block plus a hand-written card (title, summary, category, icon path, links) and an `assets/icon.svg`.
- A sonarr-derived throwaway module with 30 `#config` fields carrying `@opm(ui, ...)` hints over nine keys (`title`, `group`, `order`, `widget`, `advanced`, `hidden`, `placeholder`, `options`, `discriminator`), one field also carrying `@opm(secret, ...)`; 27 attribute-parse cases compiled from strings.

The scratch harnesses are not kept; the steps below are enough to repeat the measurements. No credentials or secret values appear in any input or output.

## Run

1. **Card.** For each fleet module: write the block and card, run `cue mod tidy`, compare values before and after, publish, and compare the published module file with the tidied one. Build one card with every field at its cap (links at 512 runes, 10 maintainers), publish it and resolve it from a cold consumer. Check the size line `len(json.Marshal(listing)) & <=8192` against every card.
2. **Hints.** Publish the hinted module; walk `#config` from a local load and from the kernel's acquisition of the published module, reading each field's attributes with the all-attributes accessor and the first-match accessor, and its doc comments. Repeat for catalog types used every way a module uses them. Compile the 27 parse cases.
3. **CRD carriage.** Decode a CRD whose schema carries `x-opm-ui` leniently and strictly.
4. **Index.** Build a CUE module copying every member's card over the 20 paths with plain OCI GETs (cards only, and with SVG data-URI thumbnails), publish it, read it from a cold consumer, and `crane copy` it with its members to the second registry.

## Outcome

**Card.**

- Real cards were 471 to 585 bytes of canonical JSON (mean 520). They survived tidy value-intact on 20 of 20 fleet modules and passed the size line. Module files grew from about 210 bytes to 1,038 to 1,177.
- Tidy dropped comments, sorted keys and expanded one-line structs; the published module file was byte-identical to the tidied file. `assets/icon.svg` shipped inside the published zip.
- The single card with every field at its cap measured 8,486 bytes, over the 8 KiB cap (eight 512-rune links dominate). Its 9,375-byte module file still tidied value-intact, published and resolved from a cold consumer, but the size line refused it (`invalid value 8486`). Tidy and publish do not enforce a size; a separate check must.

**Hints and help text (`@opm` read rules).**

- The published module source was byte-identical to the local file (26 `@opm(` occurrences each), and the walk after acquisition (44 ms) matched the local walk.
- The all-attributes accessor returned both `@opm(ui, ...)` and `@opm(secret, ...)` on one field; the first-match accessor returned only the first. A reader must read every `@opm` attribute, or a `ui` hint written first hides the secret marker.
- On unification and embedding, the module's attribute came before the catalog type's, from an undocumented conjunct order. A type's attribute was lost for a bare reference, a disjunction arm, list and map elements, and a scalar definition; following the field's reference path recovered every lost case after acquisition. Origin and precedence are therefore a reader rule, not something CUE supplies.
- Parse traps: an unquoted `)` or a newline inside quotes breaks module load; `@opm(ui title=x)` silently parses as one key named `ui title`; duplicate keys keep the first on lookup; a bare `hidden` is a flag but `hidden=true` is not; an attribute on a `[string]:` pattern is inherited by every matching key.
- Doc comments: the module's comment came first, then the catalog type's; at the `#config` root, core's own comment leaked in. Each comment's source file (acquisition prefix versus module cache) tells the origins apart. Trailing line comments were never doc.

**CRD carriage.** Lenient decoding dropped `x-opm-ui` silently; strict decoding refused it as `unknown field "properties.port.x-opm-ui"`. Presentation cannot ride inside the served schema (consistent with experiment 05's walker result).

**Index.**

- Build: cards only, 60 requests and 33,315 bytes read; with thumbnails, 80 requests and 1,407,066 bytes (every member zip). Localhost timings 7 to 19 ms.
- Size: cards-only `index.cue` 15,409 bytes (3,210-byte zip); with thumbnails 40,669 bytes (11,848-byte zip).
- Read: a cold consumer through the CUE CLI made 7 requests; a direct OCI reader needs 3 (2 with a known version), against 60 to crawl every module file.
- Mirror: index plus 20 members copied in 180 ms; entry versions and digests matched the mirror.
- The index was published with no 0022 block, because 0022's `#ArtifactKind` names only three kinds (0022:OQ6).
- Not measured: GHCR or Zot latency, real icon sizes (often 2 to 20 KB), less repetitive card text.

Hypothesis held: card, hints and index all travel through tidy, publish, acquisition and mirroring with stock tooling, given a separate size check and a reader that reads every `@opm` attribute and follows references; a presentation key inside a CRD is refused or silently pruned.
