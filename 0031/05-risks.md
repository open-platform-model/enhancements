# Risks, Drawbacks, Alternatives: Module Presentation Contract

Risks describe what could go wrong. Drawbacks describe what definitely costs something. Alternatives describe the high-level paths not taken; per-decision detail lives in `03-decisions.md`.

## Risks and Mitigations

- **The substrate stalls.** This entry cannot be accepted before 0022 and 0027 are, and 0027 has many acceptance-blocking questions, with 0025's question on how a declaration-only module trait states its fulfilment (0025:OQ13) underneath 0027:D5. **Mitigation:** the card and the index need only 0022 and this entry, so a browse-and-preview tool for platform admins delivers value before anything is orderable.
- **Authors do not write cards or hints.** A marketplace then shows module paths and raw field names. **Mitigation:** every field has a derived default (a label from the field name, a widget from the type), the card is required to appear well and not to appear at all, and the platform's presentation (0031:D6) fills gaps without the author.
- **0022's open tail lets typos through.** With the block open, a misspelled optional key such as `listng` passes the gate silently (measured, `experiments/02-listing-card/`). **Mitigation:** a CLI warning on block keys the CLI's core does not know, which catches the typo without making an older core refuse a newer block.
- **A reader stops at the first `@opm` attribute.** The single-attribute accessor CUE offers returns only the first, so with a `ui` hint written before a secret marker such a reader silently drops the secret's routing overrides and the marker-type check of 0013:D13:R2 (measured). Discovery survives, because it keys on core's tag (0013:D13, 0013:D33). **Mitigation:** 0031:D4:R2 and its amendment of 0013:D2 make reading every `@opm` attribute a requirement on every reader, secret discovery included.
- **Catalog-type hints vanish on bare references.** CUE drops a type's declaration attribute when a field names the type bare, and never carries a scalar definition's field attribute (measured). **Mitigation:** 0031:D5:R3 requires readers to follow references, which recovered every measured case.
- **Module images carry script.** An SVG can run script if a UI inlines it. **Mitigation:** OQ17 blocks acceptance; its candidate has two independent layers, a publish refusal of scripted SVG and inert rendering in every OPM UI.
- **Assets make every render heavier.** The zip is downloaded whole on every render fetch, so a module at the asset caps downloads about 2.1 MiB more per version. **Mitigation:** OQ17's small candidate caps and a digest-keyed fetch cache.
- **The index goes stale.** A new release appears only after the next index release. **Mitigation:** the index is a hint; readers check each member's tags for newer releases (0031:D7:R5), and an admin can add a path by hand.
- **Module coordinates reach tenants.** If tenants read definitions directly, they see module paths, versions and bound values against 0027:D1:R2. **Mitigation:** OQ1's listing-projection candidate, and OQ13's reference-only secret bindings.

## Drawbacks

- **A typo in a card or a hint costs a module release.** The card, the assets, the hints and the doc comments travel inside the immutable version (OQ4). The platform's presentation is the only release-free layer.
- **The module file grows.** About 210 bytes today, about 1.1 KB with the full 0022 block plus a typical card (measured), and fetched on every dependency resolve.
- **Two hint carriers on a catalog type.** A declaration attribute for a whole-field widget and field attributes for sub-fields, read by a reference-following rule that a reader must implement correctly.
- **A new reserved name in first-party space.** `opmodel.dev/modules/index` can never be a module, which amends 0011:D13.

## Alternatives

Surveyed in the portal design research of ten package and service ecosystems. OLM embeds an icon and keeps field descriptors beside the CRD schema under a closed URN vocabulary; Cozystack puts presentation on a platform-authored application definition; Open Service Broker, Artifact Hub and Helm carry images by URL; Crossplane, Kratix and Score carry almost no presentation and leave it to an external catalog. None of the six closest systems localises catalog content per field.

- **A typed presentation block on `#Module`.** Card fields in the module's own CUE. **Why not:** reading it needs the zip and CUE evaluation, so every list view pays for every module.
- **OCI manifest annotations or a listing referrer as the card.** **Why not:** CUE tooling reads neither (0022:D6 keeps annotations for push-time provenance), no gate validates them, and GHCR has no native referrers API.
- **Hints inside the served CRD as vendor keywords.** The pattern Cozystack and several Backstage plugins use. **Why not:** the API server's strict decoding refuses such keys (measured), and a binding-only definition has no CRD.
- **A hand-authored UI schema beside `#config`.** **Why not:** a second schema drifts from the first, the problem 0027:D2 refuses for CRD schemas.
- **A central OPM marketplace or index service.** **Why not:** it does not fit air gaps or data sovereignty, and the central registry is undecided. An index is a module any publisher hosts.
- **A bespoke package format beside the module.** **Why not:** the standalone package-manager UIs that took this road (Kubeapps, Glasskube) are archived, and the module is already the artifact every OPM tool reads.
