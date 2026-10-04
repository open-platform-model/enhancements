# 06-module-file-card-roundtrip: Machine-Readable Artifact Metadata in cue.mod/module.cue

Status: Concluded

## Hypothesis

A block carrying the four D2 fields plus a listing card survives `cue mod tidy` with every value intact on every real fleet module, and publish ships the module file exactly as tidy left it. Backs D1:R5 (values-intact, not byte-verbatim) and gives partial evidence for OQ5.

## Setup

- Corpus: the 20 published fleet modules (12 from `opm-modules`, 8 from `modules`).
- Each module file gained the full block under `custom."opmodel.dev@v0"` plus a `listing` card (title, summary, category, icon path, links) and an `assets/icon.svg` in the module tree.
- cue v0.17.1 (CLI and Go API); library at beta.3; core v2.0.0-beta.1 and catalogs/opm v4.4.4 from GHCR.
- Two throwaway in-process OCI registries on localhost with per-request logging. Nothing was pushed outside localhost and no repo was edited.

## Run

Ran 2026-10-04 as a throwaway harness outside this repo (not committed). For each module: `cue mod tidy`, compare values before and after, vet the card against the measured card schema, publish to the local registry, and compare the published module-file blob with the tidied file.

## Outcome

- Values survived tidy intact on 20 of 20. Tidy dropped all comments, sorted keys and expanded one-line structs, so the bytes changed.
- The published module-file blob was byte-identical to the tidied file on 20 of 20.
- The card vetted on 20 of 20. Cards were 471 to 585 B as canonical JSON (mean 520). Module files grew from about 210 B to 1,038 to 1,177 B with the full block plus the card.
- `assets/icon.svg` shipped inside the published zip.
- A card with every field at its cap (8,486 B) still tidied value-intact, published, and resolved from a cold consumer, with a 9,375 B module file. Its size cap belongs to entry 0031.
- The 0022 gate itself was not run on the tidied files, so OQ5 is not closed by this experiment.

Hypothesis held. Tidy canonicalises the block's text and keeps its values; publish then ships the tidied bytes unchanged. D1:R5 states exactly that.
