# 01-policy-as-cue — OPM Versioning Policy

Status: Concluded

## Hypothesis

A versioning policy authored as pure CUE (a shared `#Policy`/`#Rule` schema, one instance per artifact class) can carry the five header cells and the rules with their strength, layer and source; can generate its Markdown page with `cue eval -e render --out text` and no Go; can prove the page fresh by regenerate-and-diff; and can refuse, at `cue vet`, a rule whose label overstates its enforcement (a MUST at the convention layer with no stated reason, a gate rule naming no enforcer, a sentence whose strength word disagrees with its field).

## Setup

Nothing is copied from a source-of-truth repo; the schema is authored here as the proposed shape of `opmodel.dev/core/policy` (0021 02-design.md, documentation section) and the instance is the module class transcribed from 0021 D2, 0011 D15 and the modules major separation rule.

- `schema.cue`: `#Policy`, `#Rule`, `#Bump` (a discriminated union whose each form carries its own rendered text), the universal rules and `stableBump` as importable data, and `#Render`, which builds the Markdown page as a CUE string.
- `module_policy.cue`: the module class as one policy file would carry it in `modules/policy/`, five rules across must/should/may and all four layers.
- `fail/*/f.cue`: three minimal packages, each violating one schema invariant, vetted with `-c` so a required-but-absent field is an error.
- `run.sh`: the six steps.
- `POLICY-module.md`: the generated output, committed so a reader sees the page without running anything.

One dead end recorded: the first renderer selected the bump text with a comprehension-plus-index trick (`[if …, if …][0]`), which fails under `cue vet` because a definition is also evaluated with `#p` unbound and the list is then empty. Carrying the text inside the `#Bump` union removes the selection entirely.

## Run

```bash
bash run.sh
```

## Outcome

```
== 1. vet the policy package
ok
== 2. render POLICY-module.md from CUE
38 POLICY-module.md
== 3. freshness check (regenerate and diff)
fresh
== 4. negative: must without reason (expect error)
r.unenforcedBecause: field is required but not present:
    ./fail/must_without_reason/f.cue:7:50
== 5. negative: gate without enforcer (expect error)
r.enforcedBy: field is required but not present:
    ./fail/gate_without_enforcer/f.cue:6:22
== 6. negative: strength word disagrees with field (expect error)
r.statement: invalid value "A release SHOULD bump." (out of bound =~"\\bMUST\\b"):
    ./fail/strength_mismatch/f.cue:9:14
    ./fail/strength_mismatch/f.cue:7:14
```

Steps 1 to 3 pass: the package vets, the page renders (38 lines, see `POLICY-module.md`), and regenerate-and-diff reports it fresh, which is the same freshness mechanism the repos already use for `INDEX.md`. Steps 4 to 6 each fail with a one-line error naming the missing or disagreeing field, which is the safeguard the design wants: a rule cannot claim more enforcement than it names.

Two observations for the design. First, the render is pure CUE and needs no generator binary, so the pure-CUE repos (core, catalog_opm, modules) can adopt it with a two-line task. Second, the strength-word check is a regex on the sentence, which means a rule must contain its own MUST/SHOULD/MAY; that is a language rule the schema enforces rather than a style guide anyone has to remember.

Hypothesis held. The policy renders from CUE with no Go, freshness is a diff, and all three invariants are refused at vet.
