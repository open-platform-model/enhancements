# 03-index-module — Module Presentation Contract

Status: Concluded

## Hypothesis

A published CUE module holding a copy of every member's card lists a 20-module fleet in a few requests with stock tooling, and mirrors with its members by an ordinary copy.

## Setup

Measured 2026-10-04 (experiment E4 of the portal design work, run E4c).

- cue v0.17.1, `crane`, and the two throwaway localhost registries of experiment 01, all in memory.
- The 20 fleet module paths of experiment 02, published with cards.
- A builder doing plain OCI GETs over an explicit path list: for each path, the tag list, the manifest and the module file, plus the zip when a thumbnail is wanted.
- Two index variants: cards only, and cards with an SVG data-URI thumbnail per member (icons 554 bytes to 1.3 KB).
- The index was published as a plain CUE module with no 0022 block, because 0022's block admits no `index` kind (0031:OQ8).

The builder lived in a scratch directory and is not kept here; the index data shape it wrote is `#ListingIndex` in `schemas/target.cue`.

## Run

1. Build both index variants over the 20 paths; count requests and bytes.
2. Vet and publish each index.
3. From a cold consumer, import the index and evaluate `len(idx.entries)`; count requests. Repeat with a direct OCI reader.
4. Copy the index and its 20 members to the second registry with `crane copy`, then repeat step 3 against it and compare digests.

## Outcome

**Build.** Cards only: 60 requests, 33,315 bytes read, 7 to 12 ms. With thumbnails: 80 requests, 1,407,066 bytes read (every member zip), 14 to 19 ms. Localhost in-memory timings.

**Size.** Cards-only `index.cue`: 15,409 bytes, published as a 3,210-byte zip with a 102-byte module file. With thumbnails: 40,669 bytes, an 11,848-byte zip, about 3.7 times larger. Vet plus publish took about 20 ms.

**Read.** A cold consumer through the CUE CLI made 7 requests (two parent-path probes returning 404, the tag list, the manifest twice, the module file and the zip); export made none. A direct OCI reader needs 3 requests (2 with a known version), against 60 for crawling every module file.

**Mirror.** Copying the index and its 20 members took 180 ms. A consumer against the mirror got 20 entries, each entry's version equalled the member's version, and the index digests equalled the mirrored manifest digests.

**Not measured:** GHCR and Zot latency, real icon sizes (often 2 to 20 KB), and less repetitive card text, so the compression figures are optimistic.

Hypothesis held. Backs 0031:D7:R1 and 0031:D7:R4, and the choice to keep thumbnails optional. Readers should read the index with direct OCI requests rather than through the CUE CLI, and a builder should cache member zips by digest.
