# Experiments — OPM Module Publishing Workflow

Self-contained proofs-of-concept validating specific claims from the
design. See the enhancement's `02-design.md` for the claims being
tested. This file is the hand-maintained index — add a row per
experiment. Per-experiment status lives in each `NN-*/README.md`'s
`Status:` line.

> **Status note (2026-07-26), superseding an earlier banner here.** D17 briefly removed `#Catalog.metadata.version` entirely, and this file said experiments 01 and 02 were therefore historical. **D19 reversed that**: the catalog keeps a full SemVer `metadata.version` as the *compatibility signal*, while FQNs stay major-keyed as the *match key* (D18). So 01 and 02 are **live evidence again**. Exp 02's conclusion — strict-committed is the only declaration satisfying all three required properties — is directly load-bearing for OQ13. Exp 01's conclusion still holds with reduced severity: a stamped catalog's local-versus-published divergence no longer corrupts the match key, which is major-keyed now, but it does corrupt the compatibility signal, so the version must still be committed rather than stamped. Exp 03 is unaffected throughout.

All three experiments below exist to resolve **OQ13** — where a catalog's
version comes from under D4, now that D7 has brought catalog publishing into
this entry's scope. They partition the question into: does the status quo
actually break (01), which declaration is right (02), and what of enhancement
0001's existing catalog design survives the answer (03).

| # | Concept | Pins | Status |
| - | ------- | ---- | ------ |
| 01 | catalog-local-vs-published-parity | OQ13; challenges 0001 D8 + D9 | Concluded |
| 02 | catalog-version-authoring-alternatives | OQ13 | Concluded |
| 03 | identity-subpackage-necessity | OQ13; 0001 D7 + D19 retention | Concluded |
| 04 | local-module-chain-hops | OQ8 bullets 1 + 2 | Concluded |
| 05 | decided-shapes-module-catalog | D13–D20 as a whole; open A/B on `#Catalog.metadata.version`, OQ17, OQ18 | Running |
| 06 | identity-supply-mechanisms | mechanism half of D23/D25 — `@tag()` vs committed value vs marker+generated | Concluded |

Experiment 04 answers a different question from 01–03: OQ8's dev-loop
question about `cue.mod/local-module.cue` replacement chains, not catalog
version identity.

**Still unrun:** OQ8 bullet 3 — whether catalog *materialization* honours a
`replaceWith` at all. That is a kernel question rather than a CUE-resolution
one and needs a full render fixture (Platform with a `#registry` subscription
+ catalog + module). Experiment 04's Outcome records the code-level prior.

## Hypotheses

### 01-catalog-local-vs-published-parity

Under enhancement 0001's sentinel-plus-stamping method (D8 + D9), a catalog resolved from a local checkout produces different primitive FQNs than the same catalog resolved from the registry, because the FQN interpolates a version the two trees disagree about. Under a strict-committed-version method the two are byte-identical. Run against a live registry.

### 02-catalog-version-authoring-alternatives

Exactly one of six candidate version declarations satisfies all three required properties — the committed tree vets without ceremony, no placeholder can ship, and a version/tag disagreement is a schema-level failure. Variants span `core`'s literal declaration, the production identity-supplied shape, strict-committed, strict-but-forgotten, no-version-field, and a schema-level publish guard.

### 03-identity-subpackage-necessity

The sibling `identity/` subpackage is load-bearing for a reason independent of stamping — without it the catalog root and its transformer subpackage form a package import cycle — so it survives any change to how the version is authored.

### 06-identity-supply-mechanisms

An artifact's identity must be present in its own committed bytes, because CUE's dependency resolution carries it to consumers and OPM does not mediate that: a `@tag()`-supplied identity is invisible to a transitive importer whatever the top-level build injects, a committed concrete value resolves correctly with no tooling in the loop, and an inert `@opm()` marker attribute can sit alongside it without affecting evaluation.

### 05-decided-shapes-module-catalog

Decisions D13–D20 compose into a working `#Module` and `#Catalog` in which identity and match keys are stable while the compatibility signal moves: `fqn`, `uuid`, and every demanded primitive FQN are byte-identical across a catalog MINOR bump and between a local checkout and a published artifact, whereas the catalog version a module was built against varies and is what the D19 floor compares. Built as a readable reference implementation so the decisions can be reviewed as code; no registry required.

### 04-local-module-chain-hops

CUE honours `local-module.cue` only for the main module, so in a two-hop chain (`instance → module → catalog`) the inner replacement is silently dropped and the instance renders local module bytes against the published catalog. The chain can be reconstructed by listing every hop in the outermost `local-module.cue`, and `cue mod tidy` preserves such a file. Run against a live registry.

## Combined result

Method A (status quo) diverges between local and published FQNs; method B (strict committed) has parity by construction (01). Of six candidate declarations only strict-committed satisfies every required property, and a schema-level guard on the sentinel is not expressible in CUE (02). The `identity/` subpackage is required regardless (03).

Two incidental findings worth carrying independently of OQ7's resolution:

- **`core/src/catalog.cue:63`'s `*"0.0.0-dev"` default is inert.** A required field's disjunction default never applies; `core/SPEC.md:576` documents a mechanism that does not exist. The real default comes from `identity.Version`, a plain field. (Experiment 02, finding 1.)
- **Enhancement 0001's proposed "CI guard that rejects publishes of `0.0.0-dev`" cannot live in the schema** — a CUE guard deletes the default rather than rejecting it, and fires during development. The guard must be a publish-task check, and is therefore bypassable by `cue mod publish`. (Experiment 02, finding 4.)
