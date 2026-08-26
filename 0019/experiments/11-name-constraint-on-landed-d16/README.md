# 11-name-constraint-on-landed-d16 — Kernel render path parity with pure CUE

Status: Concluded

## Hypothesis

D21's propagation mechanism (`#nameConstraint` on every primitive, unified
into `metadata.resourceName` by `#Component` comprehensions) composes with
the D16 spelling that actually landed in `core` (PR 51), which experiment 09
never tested. Experiment 09 validated D21 against `target.cue`'s
`*(default & #ObjectNameType) | #ObjectNameType`; core landed
`*default | #NameType | error(...)` with a deliberately **unvalidated default
arm** plus a hidden `_resourceNameDefaultFits` guard, precisely so a failing
default is refused legibly rather than as a bare `incomplete value`. The
question is whether unifying a constraint into that field reintroduces the
caveat D16 restructured to avoid, and if so, which spelling keeps both.

## Setup

Self-contained CUE module (`experiments.opmodel.dev/e0019x11@v0`), cue
v0.17.1. `types.cue` and `primitives.cue` copied from experiment 09 (D20's
three name types, D21/D23's primitives including the container resource's
conditional constraint). Pass cases 1–6 copied from 09 and re-run against
every spelling. Three spellings survive as packages; refuted ones are
recorded below from their observed output and deleted.

- **root (`v1`)** — D21 as written, on the landed D16 field: the three
  comprehensions unify each primitive's `#nameConstraint` INTO
  `metadata.resourceName`. Ceiling widened to `#ObjectNameType`, `error()`
  arm and `_resourceNameDefaultFits` (bound raised to 253) copied from core.
- **`v3/`** — constraints COLLECTED into a hidden `_nameConstraints`
  conjunction and asserted on a plain hidden field
  `_nameFits: metadata.resourceName & _nameConstraints`.
- **`v5/`** — as v3, but the assertion interpolates the field first:
  `_nameFits: "\(metadata.resourceName)" & _nameConstraints`. **This is the
  conclusion.** Its `cases.cue` carries the extra pass cases (G, I, J) live
  and the must-fail cases commented with observed output.

Must-fail matrix, each case vetted in isolation (`cue vet -c .` with the case
in a scratch file; note CUE ignores files whose name starts with `_`):

| Case | Shape | Expected |
| - | - | - |
| A | dotted override + Expose | refuse (DNS-1035) |
| B | leading-digit instance, default + Expose | refuse (DNS-1035) |
| E | raw stateful, dotted override | refuse (DNS-1123 label, D23) |
| F | 66-rune default, raw stateful | refuse (63-rune label) |
| H | 66-rune default + Expose | refuse (63-rune label) |
| K | 254-rune override, no primitive | refuse (`#ObjectNameType`) |
| G | 66-rune default, stateless | **pass** (D20 ceiling) |
| I | dotted override, no hostile primitive | **pass** |
| J | override `istiod` + Expose | **pass** |

## Run

```bash
cd enhancements/0019/experiments/11-name-constraint-on-landed-d16
cue vet -c ./...            # all three packages: pass cases pinned by hidden assertions
cd v5 && cue vet -c .       # the conclusion
```

To reproduce a refusal, paste a commented `caseFailX` block from
`v5/cases.cue` into `zz_scratch.cue` in that package and re-run.

## Outcome

**Hypothesis refuted for D21's spelling; held for a hidden-assertion
spelling (v5).** D21's mechanism (a per-primitive slot, top by default,
composed by unification with no per-kind knowledge in core) survives intact;
what changes is WHERE the conjunction is applied.

| Spelling | A | B | E | F | H | K | G | I | J | bare `#Component` |
| - | - | - | - | - | - | - | - | - | - | - |
| v1 unify into field (D21 as written) | refuse* | refuse† | refuse* | refuse† | refuse† | refuse | pass | pass | pass | clean |
| v2 guarded `error()` on `field & C` | refuse | refuse | refuse | refuse | refuse | refuse | **FALSE REFUSE** | **FALSE REFUSE** | **FALSE REFUSE** | **fires** |
| v3 hidden `field & C` | refuse | **SILENT PASS** | refuse | **SILENT PASS** | **SILENT PASS** | refuse | pass | pass | pass | clean |
| v4 v2 + `len(field) > 0 &&` | circular dep | **SILENT PASS** | refuse | refuse | **SILENT PASS** | refuse | pass | pass | pass | clean |
| v5 hidden `"\(field)" & C` | refuse | refuse | refuse | refuse | refuse | refuse | pass | pass | pass | clean |
| v6 v2 on `"\(field)" & C` | as v2 | | | | | | **FALSE REFUSE** | | | **fires** |

\* refused by D16's `error()` arm, whose text is WRONG for these cases
("`web.internal` is not a DNS subdomain" — it is one; a primitive refused
it). The arm cannot know which conjunct failed.

† refused as `non-concrete value <constraint conjunction> in operand to ==`
at the `_resourceNameDefaultFits` guard: the D16 caveat, reintroduced. A
constraint unified into the field distributes into the default arm, the
failing default drops out of the disjunction, the field is left a bare
constraint, and the guard's `==` cannot run. The offending string appears
nowhere.

Three measured CUE facts drive the table:

1. **A disjunction unified with a constraint distributes** (`(*d | T) & C`
   = `*(d & C) | (T & C)`). When `d & C` is bottom the default silently
   vanishes and the value is non-concrete. Under `vet -c` a hidden field
   holding that value raises nothing (v3), which is the silent-pass failure
   mode experiment 09 first met in `!= _|_` guards, now in a second
   spelling. The remedy is to RESOLVE the default before unifying:
   interpolation (`"\(field)"`) forces the default arm to a string, and
   `string & C` is either that string or an error that names it (v5).
2. **`(x & C) == _|_` is true for an INCOMPLETE `x`.** On the bare
   `#Component` definition `#instance.name` is unresolved, the default
   interpolation is incomplete, and every `error()` guard built on it fires
   on the definition itself (v2, v6). D16's own guard escapes this only
   because `field == _resourceNameDefault` compares two incompletes, which
   stays pending rather than evaluating. A guard cannot therefore carry the
   remedy text; the raw CUE error is what the author sees.
3. **Prefixing the guard with a concreteness term** (`len(field) > 0 &&`)
   trades the false positive for a `circular dependency in evaluation of
   conditionals` on the override path (v4) and still loses B and H.

v5's refusals read, for each case, `invalid value "<string>" (out of bound
<regex>)` or `(does not satisfy strings.MaxRunes(63))` with the constraint
TYPE's definition site (`types.cue:NN`) and the assertion site. What they do
not name is which attached primitive declared the constraint, nor a remedy;
both are lost with the `error()` guard (fact 2). The `#nameConstraint` types
are few (`#NameType`, `#ServiceNameType`) and the site column points at the
type, so the diagnostic is unambiguous if not self-explaining.

**Consequence for D21 and D16.** D21's "the component unifies it into
`metadata.resourceName`" becomes "the component collects every attached
primitive's constraint into one hidden conjunction and asserts the RESOLVED
`resourceName` against it on a hidden field". The field's own type stays
D20's `*default | #ObjectNameType | error(...)`, so D16's unvalidated-default
invariant, its length guard and its `error()` arm are untouched; the
`_resourceNameDefaultFits` bound moves from 63 to 253 with the ceiling, and
its message loses "DNS label". D21's own caveat sentence ("the landing
carries D16-style hidden assertions for legible refusals") is what v5 is:
there is no additional assertion to write, because the hidden field IS the
assertion. D23's list-index conditional constraint is unaffected (case 5, 6
and E hold under v5).

Evidence for the D21 amendment in `03-decisions.md`.
