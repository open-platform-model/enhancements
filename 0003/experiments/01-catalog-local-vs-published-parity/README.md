# 01-catalog-local-vs-published-parity — OPM Module Publishing Workflow

Status: Concluded

Pins: OQ13 (where does a catalog's version come from under D4) — challenges enhancement 0001 D8 + D9, which D7 brought into this entry's scope

## Hypothesis

Under enhancement 0001's catalog publishing method (a `*"0.0.0-dev"` sentinel in the committed tree plus publish-time stamping into a temp build dir, D8 + D9), a catalog resolved from a **local checkout** produces different primitive FQNs than the **same catalog resolved from the registry** — because the FQN interpolates the version and the two trees carry different versions. Under a strict-committed-version method (0003 D3/D4 applied to `#Catalog`), the two are byte-identical.

This matters because catalog FQNs are the key transformer matching runs on, and `cue.mod/local-module.cue` `replaceWith` onto a local catalog checkout is a sanctioned OPM dev workflow — so the divergence is reachable in normal use, not just in theory.

## Setup

Everything is self-contained under this directory; nothing outside it is read or modified.

Two throwaway catalog modules, each a real CUE module publishable to the local dev registry:

- `catalog_a/` — **Method A** (status quo). `identity/identity.cue` declares `Version: string | *"0.0.0-dev"`. Mirrors `catalog_opm/src/identity/identity.cue` as of 2026-07-25. Published via the D9/D19 flow: copy to a temp build dir, write `identity/version_override.cue` pinning the concrete SemVer, then `cue mod publish`.
- `catalog_b/` — **Method B** (strict). `identity/identity.cue` declares `Version: "1.0.0"` — concrete, committed. Published directly from the committed tree; nothing is stamped.

Both expose `CatalogFQN` and `FooTransformerFQN` built by the same interpolation the real schema uses (`core/src/catalog.cue:64` shape `"\(modulePath)@\(version)"`, and the primitive form `"\(modulePath)/\(name)@\(version)"`). The transformer is reduced to just its FQN string — the full `#ComponentTransformer` shape is irrelevant to this claim and is exercised in experiment 02.

- `consumer/` — a third module that imports **both** catalogs by registry reference (`testing.opmodel.dev/exp0003/cat_{a,b}@v1`) and surfaces the FQNs it observes.
- `run.sh` — driver: evaluates both source trees locally, publishes both (A stamped, B direct), then evaluates the consumer against the registry and prints both sets.

Registry namespace `testing.opmodel.dev/exp0003/` is throwaway; `CUE_REGISTRY` maps it to `localhost:5000+insecure`. `.build/` is gitignored.

## Run

```bash
bash run.sh              # publishes at v1.0.0 by default
VERSION=v1.2.3 bash run.sh
```

Requires a registry at `localhost:5000` (the driver preflights and exits non-zero if absent).

## Outcome

Observed 2026-07-25 with cue v0.17.1 against a live registry at `localhost:5000`.

| Method | Local source checkout | Resolved from registry | Parity |
| --- | --- | --- | --- |
| **A** — sentinel + stamping | `…/cat_a/transformers/foo@0.0.0-dev` | `…/cat_a/transformers/foo@1.0.0` | **DIVERGE** |
| **B** — strict committed | `…/cat_b/transformers/foo@1.0.0` | `…/cat_b/transformers/foo@1.0.0` | **IDENTICAL** |

Catalog-level FQNs diverge the same way (`…/cat_a@0.0.0-dev` local vs `…/cat_a@1.0.0` published).

`diff -r catalog_a .build/cat_a` reports `Only in .build/cat_a/identity: version_override.cue` — confirming 0001 D9's claim that the source tree is left byte-clean, and simultaneously confirming that **published bytes ≠ source bytes** for method A. Method B publishes the committed tree unmodified, so artifact bytes equal source bytes.

**Hypothesis held.** Method A's divergence is real, reproducible, and reachable through the sanctioned local-dev workflow: every primitive FQN in a locally-resolved catalog carries `0.0.0-dev` while the published artifact carries the release version. Because transformer matching keys off these FQNs, a module rendered against a local catalog checkout matches a *different key space* than the same module rendered against the published catalog. Method B has parity by construction — there is no second version for the two trees to disagree about.

**Implications:**

1. This is a stronger argument against the sentinel than OQ7's original framing ("a placeholder might silently ship"). The placeholder does not merely *risk* shipping — under method A, local and published evaluation are *guaranteed* to disagree, and the disagreement lands precisely on the identifier used for matching.
2. It is the catalog-side analogue of the `#Module` failure in `01-problem.md`: an identity computed inside CUE cannot observe the tag it was published under, so any scheme where the file and the tag differ makes the in-file identity a lie.
3. Method A's divergence is invisible to `cue vet` on either tree — both vet clean. Only a cross-tree comparison like this one surfaces it, which is why it survived enhancement 0001's experiment 04: that experiment measured that stamping *works* (source tree stays clean, versions propagate), never whether local and published agree.
