# Problem Statement — Initialize a Module Instance Package from a Published Module

## Current State

Deploying a published OPM module requires a **module instance package**: an on-disk CUE package whose evaluation produces a `core.#ModuleInstance` — an `instance.cue` that imports the published module and the core schema, states `metadata.name` / `metadata.namespace`, embeds `#module: <imported module>`, and a `values:` struct satisfying the module's `#config`. `opm-kind-demo/web_app/instance.cue` is the canonical example of the shape; `library/opm/helper/loader/file` (`LoadInstancePackage`) is the code path that consumes it, both from the CLI (`opm instance build <instance.cue|dir>`) and from the operator's ModulePackage path.

Nothing creates that package. Today there are exactly three adjacent capabilities, none of which produces an on-disk instance package from a published module:

- **`opm module init`** (`cli/internal/cmd/module/init.go`) scaffolds a new *module* — the author-side artifact — from embedded templates (`cli/internal/templates/{simple,standard,advanced}`). It knows nothing about published modules or instances.
- **`synth.Instance`** (`library/opm/helper/synth/instance.go`) synthesizes an *in-memory* instance package from an acquired module — it overlays a generated `instance.cue` (and optionally `values.cue`) into the module's staged source tree and evaluates it in one build. It is deliberately ephemeral: nothing is written to disk, and it explicitly refuses to fall back to `debugValues` ("that is a frontend policy concern" — the policy this enhancement now defines for one frontend).
- **`#Module.debugValues`** (`core/src/module.cue:105`) carries concrete example values "for testing and debugging". The CLI uses it for `opm module build` dry-runs, but no tool ever surfaces it to a *deployer* as a starting point for their own values.

So the deployer-facing gap: a user who finds a published module (an OCI artifact in a CUE registry, e.g. `ghcr.io/open-platform-model/opmodel.dev/modules/jellyfin` at some tag) and wants a committable, editable deployment definition has to hand-write the whole package.

## Gap / Pain

Hand-writing an instance package requires knowledge the user should not need up front:

1. **The package boilerplate** — the correct `cue.mod/module.cue` (module path, language version, the module and core as dependencies with correct majors and pinned versions), the correct import lines, the `core.#ModuleInstance` embedding, the `#module:` wiring. Every line is mechanical, and every line is an opportunity for a version/major mismatch that surfaces as an opaque CUE resolution error.
2. **The values shape** — what `#config` actually accepts. The contract lives inside the published artifact; without scaffolding, the user's discovery path is reading the module source or iterating on `cue vet` errors.
3. **A sensible starting point** — which values to set first. The module author already knows this (they wrote `debugValues` to exercise the module), but that knowledge is trapped in a field whose *purpose* is debugging, not onboarding: `debugValues` may legitimately contain test-only junk (throwaway hostnames, debug log levels, dummy credentials) that the author would never want templated into a user's deployment file.

The third point is why this enhancement touches `core/` and not only `cli/`: there is no field on `#Module` through which an author can say "this is what a new deployment of my module should start from". `debugValues` is the closest thing that exists, which makes it the right *default* — but defaulting to it forever would quietly redefine its meaning and punish modules whose debug values are genuinely debug-only.

## Concrete Example

The `jellyfin` module is published as `opmodel.dev/modules/jellyfin@v3`, version `3.0.0`. Its `#config` (`modules/jellyfin/module.cue`) covers image, port, PUID/PGID, timezone, storage volumes, optional hardware transcoding, optional HTTPRoute. A user wanting to deploy it today must produce, by hand:

```text
jellyfin-instance/
  cue.mod/module.cue    # module path? language version? which deps, which versions?
  instance.cue          # imports core@v2 and jellyfin@v3, #ModuleInstance, #module wiring
  values.cue            # a values: struct satisfying #config they have never seen
```

Their realistic path is copying `opm-kind-demo/web_app/instance.cue` and mutating it — against a different module with a different config contract, a different major, and a possibly different core line. The failure modes (wrong core major for the module, unpinned dependency, values that don't satisfy `#config`) all surface late, as CUE errors, instead of being impossible by construction.

What the user should be able to run instead:

```text
opm instance init opmodel.dev/modules/jellyfin@v3 --version 3.0.0 --name jellyfin --namespace media
```

and get that directory generated — boilerplate correct by construction, `values.cue` pre-populated from what the module author designated for exactly this purpose (falling back to `debugValues` when they designated nothing).

## User Stories

- As a **deployer** (platform user consuming published modules), I want to point the CLI at a module OCI reference and tag and get a runnable, committable instance package so that my first `opm instance build` succeeds before I have edited anything. Today: I hand-assemble three files from an example belonging to a different module.
- As a **module author**, I want to control what a freshly initialized instance's `values.cue` contains so that new users start from my intended defaults rather than from my debug fixture. Today: no field on `#Module` carries that intent; `debugValues` is the only values-shaped example and its contract is debugging.
- As a **GitOps operator**, I want initialized instance packages to be well-formed on-disk packages so that the same directory feeds `opm instance build`, `opm instance apply`, and the operator's ModulePackage path without rework. Today: only hand-written packages exist, with hand-introduced drift.

## Why Existing Workarounds Fail

- **Copy an example instance package and mutate it.** Carries the donor's core major, module major, and values shape into a foreign module. Every mismatch is discovered at `cue` evaluation time, not at creation time.
- **`opm module build --name --namespace` (synth path).** Validates that the module deploys, but is deliberately fileless — there is nothing to edit, commit, or hand to the operator. It also refuses `debugValues` fallback by design, so it answers "does this module render?", not "give me my deployment definition".
- **Read the module source to learn `#config`, then write values from scratch.** Works, but requires registry-browsing and CUE fluency for what should be a one-command onboarding step — and re-does, per user, work the module author already did once in `debugValues`.
