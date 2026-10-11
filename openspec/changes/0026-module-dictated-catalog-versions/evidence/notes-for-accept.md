# Notes for the owner at accept

Written by the converter, not part of the entry's text. They list the places where the conversion made a call that the owner confirms at accept. The proposal holds only the questions of the old entry.

## Blocking questions

The proposal keeps all 18 old questions except OQ8 and OQ17, which the old text closed. Ten are Blocking: OQ1, OQ2, OQ3, OQ5, OQ9, OQ10, OQ11, OQ12, OQ13 and OQ18. OQ5 had `Blocking: implementation` in the old text, which becomes a Blocking line by the ruling of 2026-10-11 07:55. The entry stays a draft until each is answered and moved into the design.

## Seed requirements that 0026 changes but the old lines do not decide

These wait on the blocking questions above. Each needs a MODIFIED or a REMOVED and ADDED pair once the owner answers.

- OQ11 and OQ12 decide where the provider count and the over-subscription report live at platform level. They touch `platform-contract-inventory` ("A platform derives its contract inventory" beyond the rename that 0026:D3:R1 states, "Providers are named per registry entry", "Over-subscription lists contracts with several providers"), `platform-contract-gates` ("An over-subscribed contract fails the check", "An over-subscribed platform is refused at generation") and the sentence of `contract-fulfilment` that says core computes the provider count once, in the inventory. The ADDED requirement of `contract-fulfilment` keeps that sentence word for word, by the ruling that a MODIFIED or a replacement drops no seed sentence that no old line changes. D9:R5 arguably makes "once" false for a platform with two majors; the shipped rule stays until the owner answers OQ12, and OQ12 then decides whether the sentence changes.
- OQ3 and OQ11 decide the reference versions of the module-less build. They touch `platform-module-generation` ("The registry unites authored subscriptions and active claims", "The generated module is validated by building it"), which still pins each subscription at the version it names.
- The word "subscription" still stands in `platform-module-generation` and `platform-registry`. A vocabulary pass over the seeds follows the owner's answers.

## Seed requirements of platform-artifact that 0026 may touch

The seed writer of `platform-artifact` guessed these two from 0026:D3, which gives the name `#Platform` to the authored value (`reports/T4.3-platform-artifact.md`; `seed-platform-artifact/source.md`, last line). No old requirement line decides them, so this conversion modifies neither. The owner decides at accept whether each needs a MODIFIED.

- "Acquisition refuses a package that is no platform": its kind check says "one struct of kind Platform". Whether acquisition checks the authored platform, the resolved platform or both is open.
- "A platform holds its package, metadata and source": the wording may need the name of the value.

## Purpose lines that a delta cannot change

The `## Purpose` of the seed `platform-module-generation` says the generated module "embeds `#Platform`". A delta cannot change a Purpose, so the delivery of 0026 needs a Purpose-only PR to correct it (DECISIONS 2026-10-10 19:00 Q2).

## Seed requirements the seed writers named that this conversion leaves unchanged

No old requirement line states a change to them, so none is modified.

- `single-build-render`: "Render inputs are source-carrying artifacts", "Local replacements are promoted under dependency precedence", "Version skew follows a caller-chosen policy", "A render refuses colliding contract keys". The first and third read as platform-wins rules or as inputs of a render, and 0026 states the module-wins rule only for the dependency list.
- `platform-registry`: "Catalog selection depends on committed source only". It stays true of the generated registry.
- `platform-module-generation`: "An entry's expected version is stamped bare", "The dependency closure comes from published module files".
- The collision rules and the CLI half of the colliding-platform refusal are in no seed. 0026 adds no collision requirement. The collision reports shipped ahead of this entry, as the old text of OQ17 says.

## Overlaps for the collision review

- `catalog-version-selection` "A render without a platform holds its pins" overlaps the CLI rule of the seed `platform-resolution`, "Deps become one catalog entry each, core floored". The first states the kernel rule, the second the CLI frontend.
- `registration-acceptance` "A build-incompatible provider is refused at acceptance": the operator change `index-build-compat-by-major` already compares a claim with the entry of the provider's own major. The seed text predates it. The MODIFIED restates the requirement with that rule and the platform floors of the old D7. Task 3.1 is ticked for that change.

## The old text of OQ13

The old text says the operator's shared-path check answers arbitrarily on a platform with two majors of one catalog. The old text of OQ17 says that change shipped. The proposal does not repeat the claim.

## Clashes that the old text itself holds

The conversion does not rewrite the first; the owner decides at accept which line wins. The second is the entry's change, which the sync carries into the seed.

- **Admission by entry, or by registration.** The old line 0026:D2:R2 says a module importing a catalog path with no enabled admission entry is refused as not admitted. The old line 0026:D6:R1 says a provider catalog is admitted by its accepted registration alone, with no entry. A module that imports a provider catalog with an accepted registration and no entry meets both lines. The requirement "An unadmitted catalog is refused" keeps the text of D2:R2. Its scenario "No entry for the path" names the case of no entry and no accepted registration, so the scenarios agree with each other. The requirement text does not yet carry the registration case. The same gap holds for a provider catalog that has a disabled entry.
- **Version held, or registration's version.** The old line 0026:D5:R1 says a consumer module renders at its own pin on a provider catalog's path. The old line 0026:D5:R2 says the render holds the registration's version when no consumer pins the path. The seed scenario "An active claim's catalog reaches the package" of `platform-module-generation` says the package carries the provider's catalog at the claim's version without the condition of D5:R2. The delta adds the condition "and no consumer pins its catalog's path". The sync must carry that condition into the seed.
