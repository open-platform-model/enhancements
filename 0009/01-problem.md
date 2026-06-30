# Problem Statement — Operational Primitives: Op, Action, Lifecycle, Workflow

This document answers the question: "Why does this enhancement need to exist?"

## Current State

OPM today is a *rendering* system. The kernel takes a declarative `#Module` (Resources, Traits, Blueprints composed into Components), matches each Component against the transformers a `#Platform` subscribes to, and emits platform-native resources. In the library this is the `opm/compile/` half of the kernel: `finalize → match → execute → emit`, producing `[]*core.Compiled`. The schema describes *what must exist*; the pipeline turns it into Kubernetes manifests.

That covers the declarative side completely. Every concern OPM models has a primitive: `#Resource` ("what must exist"), `#Trait` ("how it behaves"), `#Blueprint` ("what the reusable pattern is"). The render pipeline is pluggable along its whole length — transformers are not hardcoded in the kernel, they live in catalogs (`catalog_opm`, published as `opmodel.dev/catalogs/opm@v1`) and are pulled and composed at runtime through `#Platform.#registry` + `materialize`.

## Gap / Pain

OPM can describe *what should exist* but has no way to describe *what should happen* — no primitive for executable operations, and no engine to run them. There is no equivalent of:

- A pre-install step that waits for a dependency to be ready before the app starts.
- A database migration that must run between two deploy phases.
- An on-demand operation a developer triggers by hand (seed data, rotate a credential, build a container).
- Any state-transition hook at all (install / upgrade / uninstall).

The consequence is that everything operational falls *outside* OPM — into shell scripts beside the module, hand-written Kubernetes Jobs, manual `kubectl` runbooks, or Helm-style hooks if a chart is involved. None of these are typed, composable, or portable across the platforms OPM already targets.

The trap to avoid is **Helm's model**: a hook is an arbitrary template that renders an arbitrary Kubernetes object running an arbitrary script. It is maximally flexible and, precisely because of that, unmaintainable at scale — every chart reinvents the same operations slightly differently, the escape hatch is the front door, and the platform owner has no leverage over what runs. OPM's whole thesis is the opposite: find the smallest common denominator, make it a typed primitive, and let people *compose* upward rather than script sideways. That thesis has never been applied to operations.

## Concrete Example

A module author ships an app that needs a schema migration applied after the database is reachable but before the app rolls out, and wants a one-shot "seed demo data" operation an operator can run on demand.

Today, this is not expressible in OPM. The author writes a `migrate-job.yaml` by hand (pinned to one cluster's shape), documents the seed step as a `kubectl exec` runbook in the README, and hopes the next operator runs them in the right order. None of it is validated, none of it is reusable by the next module, and the platform team cannot see or constrain what these steps do.

What the author *should* be able to write is a typed flow composed from primitives OPM controls — a `wait` Op, then a migration `Action`, bound to the `pre-upgrade` lifecycle phase — and a separate on-demand `Workflow` for the seed step. The same `#Module` that renders to Kubernetes would also carry its operational intent, and the kernel would plan and orchestrate it the same way it already plans and renders resources.

## User Stories

- As an **application module author**, I want to declare ordered operational steps (wait, migrate, verify) as typed flows in my `#Module`, so that operations ship and version with the app instead of living in side scripts. Today: there is no primitive for this — operations live in untyped shell/YAML beside the module.
- As a **platform team operator**, I want to control the set of operational primitives authors may use and supply ready-made compositions, so that operations stay consistent and reviewable instead of every module inventing its own. Today: nothing constrains operational logic because OPM does not own it.
- As a **kernel / catalog contributor**, I want operational behavior to be pluggable and catalog-sourced (like transformers already are) rather than compiled into the kernel, so that new operations ship without a library release. Today: there is no execution half of the kernel at all.

## Why Existing Workarounds Fail

- **Shell scripts beside the module.** No schema, no composition, no reuse, no platform-level control. A migration in one module cannot be adapted by another without copy-paste.
- **Hand-written Kubernetes Jobs / Helm hooks.** Pinned to one resource shape and one platform; fire-and-forget rather than convergent under reconciliation; and they re-import exactly the "arbitrary script as a hook" pattern OPM exists to replace.
- **Manual `kubectl` runbooks.** Unvalidated prose. Ordering and preconditions live in a human's head; nothing enforces them.
- **CUE's own `tool/exec` (`cue cmd`).** Tied to the CUE CLI, not to OPM's runtime. OPM needs operations its own kernel — embedded by the CLI and the operator — can plan and execute, not operations that require the `cue` binary.
