# Problem Statement: Module Presentation Contract

A UI cannot list or present an OPM module, or a platform's offering of one, without kind-specific code. Nothing a module publishes says what it is called for a human, what it looks like, or how its configuration should be laid out as a form, and nothing a platform owns can say it either.

## Current State

**A published module carries one line of description.** An OPM module is a CUE module: one OCI manifest with exactly two layers, the module zip and the module file (`cue.mod/module.cue`). CUE's client refuses any other layer count. OPM publishes it with no manifest annotations. Everything descriptive lives inside the zip: `#Module.metadata.description` (one line), a README and a CHANGELOG. Measured across the first-party and personal fleets (20 modules): no module has an icon, a category, a screenshot or a display title.

**The module file is a channel, and entry 0022 is opening it.** Entry 0022 puts a metadata block at `custom."opmodel.dev@v0"` in the module file, holding `kind`, `identity`, `core` and `catalogs`, every value a duplicate its publish gate asserts. The module file is about 210 bytes, fetched without the zip, and readable without evaluating CUE. Measured: a block in it survives `cue mod tidy` and publish with every value intact, though tidy sorts keys and drops comments (`experiments/02-listing-card/`).

**A module's configuration has no layout.** `#config` states types, constraints, defaults and doc comments. It says nothing about which fields belong together, which are advanced, what a field should be labelled, or which widget suits it. Doc comments are rich (heavy prose in all 19 modules sampled), but `Value.Doc` returns every conjunct's comments, so core's own `#config` comment ("Value schema ... MUST be OpenAPIv3 compliant") leaks into a module's root help text (measured, `experiments/01-ui-hint-attributes/`).

**A field attribute namespace exists.** Entry 0013 established `@opm(secret, ...)` on `#config` fields, dispatched on position 0 (0013:D2). Field attributes survive publish and kernel acquisition (measured). No library code reads any `@opm` attribute yet.

**A platform has an object for each offering, but no presentation on it.** Entry 0027 gives the platform a cluster-scoped definition that binds a module and serves its `#config` as a Kubernetes kind (0027:D1). The definition carries a binding, an update policy and bound values. It carries nothing a marketplace could show.

**Nothing lists the modules a publisher offers.** GHCR has no usable `/v2/_catalog` (it is one global list of all of GHCR) and no native OCI referrers API. Anonymous `tags/list` works for a known path. A UI can enumerate versions of a module it already knows, and cannot discover which modules exist.

## Gap / Pain

- **A UI shows module paths and raw field names.** With no card, a catalog grid can show `opmodel.dev/modules/jellyfin@v1` and the one-line description, and nothing else.
- **Every UI invents its own form layout.** With no hints, each consumer of a module's schema either renders every field flat in source order or writes per-module code. Neither scales past a handful of modules.
- **A platform cannot fix what its users see.** A platform team that wants a different name, a different icon, a preset or a hidden field for its own users has nowhere to put it without forking the module.
- **Listing a publisher's modules costs one request per guessed path.** Without an index, a browser either holds an explicit path list or crawls every module file it knows.
- **0022's gate refuses what a later entry adds.** As drafted, 0022's block definition is closed, so a module carrying any key the gate does not know is refused at publish by every core that predates the key. Measured: the drafted gate refuses a card with `listing: field not allowed` (`experiments/02-listing-card/`).

## Concrete Example

A platform team at Acme wants to offer the Jellyfin media server to its application teams through an OPM portal.

```text
Today
  registry: opmodel.dev/modules/jellyfin@v1   (zip + module file, no annotations)
     |
     v
  portal: "jellyfin"  "Free software media server"  [no icon]
          form: 30 fields, flat, source order, labels like "publishedServerUrl",
                help text that starts with core's "MUST be OpenAPIv3 compliant"
     |
  Acme wants: title "Media server", its own icon, a "small" preset,
              the storage field first under "Storage", advanced fields folded
     -> no place to say any of it
```

The author knows the module's title, icon and which fields matter; Acme knows its own taxonomy and presets. Neither has a place to say it, and the portal has nothing to read.

## User Stories

- As a **module author**, I want to give my module a title, icon, category and a sensible form layout once, so that every OPM UI presents it well. Today: there is no field for any of it, and an icon has no carrier.
- As a **platform team operator**, I want to rename, re-brand, preset and hide parts of an offering for my users without forking the module. Today: the 0027 definition has no presentation, and a module edit needs a release.
- As a **portal or tool author**, I want to list a publisher's modules and render a form for any of them from published data alone. Today: there is no index, no card, and no hints, so I need per-module code.

## Why Existing Workarounds Fail

- **README parsing.** Measured READMEs differ wildly in structure; a card scraped from them is guesswork, and the README lives in the zip, so a list view pays for every zip.
- **OCI manifest annotations.** OPM publishes through CUE's module registry client, which writes none; CUE tooling never reads them; they are outside the content-addressed module bytes, and no gate can validate them.
- **A listing referrer per module.** Measured: GHCR has no native referrers API, and a referrer per module still gives no listing of a prefix. 0022:D1 already rejected a sidecar artifact for drift.
- **Hard-coded per-module UI code.** It is what every surveyed portal without a presentation contract ends up doing, and it is the "kind-specific code" this entry exists to remove.
