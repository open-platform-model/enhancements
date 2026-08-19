# Experiment 05: match-in-one-build

Status: Draft

## Hypothesis

Matching can move into the render build without losing fidelity, provided the glue reports failures **as data rather than as bottom**: a CUE expression of the three rungs (`library/opm/compile/match.go`'s FQN-lookup, always-unify, predicate) produces the same pairs the kernel produces on the same fixture, the D30 provenance carve-out proves unnecessary because one build cannot diverge on provenance, D28's fail-closed demand resolution is expressible as an assertion over computed data, and one failing pair does not prevent the other pairs from rendering.

This is the executable form of the four undecided items in `02-design.md`'s **What matching costs** section, which the design states in prose and no open question currently tracks. Experiment 01 deliberately modelled only the predicate rung and wrote down, in its own comments, exactly what it was not modelling. This experiment is the other three rungs.

### Why this is one experiment and not three

The protocol's one-concept rule is real, and this hypothesis names four things. They are one concept because they are all decided by **the shape of the glue**, not by four independent mechanisms: whether match verdicts, unify conflicts, missing FQNs and unresolved demands live in a `diagnostics:` field or are allowed to become `_|_` is a single authoring choice, and every one of the four claims is a consequence of it. Testing them separately would mean writing the same glue three more times and would still not answer the only question that matters, which is whether one shape satisfies all four at once.

The split trigger is stated in advance: if the diagnostics-as-data half turns out to require a `core` schema addition (a `#diagnostics` surface on `#transform` or on the platform), that half leaves this experiment and becomes experiment 06, because it stops being a glue question and becomes a schema proposal.

## Setup

> **Draft.** Nothing has been built yet. This section is the plan; it is rewritten as a record of what was actually copied and measured when the experiment moves to `Running`.

A single CUE module, built the same way experiment 01 was, with the glue extended from one rung to three and a fixture set chosen so that each failure class fires at least once.

| Path | Role |
| --- | --- |
| `cue.mod/module.cue` | pinned to the same published builds experiment 01 used, so the two are directly comparable |
| `match.cue` | the glue: all three rungs plus demand resolution, laid out phase by phase against `match.go` so a reviewer can read them side by side |
| `instance.cue`, `web_app/` | the real instance and module, copied from `experiments/01-purecue-render-flow/` |
| `opm_platform/` | the platform, copied from `experiments/02-platform-authority-mvs/platform/` (the D5 shape, so the transformer map arrives by import) |
| `broken/` | the deliberately-failing fixtures below, kept in their own package so a healthy build and a poisoned one can be evaluated separately |
| `expected/pairs.json` | the kernel's own answer for the healthy fixture, captured once from a `library` flow test run and vendored, so the comparison is against recorded kernel output rather than against a re-derivation |

**Copied, never referenced.** The fixtures come in as bytes from experiments 01 and 02 and from `library/testdata/modules/web_app/`. The same registry deviation the earlier experiments recorded applies: `opmodel.dev/core@v2` and `opmodel.dev/catalogs/opm@v2` resolve from GHCR at exact published versions.

### The four claims, and the fixture that fires each

**Claim 1: same pairs.** The three rungs in CUE, run against the healthy fixture, produce the pair set in `expected/pairs.json` exactly. Rung 1 is the part experiment 01 skipped: the kernel only considers transformers sitting in a `#matchers.{resources,traits}[fqn]` bucket built from required union optional (`opm/materialize/index.go`), while experiment 01 looped every transformer in the catalog. Building that reverse index in CUE and looping only the buckets is what closes the one latent divergence experiment 01 named.

**Claim 2: the D30 carve-out is a federation artifact.** `match.go`'s always-unify rung drops CUE diagnostics located at `metadata.catalogVersion` or `metadata.description` because provenance changes per catalog release by construction, so a component body and a transformer's embedded required copy from *different builds* always disagree there. In one build both come from the same catalog bytes. The test is direct: express the rung as plain `&` with no exclusion, and check that no pair is disqualified on the healthy fixture. If that holds, the carve-out is deleted rather than ported, and the parity harness loses the one stated exemption `02-design.md` reserves for it. A second fixture pins the negative case: a component whose primitive body genuinely conflicts with a transformer's required copy must still disqualify, so the claim is "provenance cannot diverge", not "unification was disabled".

**Claim 3: fail-closed survives.** D28 refuses a render when a declared resource's bucket is empty or fully disqualified, or when an unhandled trait's `optional` posture is false or unstated. All seven of `web`'s traits are `optional: true`, so the healthy fixture cannot exercise this; `broken/` carries a component with an unstated-optional unhandled trait and one with a demanded FQN no transformer provides. Both must refuse. The open sub-question this answers concretely: the refusal names a list rather than a field path, so whether `oerrors.{MissingFQN,UnresolvedDemand,UnifyError}` become values decoded from a `diagnostics:` field rather than constructed in Go becomes a decision with evidence under it.

**Claim 4: failure isolation.** Not stated anywhere in the entry today, and the sharpest consequence of the collapse. Today each pair renders independently, so one broken transformer fails one pair attributably and the rest still render. In one build, whether a single bad pair poisons the whole evaluation depends entirely on whether the glue lets a bottom propagate out of a comprehension. The fixture is a healthy instance plus one component that fails each way in turn; the readout is whether `rendered` still yields the other pairs concretely, and whether the failure is attributable to a `(component, transformer)` key or only to the build. A design that can only report "the build failed" is a real regression against today's behaviour and needs to be known before the glue shape is fixed.

### What this experiment does not model

- **Error message quality.** CUE can answer `(a & b) == _|_`; it cannot hand back the conflict message `oerrors.UnifyError` carries verbatim. This experiment records what *is* recoverable from a failed unification inside the build; whether a failed pair gets re-run in a second diagnostic build to recover the message is a design decision the result informs rather than settles.
- **Cost.** Moving matching into the build adds evaluation work. Experiment 04 measures an execute-only build deliberately, so the delta is attributable; measuring it here would make a two-variable result. If claim 1 holds, re-running arm C of experiment 04 against this glue is the natural follow-up.
- **The multi-build machinery.** `indexCatalogs`' same-FQN cross-build collapse and the D32/D37 single-provider guard are only reachable when several builds are composed. Whether they survive or become vacuous follows from the same question claim 2 asks, and is recorded as a consequence rather than tested here.

## Run

> **Draft.** These are the intended commands; they do not exist yet.

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
cue vet -c ./...                       # healthy fixture must be fully concrete
cue eval -e pairs                      # compare against expected/pairs.json
bash run.sh                            # every fixture, including the failing ones, with a verdict table
```

Pinned to `cue v0.17.1`. `run.sh` prints one row per fixture: expected verdict, observed verdict, and for the failing fixtures whether the other pairs still rendered.

## Outcome

{Placeholder. Fill when the experiment moves to `Running`; finalise with an unambiguous held/refuted statement at `Concluded`, and link the result back into `02-design.md`'s **What matching costs** section, which is where the claims are currently stated as undecided.}
