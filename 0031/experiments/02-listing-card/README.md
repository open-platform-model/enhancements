# 02-listing-card — Module Presentation Contract

Status: Concluded

## Hypothesis

An author card at key `listing` of the 0022 module-file block survives `cue mod tidy` and publish on every real module, stays small, and is accepted by a core gate that predates the card schema once 0022's block admits unknown keys.

## Setup

Measured 2026-10-04 (experiment E4 of the portal design work, runs E4a and E4b).

- cue v0.17.1; the same two throwaway localhost registries as experiment 01.
- A copy of the 20-module fleet: the 12 personal modules and 8 first-party modules. Each module file was given the full 0022 block (`kind`, `identity`, `core`, `catalogs`) plus a hand-written card, and an `assets/icon.svg`.
- The card schema as `schemas/target.cue` states it, except that link URLs were capped at 512 runes and maintainers at 10 (the first draft).
- Three copies of 0022's block definition: as drafted (closed), with only an open tail (`...`, standing in for an older core), and with the open tail plus `listing?: #Listing`.
- Five cases: no card, a valid card, a card plus an unknown future key, a bad card (wrong category, an `https://` icon, `locales`), and a misspelled key (`listng`).

The scripts lived in a scratch directory and are not kept here; the card schema they validated is `schemas/target.cue`.

## Run

1. For each module: write the block and card, run `cue mod tidy`, compare values before and after, vet the card against the schema, publish, and compare the published module-file blob with the tidied file.
2. Build a card with every field at its cap, publish it, and resolve it from a cold consumer.
3. Vet the five cases against each of the three block definitions.
4. Check the size line `len(json.Marshal(listing)) & <=8192` against the all-caps card and the real cards.

## Outcome

**E4a: the card on the real fleet. Held.**

- Values survived tidy intact 20/20, and the card vetted 20/20.
- Tidy dropped every comment, sorted keys and expanded one-line structs. The published module-file blob was byte-identical to the tidied file. So "byte-verbatim" holds for the published file only after tidy, which bears on 0022's wording.
- Card size: 471 to 585 bytes of canonical JSON, mean 520.
- Module file: about 210 bytes before; 1,038 to 1,177 bytes with the full 0022 block plus a card.
- `assets/icon.svg` shipped inside the published zip.
- A card with every field at its first-draft cap was **8,486 bytes, over its own 8 KiB cap** (eight 512-rune links dominate). Its 9,375-byte module file still tidied value-intact, published and resolved from a cold consumer. The size line refused it (`invalid value 8486`) and passed every real card. This is why 0031:D2 caps links at 256 runes and maintainers at five (a card at every cap is then 7,099 bytes, pinned in `schemas/examples.cue`) and keeps the size line as a separate check.

**E4b: the 0022 block's gate. Refuted as drafted; held with an open tail.**

- 0022's block definition as drafted refused the card with `listing: field not allowed`, and refused every unknown future key, so a reader-side "ignore unknown keys" rule does not hold for the gate.
- With only an open tail (an older core), the gate accepted the card, the future key and the bad card (unjudged, as expected for a core that predates the card).
- With the open tail plus `listing?: #Listing`, the gate accepted valid cards and future keys, and refused the bad category, the `https://` icon and `locales`.
- Cost of the open tail: the misspelled `listng` passed silently. A CLI lint that warns on block keys its core does not know catches it without closing the gate.
- `locales?: _|_` refused with a poor error: `explicit error (_|_ literal) in source` (0031:OQ5).

Hypothesis held for the card (0031:D2, 0031:D3:R1) and held for the gate only once 0022 admits unknown keys, which 0022 takes as an in-place revision.
