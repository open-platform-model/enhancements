# Open Questions — Module and Catalog Identity

## Open Questions

- **OQ1: Does `#Catalog` gain a `name` field?** Status: resolved-by-D16.

- **OQ2: What does the D3 floor compare against when a catalog was not resolved from a tag?** Status: resolved-by-D4.

- **OQ3: Is a primitive's `modulePath` required to sit under its owning catalog's?** Status: resolved-by-D17.

- **OQ4: How do live instances adopt their new identity?** Status: resolved-by-D18.

- **OQ5: Do prereleases and 0.x builds of one major share a key space safely?** Status: resolved-by-D4 and D14.

- **OQ7: When may a catalog build be dropped from a platform's materialized set?** Status: resolved-by-D14.

- **OQ8: What stops a moved-ahead dev checkout from supplying keys that look published?** Status: resolved-by-D19.

- **OQ6: Does a primitive's `metadata.version` have a reader?** Status: resolved-by-D21.

- **OQ9: What supplies the auto-secrets resource identity, now that `core` cannot?** Status: answered. Nothing does, because `core` no longer names one. `core/src/helpers_autosecrets.cue` was deleted and the `opm-secrets` injection removed from `#ModuleInstance` (core `a77a12d`, 2026-07-27), so no `core` construct names a catalog primitive and there is no identity left to supply. The *discovery* half stays — `#AutoSecrets`, `#DiscoverSecrets` and `#GroupSecrets` remain in `core/src/schemas.cue` and catalogs re-export them — while a module carrying secrets now declares a secrets component against its own catalog's `#Secrets` resource, so the FQN comes from the catalog that owns it, as every other primitive's does. `core/src/module_instance.cue:59-65` records the reasoning in this question's own terms ("a catalog's FQN embeds that catalog's version — a value core cannot know and must not hardcode") and settles one thing this question left open: the mismatch was live rather than latent, because the injected component "matched no transformer on the v1 line and failed the render outright". Original framing follows. Surfaced 2026-07-27 while resolving OQ3. `core/src/helpers_autosecrets.cue:5` hardcodes `#SecretsResourceFQN: "opmodel.dev/opm/resources/config/secrets@1.0.0"` and `:31` a matching `modulePath: "opmodel.dev/opm/resources/config"`. These are **live values, not doc examples**: `core/src/module_instance.cue:72` synthesizes an `opm-secrets` component keyed by that FQN whenever a module's resolved config contains `#Secret` fields. The shipped catalog ships the same primitive at `opmodel.dev/catalogs/opm/resources/secrets@<id.Version>` (`catalog_opm/src/resources/secret.cue:20-22`), and `catalog_opm/src/transformers/secret_transformer.cue:35` requires *that* FQN. The two differ in both path and version, so the synthesized component cannot match the transformer meant to handle it. The stale comment above the constant ("must stay in sync with `resources/config/secret.cue`") names the deprecated `catalog/` tree's layout, so this is fallout from the catalog split. One fleet module reaches the code path (`modules/metallb`).

  This belongs to 0010 because D13 makes the version half permanent: a literal `@1.0.0` written into `core` can never equal a catalog build's key, and no subscription breadth fixes it — the key names a build of a catalog that does not exist. The deeper problem is that `core` names a *catalog primitive* at all, which is a layering inversion this entry's identity model has no way to express: `core` is the schema every catalog depends on, so it cannot depend on one. Candidates: **(a)** move the whole auto-secrets synthesis out of `core` and into the catalog that owns the secrets resource, so the FQN is computed from `id` at its own definition site like every other primitive; **(b)** keep the synthesis in `core` but have it take the secrets FQN as an input supplied by the platform's materialized catalogs rather than as a literal; **(c)** keep the literal and accept that auto-secrets only works for a catalog that agrees to ship that exact path and version, documenting the coupling. Resolving this fixes whether `core` may name a primitive, and whether auto-secrets survives in its current form.

- **OQ10: What owns a `ModuleInstance`'s resources through deletion?** Status: deferred-to-0012.

- **OQ11: What pins the transformer build, now that the key no longer does?** Status: resolved-by-D14.

- **OQ12: How is provenance excluded from the match comparison, and where is the boundary?** Status: resolved-by-D30.

- **OQ13: Does the additive-only promise get a read-side check, or is publish-side enforcement accepted as the whole of it?** Status: resolved-by-D35.

- **OQ14: What `apiVersion` does a pre-stable contract carry, and when does the promise turn on?** Status: resolved-by-D34.

- **OQ15: Does a subscription still materialize every build in the major, and if so what picks one transformer per contract?** Status: resolved-by-D14.

- **OQ16: Is a primitive's component fragment covered by the additive-only promise?** Status: resolved-by-D36.

- **OQ17: When two catalogs deliberately supply one contract, what decides which implements it?** Status: resolved-by-D37.
