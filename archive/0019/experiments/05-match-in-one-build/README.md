# Experiment 05: match-in-one-build

Status: Concluded

## Hypothesis

Matching can move into the render build without losing fidelity, provided the glue reports failures **as data rather than as bottom**: a CUE expression of the three rungs (`library/opm/compile/match.go`'s FQN-lookup, always-unify, predicate) produces the same pairs the kernel produces on the same fixture, the D30 provenance carve-out proves unnecessary because one build cannot diverge on provenance, D28's fail-closed demand resolution is expressible as an assertion over computed data, and one failing pair does not prevent the other pairs from rendering.

This is the executable form of the four undecided items in `02-design.md`'s **What matching costs** section, which the design states in prose and no open question currently tracks. Experiment 01 deliberately modelled only the predicate rung and wrote down, in its own comments, exactly what it was not modelling. This experiment is the other three rungs.

### Why this is one experiment and not three

The protocol's one-concept rule is real, and this hypothesis names four things. They are one concept because they are all decided by **the shape of the glue**, not by four independent mechanisms: whether match verdicts, unify conflicts, missing FQNs and unresolved demands live in a `diagnostics:` field or are allowed to become `_|_` is a single authoring choice, and every one of the four claims is a consequence of it. Testing them separately would mean writing the same glue three more times and would still not answer the only question that matters, which is whether one shape satisfies all four at once.

The split trigger stated in the draft (diagnostics-as-data requiring a `core` schema addition) did **not** fire: the glue needed no schema change anywhere. One boundary of the data contract was found instead and is recorded in the outcome rather than split out, because it is a property of CUE, not a proposal.

## Setup

One CUE module, `experiments.opmodel.dev/0019/match-in-one-build@v0`, pinned to `opmodel.dev/core@v2.0.0-alpha.4` and `opmodel.dev/catalogs/opm@v2.0.0-alpha.3` — the same builds experiments 01 and 02 pinned, and the same catalog build `library/modules/opm_platform` subscribes, so the vendored kernel record and the CUE side evaluate the same bytes. The same registry deviation experiment 01 recorded applies: both pins are immutable published versions resolved from GHCR rather than vendored bytes.

| Path | Role | Copied from |
| --- | --- | --- |
| `matchdef/match.cue` | **the glue under test**: all three rungs plus D28 demand resolution as one `#Match` definition, laid out rung by rung against `match.go`; every verdict is a public data field (`pairs`, `missing`, `unresolved`, `unifyFailures`, `warnings`, `unmatchedComponents`, `resolved`) | authored here |
| `web_app/` | the real module fixture | `experiments/01-purecue-render-flow/web_app/`, unmodified |
| `opm_platform/` | the D5 platform: transformer map arrives by import, `#composedTransformers` is a fold | `experiments/02-platform-authority-mvs/platform/`, unmodified |
| `healthy/render.cue` | experiment 01's instance + `#Match` instantiation + render-as-data; carries the claim-1 and claim-2 assertions as in-file unifications | instance copied from `experiments/01-purecue-render-flow/instance.cue` |
| `localcat/localcat.cue` | synthetic catalog: one member per failure class (orphan resource, posture-unstated trait, conflicting-required-copy transformer, output-conflict transformer, output-incomplete transformer), fqns under `testing.opmodel.dev` | authored here |
| `broken/missing/` | claim 3, resource half: demand with an empty bucket; `gate/` subpackage carries the in-build refusal | authored here |
| `broken/unstated/` | claim 3, trait half: unhandled trait, posture unstated | authored here |
| `broken/conflict/` | claim 2 negative case: genuinely conflicting required copy | authored here |
| `broken/pair/` | claim 4: healthy instance + one error-style and one incomplete-style sabotaged pair | authored here |
| `expected/pairs.json` | **the vendored kernel record**: the real kernel's `MatchPlan` on the same fixtures, captured 2026-08-19 | output of `capture/` |
| `capture/` | Go recorder; `pairs` runs the real kernel (mirroring `flow_integration_test.go`'s setup byte for byte), `probe` measures Go-API readability of `diagnostics` beside a failing gate. Deliberately imports the library — it is the recorder of kernel behaviour, not part of the claim; the vendored JSON is the moment-in-time record | authored here |
| `run.sh` | the verdict table: 18 rows, one per readout | authored here |

Three CUE semantics questions were probed with `cue v0.17.1` before the glue was written, because the glue's design rests on them: comprehension guards DO resolve defaults (`if x` where `x: bool | *true` takes the `true` branch); `(a & b) == _|_` DOES detect nested struct conflicts with no false positives; and an INCOMPLETE value is **not** `== _|_` (only a genuine error is). The third is the boundary the outcome records.

## Run

```bash
export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
bash run.sh                            # the full 18-row verdict table + Go API probe

# individual readouts
cue vet -c ./healthy/                  # exits 0
cue eval ./healthy/ -e pairs           # the five pairs
cue eval ./broken/missing/ -e diagnostics
cue vet ./broken/missing/gate/         # the in-build refusal
cue vet -c ./broken/unstated/          # the incomplete-value refusal
cue eval ./broken/conflict/ -e diagnostics
cue eval ./broken/pair/ -e failedPairs -e renderedKeys

# re-record the kernel side (writes ../expected/pairs.json)
(cd capture && go build . && ./capture pairs > ../expected/pairs.json)
(cd capture && go run . probe)         # Go-API gate coexistence
```

Pinned to `cue v0.17.1`, the same version `library/go.mod` pins for the SDK. `run.sh` last run 2026-08-19: **18 passed, 0 failed**.

## Outcome

**Hypothesis held**, on all four claims, with one measured boundary and two findings the draft did not predict.

**Claim 1 held: same pairs.** All three rungs plus the bucket index in ~230 lines of commented CUE produce exactly the kernel's pair set on the web_app/opm_platform fixture — five pairs, compared against the vendored kernel record rather than against a re-derivation. Every other verdict surface agrees too: `missing`, `unresolved`, `unmatched` and the warning set are empty on both sides. Rung 1's reverse index (required ∪ optional, `opm/materialize/index.go`) is a two-comprehension fold, which closes the latent divergence experiment 01 recorded when it looped every transformer instead of the buckets.

**Claim 2 held: the D30 carve-out is a federation artifact.** The always-unify rung runs as plain `&` with no provenance exclusion and disqualifies nothing on the healthy fixture. The reason is stated directly rather than only by absence: the component's embedded primitive copy and the transformer's embedded required copy resolve to the same catalog bytes in one build, so `metadata.catalogVersion` and `metadata.description` — the two fields D30 exists to excuse — are **equal**, asserted by in-file unification. The negative case pins that unification was not disabled: a required copy narrowed to a container name the component's copy excludes is disqualified by plain `&`, reported as data (`unifyFailures` names the component, the transformer and the conflicting FQN), while the unnarrowed candidate in the same bucket still pairs and the demand still resolves. In the collapse, `excludeProvenance` and its denylist are **deleted, not ported**, and the parity harness loses its one stated exemption.

**Claim 3 held, with the boundary measured.** The resource half is fully data: an empty-bucket demand yields a `missing` row (rung 1) and an `unresolved` row with an empty `disqualified` list (D28), `resolved` computes `false`, and the component's healthy sibling demand still pairs — refusal evidence without poisoning. The in-build form of `compile/module.go`'s gate is one unification (`resolved & true`) and refuses the render with `conflicting values false and true`. Where the gate can live is now measured on both surfaces: **through the Go API, `diagnostics` stays fully readable and concrete via `LookupPath` while the gate is failing** (probed on the built instance, `value.Err()` non-nil), so the kernel can have the in-build gate and decode `oerrors.{MissingFQN, UnresolvedDemand, UnifyError}` from a `diagnostics:` field at once; the CLI cannot — `cue eval -e diagnostics` validates the whole instance first and reports the gate's conflict instead of answering. The boundary is the trait half's unstated posture: classifying it means evaluating a plain `bool`, which is incomplete, not an error, so `== _|_` cannot see it and the posture-dependent lists stall symbolically. The refusal still happens — `cue vet -c` refuses naming `core/trait.cue`'s own `optional: bool` declaration — which is fail-closed **as bottom rather than as data**, and it is contained: `pairs` stays readable beside the stall. D28's unstated-posture rule therefore survives the collapse, but its diagnostic cannot be a `diagnostics:` row without either a posture-statedness probe CUE does not offer or a publish-side gate that makes unstated posture unrepresentable.

**Claim 4 held, with the error/incomplete asymmetry pinned.** Two sabotaged transformers pair with `config` through the real ConfigMaps bucket (matching cannot see output sabotage, which is the point). The error-style failure — output constraining the component name to a value it never has, which lands as `core`'s `{...} | [...{...}]` output disjunction emptying — is named in `failedPairs` as data while all five healthy pairs render concretely beside it. The incomplete-style failure — a declared output field nothing fills — is invisible to `== _|_`, lands in `rendered` non-concrete, and is caught by `cue vet -c` at a path **naming the pair key** (`rendered."config :: …incomplete-pair-transformer@0.0.1".metadata.name`). So failure isolation as data covers exactly the class of failures that are errors; incompleteness degrades to a build-level refusal that is still per-pair attributable by path. A design that wants incompleteness as data would compute per-pair concreteness, which is a validation walk the glue should not hand-roll — the honest statement is that the kernel's render loop keeps owning the concreteness check per pair, as it does today via `Validate`.

### Two findings beyond the claims

**The provenance stamp refuses cross-catalog injection.** Unifying a synthetic transformer into `catalog.#transformers` is refused outright: the catalog's pattern constraint stamps its own `modulePath`/`catalogVersion` onto every member (0010 D25), and the foreign member conflicts. Multi-catalog composition is therefore a map **fold** (comprehension copy), never a unification into one catalog's member map — which is both a constraint on the collapse's glue and a live demonstration that the stamping 0015 D1 builds its contract maps on actually enforces provenance.

**The label predicate's `&` covers what the kernel's `String()` skips.** Kept from experiment 01 and now load-bearing in the glue: the predicate unifies label values, so every type `#LabelsAnnotationsType` admits is compared, where `match.go`'s `labelPairs`/`missingMapLabels` silently skip non-strings. The two agree on everything the catalog ships today.

### What this discharges in the design

The four bullets in `02-design.md`'s **What matching costs** now have measured answers: D30 is deleted rather than ported (with the negative case pinned); D28 fail-closed survives with its refusal expressible in-build and its evidence as data, except the unstated-posture diagnostic, which stays a bottom; error quality for a failed pair is `unifyFailures`' conflicting-FQN row plus, at render, the empty-disjunction bottom — recovering the verbatim `oerrors.UnifyError` cause still needs a second diagnostic evaluation if wanted, unchanged from the draft's expectation; and failure isolation is a property the data-shaped glue delivers for error-class failures and degrades gracefully for incompleteness. The D32/D37 single-provider guard and `indexCatalogs`' cross-build collapse remain multi-build machinery whose fate follows D5, as the draft scoped.

**Hypothesis held.** One glue shape — verdicts as data, gate as one unification, bottoms confined behind `== _|_` guards — satisfies all four claims at once on `cue v0.17.1`, with the unstated-posture diagnostic and incomplete-output detection as the two measured places where the data contract hands back to the build error, both still attributable.
