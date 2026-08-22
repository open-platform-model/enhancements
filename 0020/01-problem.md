# Problem Statement — Contract Promotion and Retirement

Enhancement 0010 gave every contract-bearing primitive its own API version and keyed the contract on it (D4, D25), then borrowed the Kubernetes ladder so the additive-only promise could bind at beta and GA while staying off at alpha (D27, D34). The ladder works. What is missing is every rule about **movement along it**: a contract can be born at a level and it can be broken into a new one, but nothing describes a contract that has earned promotion, and nothing describes a contract leaving the catalog at all.

## Current State

A contract's level is fixed at the moment its author picks an `apiVersion`, and the only sanctioned way to change it is to break something. D27 states the rule in one direction only: removing a field, narrowing a type or changing a default "requires a new `apiVersion`, which may ship alongside the old one in the same catalog build". D34 repeats it for the level: a break "requires a beta bump (`v1beta1` → `v1beta2`), which may ship beside its predecessor in one build".

Coexistence is therefore already blessed, and enhancement 0010 D49's `<kind>/<apiVersion>/` filing already gives two levels two directories. The machinery for two levels in one build exists and is in use.

The compatibility gate (0011 D9, with predecessor selection settled by 0011 D23) keys its lookup on `name` plus `apiVersion`. A contract at a level that has never been published finds no predecessor and passes.

Contracts are not enumerable **as values**. `#Catalog` carries exactly one member map, `#transformers`, and `core/src/catalog.cue` says so in its own comment: "Resources / Traits / Blueprints are surfaced transitively via each transformer's required/optional maps." Enhancement 0015 D1 adds the three sibling maps and is `accepted`, not yet delivered. The publish tooling already works around this: measured 2026-08-22, it enumerates members by walking enhancement 0010 D49's `<kind>/<apiVersion>` filing on the filesystem, having rejected the value walk because `#transformers` reaches about half the contract members and no blueprints.

## Gap / Pain

**There is no promotion path.** A contract whose shape has been right for a year has no way to say so. Measured 2026-08-22, `catalog_opm/src` holds 3 members at `v1alpha1`, **41 at `v1beta1`**, 26 at `v1` and 1 at `v2`. Beta is the largest tier and nothing in the system moves it. D34 assigned `v1beta1` to the two mainline catalogs on evidence that their history was "overwhelmingly additive" (715 field additions against 30 removals), which is to say: on evidence that they had already behaved better than the level they were being given.

**The promotion that does happen is unchecked.** Because the gate keys on `name` plus `apiVersion`, publishing `container@v1` finds no predecessor and passes trivially. A build may ship `container@v1` whose shape has nothing to do with `container@v1beta1`, and the tooling reports success. Promotion is not merely undescribed; it is a hole in an otherwise closed gate.

**Promotion is expensive when it does happen.** The level is a component of the key and the match path is exact-string (`compile/match.go:290`, a bare `LookupPath` with no fallback), so `container@v1beta1` becoming `container@v1` is a different key. Every consuming module changes an import and every provider adds a `requiredTraits` entry, in one coordinated flag day per contract. 0015 OQ5 already names this cost for the cross-catalog case and calls it "a recurring cost rather than a one-off".

**Nothing refuses a removal.** 0011 OQ10 states it plainly: "What refuses the removal of a beta or GA member? Nothing does." D23's backward scan closed the remove-then-readd hole, but a build that simply drops a member ships clean, and the question's own text notes the evidence is built into the test suite: "the hermetic remove-then-readd test's *removing* build passes the full gate set on its way to seeding the case."

## Concrete Example

`catalog_opm` ships `opmodel.dev/catalogs/opm/resources/container@v1beta1`. Its shape has not changed incompatibly since bootstrap. Twelve modules across the fleet attach it, and eight transformers require it.

The author decides it has earned GA.

Today, three things happen, none of them good.

1. **The bump is a flag day.** Publishing `container@v1` produces a key nothing demands. Every one of the twelve modules must change its import and republish, and the eight transformers must change their `requiredResources`, and none of it can be staged: on the release where the catalog stops shipping `@v1beta1`, every module still on it fails to match with a `MissingFQN` naming a key that no longer exists anywhere.

2. **Or the author never does it,** which is what actually happens, and `container` sits at beta permanently alongside forty others. The tier stops carrying information: a consumer reading `v1beta1` cannot distinguish "still moving" from "nobody got around to it".

3. **And if the author does bump, nothing checks the result.** `container@v1` could drop a required field relative to `container@v1beta1` and publish green, because the gate has no predecessor at `v1` to compare against. The consumer discovers it at match time or, for a changed default, at render time on an incomplete value, which `0010/experiments/02` measured as the one class no consumer-side check catches.

Now the mirror case. The author instead deletes `container@v1beta1` outright, having decided it was a mistake. The build publishes green. Twelve modules break on their next render, each reporting a missing FQN, and nothing anywhere records that the contract ever existed or why it went away.

## User Stories

- **As a catalog author,** I want to promote a contract that has proved itself, without coordinating a flag day across every consumer at once.
- **As a catalog author,** I want the tooling to refuse a promotion that quietly breaks the level it promotes from, the same way it already refuses a break inside a level.
- **As a module author,** I want a contract I depend on to keep working while I migrate at my own pace, and I want a machine-readable pointer at its successor when one exists.
- **As a module author,** I want a removed contract to produce a diagnostic that names when it went and what replaced it, rather than a missing key.
- **As a platform operator,** I want to know that a catalog upgrade cannot silently withdraw a contract my instances depend on.
- **As a reader of a catalog,** I want a contract's level to mean something, which requires that a contract cannot sit at beta indefinitely by inattention.

## Why Existing Workarounds Fail

**Publisher discipline.** The standing objection applies unchanged: 0010 D13 argued it against D4, and 0010 D17 records that "a third-party catalog author has no reason to copy a convention nothing checks." A promotion policy nothing enforces is a note in a README.

**Coordinated flag days.** They work exactly once, for one contract, with a small and cooperative fleet. Against 41 beta contracts and a design that expects "a well-known contract set with an experimental on-ramp" (0015 OQ5), the cost is recurring and it scales with adoption, which is the wrong direction.

**Leaving everything at beta forever.** This is the current trajectory and it is not neutral. It empties the ladder of meaning, and it defers the promotion cost rather than removing it: the fleet gets larger every month, so the flag day gets more expensive the longer it is postponed.

**Letting a module demand a bare name and resolving the level at match time.** This is the version join enhancement 0010 D4 removed, reintroduced on the consumer side. What a module receives would depend on what the platform happens to carry. Rejected in this entry's design as a non-starter rather than left as an option, because it is the intuitive answer and it undoes the identity reshape.

**The Kubernetes deprecation window.** 0010 D34 rejected importing it, with a reason that holds: "Kubernetes's exist because cluster upgrades force version moves on a support lifecycle, and under D14 a platform moves only when someone edits `version:` in its own source, so any window would be arbitrary." That rejection is correct and this entry does not reopen it. It answers a different question, which is stated in `02-design.md`.
