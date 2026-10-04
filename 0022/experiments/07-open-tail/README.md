# 07-open-tail: Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Concluded

## Hypothesis

`#ModuleFileCustom` as first drafted lets a block carry a key a later entry defines, as D1:R3 ("a reader ignores keys it does not know") requires of every reader, the gate included. Backs D2:R7.

## Setup

- A verbatim copy of `#ModuleFileCustom` as drafted (four required fields, closed).
- Three variants: an older core with only `...` as the block shape; the drafted shape plus `listing?: #Listing` (the measured card schema) and `...`; and the drafted shape unchanged.
- Inputs: a valid listing card, an unknown future key, a card with a bad category, a card with an `https://` icon, a card with a `locales` key the card schema forbids, and a misspelled optional key (`listng`).
- cue v0.17.1, as in experiment 06.

## Run

Ran 2026-10-04 as a throwaway harness outside this repo (not committed). Each input was unified with each variant and the verdict and error text recorded.

## Outcome

- **Drafted shape, closed:** refuses the card with "listing: field not allowed" and refuses every unknown future key. D1:R3 was therefore false for this entry's own gate.
- **Older core with only `...`:** accepts the card, the future key and the bad card. Any new key passes, unjudged.
- **Drafted shape plus `listing?` and `...`:** accepts valid cards and future keys, and refuses the bad category, the `https://` icon and `locales`.
- **Cost of any open tail:** the misspelled `listng` passes silently. A forbidden key written as `_|_` gives a poor error ("explicit error (_|_ literal) in source").

Hypothesis refuted for the drafted shape. The block now ends in `...` with `listing?: _` reserved: entry 0031 owns the card schema, so this entry does not import it. A misspelled key is a CLI lint warning on keys the CLI's core does not know, not a gate refusal.
