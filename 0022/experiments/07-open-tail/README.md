# 07-open-tail: Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Concluded

## Hypothesis

`#ModuleFileCustom` as first drafted lets a block carry a key a later entry defines, as D1:R3 ("a reader ignores keys it does not know") requires of every reader, the gate included. Backs D2:R7.

## Setup

- A verbatim copy of `#ModuleFileCustom` as drafted (four required fields, closed).
- Three variants: an older core with only `...` as the block shape; the drafted shape plus `listing?: #Listing` (the measured card schema) and `...`; and the drafted shape unchanged.
- Inputs: a block with no card, a valid listing card, a card plus an unknown future key, one card carrying a bad category, an `https://` icon and a `locales` key the card schema forbids, and a misspelled optional key (`listng`).
- cue v0.17.1, as in experiment 06.

## Run

```bash
bash run.sh
```

`schema/closed`, `schema/oldopen` and `schema/open` are the three variants; `schema/cases/*.json` the inputs (`card`, `card-future`, `bad-card` carrying the bad category, the `https://` icon and `locales` at once, `typo`, and `no-card`). The script vets every case against every variant and prints the verdict with each error's first line.

## Outcome

- **Drafted shape, closed:** refuses the card with "listing: field not allowed" and refuses every unknown future key. D1:R3 was therefore false for this entry's own gate.
- **Older core with only `...`:** accepts the card, the future key and the bad card. Any new key passes, unjudged.
- **Drafted shape plus `listing?` and `...`:** accepts valid cards and future keys, and refuses the bad category, the `https://` icon and `locales`.
- **Cost of any open tail:** the misspelled `listng` passes silently. A forbidden key written as `_|_` gives a poor error ("explicit error (_|_ literal) in source").

Hypothesis refuted for the drafted shape. The block now ends in `...` with `listing?: _` reserved: whatever entry defines the listing card owns its schema, so this entry does not import it. A misspelled key is a CLI lint warning on keys the CLI's core does not know, not a gate refusal.
