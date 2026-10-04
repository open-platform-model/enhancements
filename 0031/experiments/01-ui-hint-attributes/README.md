# 01-ui-hint-attributes — Module Presentation Contract

Status: Concluded

## Hypothesis

`@opm(ui, ...)` field attributes and doc comments on `#config` reach a reader of a published, kernel-acquired module intact, a second `@opm` attribute on the same field included, and a reader can tell the module's hints and comments apart from a catalog type's and from core's.

## Setup

Measured 2026-10-04 (experiment E2 of the portal design work, runs E2a to E2d).

- cue v0.17.1, CLI and Go API. The library at its beta.3 main through a replace directive. Core v2.0.0-beta.1 and the opm catalog v4.4.4 from GHCR.
- Two throwaway in-process OCI registries on localhost, with per-request logging. Nothing pushed outside localhost; no repository edited.
- A throwaway catalog `throwaway.test/uicat@v1`, and a sonarr-derived module `throwaway.test/modules/uidemo@v1` with 30 `#config` fields covering all nine vocabulary keys (`title`, `group`, `order`, `widget`, `advanced`, `hidden`, `placeholder`, `options`, `discriminator`), one field carrying both `@opm(ui, ...)` and `@opm(secret, group=admin, key=password)`.
- 27 attribute-parse cases compiled from strings.
- An offline CRD check with `k8s.io/apiextensions-apiserver` v0.37.1 schema types.

The Go harness lived in a scratch directory and is not kept here; the method below is enough to repeat it.

## Run

1. Publish the catalog and the module to the local registry with the stock CLI.
2. Walk `#config` twice: from a local load, and from the library's kernel acquisition of the published module. Read each field's attributes with the field-attribute accessor (all attributes) and the single-attribute accessor (first match), and each field's doc comments.
3. Repeat the walk for catalog types used every way a module uses them: unified with a literal, embedded, reached through a `let`, named bare, as a disjunction arm, as list and map elements, and as a scalar definition.
4. Compile the 27 parse cases and read each through the positional, lookup and flag accessors.
5. Decode a CRD whose schema carries `x-opm-ui`, leniently and strictly.

## Outcome

**E2a: carriage. Held.**

- The published zip's module source was byte-identical to the local file: 26 `@opm(` occurrences in each.
- The walk after kernel acquisition (44 ms) was identical to the local walk, attributes and doc comments alike.
- The field-attribute accessor returned both `@opm(ui, ...)` and `@opm(secret, ...)` on the one field. The single-attribute accessor returned only the first, so a `ui` hint written first hides the secret marker. Backs 0031:D4:R1 and 0031:D4:R2.

**E2b: catalog-type hints. Held only with a reader rule.**

- Order: the module's field attribute came first, the catalog sub-field's second, for unification either way round and for embedding. Identical text was deduplicated. Declaration attributes also came back module-first. The order comes from an undocumented internal conjunct order, and an attribute has no position.
- A type-level declaration attribute reached the field only when the type was unified with a struct literal, embedded, or reached through a `let`. It was **lost** for a bare reference (`f: #T`), a disjunction arm, list and map elements, and nested bare references.
- A field attribute on a scalar definition (`#Port: int & ... @opm(ui, widget=port)`) **never** reached a field typed `types.#Port | *8989`.
- Following the field's reference path, and each operand of its expression, recovered every lost case after kernel acquisition, across packages (verified for a port scalar, a struct wrapping it, the image type and a bare resources type). The type's hints come back in a separate list, so precedence is a reader rule: origin by subtraction, module wins key by key. Backs 0031:D5:R3 and 0031:D5:R4.

**E2c: parse traps. Held, with refusals needed.**

- Quoted forms (`"..."`, `'...'`, `#"..."#`, multi-line) all unquote cleanly; commas and `)` inside quotes are fine. Unquoted values keep spaces.
- An unquoted `)` or a newline inside `"..."` is a compile error that breaks module load.
- `@opm(ui title=x)` parses as one key named `ui title`: the kind in position 0 is silently lost.
- Duplicate keys are kept and lookup returns the first. A bare `hidden` reads as a flag while lookup does not find it; `hidden=true` reads as not a flag. Names are case-sensitive.
- An attribute on a `[string]:` pattern is inherited by every matching key. An optional field is visible only when the walk includes optional fields.
- `options="a|b|c"` duplicates a field's own enum as an opaque string.

These are the refused forms in `contracts/hints.cue` and 0031:D4:R3.

**E2d: help text and CRDs. Held.**

- On a catalog-typed field the module's doc comment came first, then the catalog's; with no module comment, only the catalog's. At the `#config` root, core's "Value schema ... MUST be OpenAPIv3 compliant" comment leaked in after the module's. Trailing line comments were never doc.
- Each comment's source file tells the origins apart: the module's own files sit under the kernel's acquisition prefix, dependencies under the module cache. Backs 0031:D5:R1.
- Lenient decoding of a CRD dropped `x-opm-ui` silently; strict decoding refused it as `unknown field "properties.port.x-opm-ui"`. Evidence for 0031:OQ10.

Hypothesis held: hints and comments travel intact, and a reader that reads every `@opm` attribute and follows references gets every hint with its origin.
