# Operational Concerns: Self-Describing Modules

This document is the OPM Production Readiness Review (PRR-lite). Five fixed prompts, each answered.

## Observability

**What new signals, metrics, diagnostics, or error types does this enhancement introduce, and how are they surfaced?**

- **Unhandled aspects.** An aspect whose demand no enabled module transformer handles surfaces through the contract inventory as every unhandled demand does: a refusal naming the trait when it is not optional, a warning naming it when it is. Silence is the failure either way: an aspect that should have become an object and did not, and an aspect stating what the module is that nothing read, are both a module whose request went unanswered with nothing said about it.
- **Where a rendered object came from.** Every object a module transformer renders carries the instance label and the aspect's name, so an object that belongs to no component is still traceable to the aspect that asked for it and to the module trait behind that.
- **An aspect refusal names its subject.** An aspect with no trait, an aspect contributing a matching key of its own, and a spec key no attached trait declares each fail at the aspect, naming the module and the aspect key, rather than somewhere inside the render.
- **Coverage before any module exists.** Because the contract inventory covers module traits (D14), a platform reports that an enabled catalog publishes a module trait no enabled module transformer requires, with no module in hand.

## Semver Impact

**Is this a breaking change for any consumer? If so, what's the backwards-compatibility plan?**

Additive throughout. Core gains three definitions, an optional `#aspects` map on `#Module`, a module-transformer map on `#Catalog` and its fold on `#Platform`; `#ModuleInstance` does not change, and a module, catalog or platform that declares no aspect and no module transformer observes nothing. The library gains a matching pass. No catalog gains a member (D15), so no published vocabulary changes and no module in the wild renders differently. `semver` is set at promotion; the expected value is `minor`.

## Deprecation

**What gets removed and when? What replaces it?**

Nothing is removed and nothing is deprecated. `#components` and component traits keep their meaning exactly; an aspect is a second unit beside them, never a replacement for one. The workarounds this entry displaces stay legal: a label or annotation on `#Module.metadata` still means whatever its reader agrees it means, and a component trait standing in for a module-wide concern still renders. Retiring one of those is a catalog's decision about its own vocabulary, made under the catalog's API versions, and no catalog publishes a module trait under this entry (D15).

## Rollback

**If this lands and proves bad, what's the rollback story?**

- **Core.** Additive definitions and one optional map. A module that declares no aspect is unaffected by their presence or their removal.
- **Library.** The aspect pass is a second matching pass emitting into the same output set. Removing it renders exactly today's output for a module that declares no aspect, and silently drops the module-scoped objects for one that does. That is why the inventory coverage (D14) lands with the pass rather than after it: without it, a rollback is invisible to the module author.
- **Catalogs and modules.** Nothing to withdraw. No catalog member ships under this entry (D15), so no published vocabulary has to be pulled and no module in the wild is carrying an aspect that would stop rendering.

## Cross-Repo Coordination

**Which repos must coordinate, and what constrains the order?**

Constraints only; landings are logged in this entry's `delivery.yaml`.

- **Core before the library.** The kernel cannot match an aspect core does not define, and the inventory cannot cover a module trait that has no shape.
- **The inventory lands with the pass, not after it.** D14 is what makes an unhandled demand visible; shipping the matching pass first would render module-scoped objects with no way to report the ones nobody handles.
- **Nothing waits on a catalog.** The delta is exercised by fixtures (D15), so no catalog release gates this entry. The first catalog member ships with the entry that consumes it, which is entry 0027 for the offering declaration and entry 0009 for lifecycle.
