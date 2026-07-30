# 03-provenance-operand-filter — Module and Catalog Identity

Status: Concluded

## Hypothesis

Enhancement 0010 **D26** decided that provenance is removed from the match comparison *before* unification rather than forgiven after it, and left the mechanism open as **OQ12**. Candidate **(a)** is a Go-side filter that builds both operands minus the excluded fields, leaving `core` untouched.

`experiments/02` measured candidate **(c)** — unify everything, then discard errors whose path passes through `metadata` — and got the full predicted matrix. **(a) had never been measured**, and it is not obviously equivalent: `cue.Value` is immutable and exposes no field-removal operation, so removing a field means a **syntax round-trip** (`Syntax` → edit AST → `Build`). Experiment 02's own finding 1 is the reason that matters — changing *what is fed to* `Unify` can silently drop closedness, which is how spec-only unification made case 1 pass while dropping a field the module had set.

The claim under test:

> An operand-side filter that strips provenance fields via a syntax round-trip **preserves the closedness** that makes a lagging provider fail, and therefore reproduces experiment 02's matrix.

If closedness does not survive the round-trip, candidate (a) is unavailable and OQ12 must take candidate (b), a structural split in `core`.

A second question rides along, because it decides the filter's **field list**: is `catalogVersion` alone sufficient, or must `description` go with it?

## Setup

Fixtures copied verbatim 2026-07-29 from `experiments/02-primitive-closedness-skew/` (`mod/`, `prov/`, `go.mod`, `go.sum`) — copied, never referenced, per the experiments rules. Two module roots declaring the same module path over byte-identical trees; the component loaded from `mod/`, the transformer from `prov/`, by two `load.Instances` calls sharing one `*cue.Context`.

Two fixtures are **new**, and they exist to isolate one variable:

- `catalog_v1_1_desc` — build 1.1.0 with the primitive's `description` **reworded** and nothing else changed against `catalog_v1_1`.
- `demand_11_desc` — a module authored against that build, staying inside the fields both builds share.

Paired against `supply_10`, the two sides then differ in `catalogVersion` **and** `description`, and in nothing else. A catalog author clarifying wording between builds is the most ordinary edit there is; case 8 asks whether it can break a match.

Four comparison scopes are measured for all eight cases:

| Scope | What it does |
| --- | --- |
| `whole value` | `match.go` today — no exclusion at all |
| `(c) error-path filter` | unify everything, discard errors under `metadata` — what experiment 02 measured |
| `(a) operand: -catalogVersion` | round-trip both operands without `metadata.catalogVersion` |
| `(a) operand: -catalogVersion -description` | the same, also without `metadata.description` — **the scope carrying the predictions** |

`unifyIntersection` is copied from `library/opm/compile/match.go:247-273`, with the plan-recording replaced by a returned slice and the operand filter applied between lookup and `Unify`. The `Unify(...).Validate(cue.Concrete(false))` call is copied, not approximated.

The filter renders with `Syntax(cue.All(), cue.InlineImports(true))` — `InlineImports` is required, since these values come from imported packages and an unresolved cross-package reference would not rebuild in a bare context. Two guards make a vacuous measurement impossible: the harness counts the fields it actually removed and errors if the count is zero, and it probes the rebuilt supply operand directly by unifying an undeclared field into its spec body.

## Run

```bash
bash run.sh          # fixtures vet clean, then the harness
# or just the harness:
go run .
```

## Outcome

Observed 2026-07-29, cue v0.17.1, Go 1.26.2. **8 of 8 cases behaved as predicted** under `-catalogVersion -description`.

### 1. Closedness survives the round-trip — candidate (a) is available

The decisive result. The closedness probe returned `true` on every rebuilt operand in every case, and the three cases that must fail on a contract field still do, naming that field:

| # | skew | whole value | (c) error-path | (a) -catVer | (a) -catVer -desc |
| - | --- | --- | --- | --- | --- |
| 1 | lagging provider, module **uses** `retention` | FAILS `field not allowed` | FAILS | **FAILS** | **FAILS** |
| 2 | same skew, module does not use it | FAILS on `catalogVersion` | PASSES | PASSES | PASSES |
| 3 | provider ahead | FAILS on `catalogVersion` | PASSES | PASSES | PASSES |
| 4 | same build (control) | PASSES | PASSES | PASSES | PASSES |
| 5 | provider broke the promise (narrowing) | FAILS on `schedule` | FAILS | **FAILS** | **FAILS** |
| 6 | default drift | FAILS on `catalogVersion` | PASSES | PASSES | PASSES |
| 7 | case 1 in the named-schema shape | FAILS `field not allowed` | FAILS | **FAILS** | **FAILS** |
| 8 | **description drift** (new) | FAILS on `catalogVersion` + `description` | PASSES | **FAILS** | PASSES |

Cases 1 and 7 are the ones that matter: both are the lagging-provider skew that spec-only unification got wrong in experiment 02, and both still fail after the round-trip, in both spec-body styles. `Syntax(cue.All(), cue.InlineImports(true))` → `BuildExpr` preserves the closed definition. **The hypothesis held.**

Case 6's probe is unchanged from experiment 02: `spec.backup.mode` resolves to `"delete" | "retain"` and is **not concrete**. Default drift still passes the match and still fails later at render, which is why 0011 D9's publish-side gate is not redundant.

### 2. Case 8 settles the field list, and `catalogVersion` alone is not enough

Under `-catalogVersion` only, case 8 **fails**:

```
_#def.metadata.description: conflicting values
  "Generic backup contract, fulfilled by a platform provider" and
  "Generic backup contract, fulfilled by an installed provider"
```

Two builds whose contract surfaces agree completely do not match, because someone reworded a sentence. `description` is provenance by the same argument `catalogVersion` is, and it has to be in the strip list — measured, not assumed.

### 3. What the measurement does *not* settle: (a) versus (c)

`(c)` and `(a) -catalogVersion -description` agree on all eight cases. **No fixture here distinguishes them**, and none can: the fields that would separate them are the identity fields (`name`, `modulePath`, `apiVersion`, `fqn`), and those cannot be made to disagree while the two sides still meet, because the map key *is* `fqn` and `fqn` is computed from the other three. A disagreement is structurally unreachable through `unifyIntersection`.

That cuts both ways and should be stated plainly. The argument for (a) over (c) is **not** measured correctness — it is that (c) forgives any metadata conflict by construction, so it would also forgive an identity conflict arriving by some route this fixture cannot model (a hand-written map key, a future field, a bug in FQN derivation). (a) with a **denylist** keeps that tripwire; (a) with an allowlist would give it up again, which is why the denylist form is the one that makes (a) meaningfully different from (c).

### 4. A cost of (a) that (c) does not have: the error path is rewritten

The round-trip discards the value's position in its enclosing document, so the CUE-level message changes:

```
(c)  components.web.#resources."…/backup@v1".spec.backup.retention: field not allowed
(a)  _#def.spec.backup.retention: field not allowed
```

The **field path survives intact** — `spec.backup.retention` is what matters and it is still there. What changes is the leading segment, from the component's real path to a synthetic `_#def.`.

This is mitigated rather than free: `oerrors.UnifyError` (`library/opm/errors/match.go:49-63`) already carries `Component` and `FQN` as struct fields and renders `component %q, fqn %q: %v`, so no information is actually lost — the wrapper supplies what the round-trip drops. But the raw CUE error read on its own no longer self-describes, and anything that pattern-matches on the message path would break. Worth knowing before implementing; not a reason to prefer (c).

### 5. A note on what gets stripped

The filter removes 6 field occurrences per operand pair at `-catalogVersion` and 12 at `-catalogVersion -description` — more than the two literal values, because `InlineImports` expands the primitive's *definition* alongside its instance and each carries the field. That is correct and load-bearing: stripping the instance's `catalogVersion: "1.1.0"` while leaving the definition's `catalogVersion!: #VersionType` would leave a required field with nothing to satisfy it, and `Validate(cue.Concrete(false))` would not catch it but a later concrete evaluation would.

### Where this landed

- **OQ12** — resolved. The mechanism is candidate (a), and the field list is `catalogVersion` + `description` as a denylist.
- **D30** — the decision this experiment was run to inform.

**Hypothesis held.** An operand-side syntax round-trip preserves closedness in both spec-body styles, so candidate (a) is available; and `catalogVersion` alone is insufficient, since a reworded `description` breaks an otherwise-compatible match.
