# Experiment 01 — Cross-level promotion comparison

Status: Draft

## Hypothesis

**The field-wise comparator that `0011/experiments/03-d27-compat-gate` established for the within-level case produces correct verdicts when the two operands sit at different contract levels.**

D2 requires that a member carrying `promotedFrom` be compared against the newest published build carrying its `name` at the `promotedFrom` level, under enhancement 0010 D27's additive-only rule. The comparator itself is settled: `0011/experiments/03` measured that `cue.Value.Subsume` cannot express D27 in either direction (`next.Subsume(prev)` agreeing on 10/14 cases, `prev.Subsume(next)` on 8/14, on disjoint failure sets, with a changed default invisible to both), and that a three-rule field-wise walk expresses it at 14/14.

What has never been run is that walk over operands whose `apiVersion` differs. Three specific things could break, and the experiment exists to find out which:

1. **The level-aware entry point short-circuits.** `library/opm/compat`'s `CheckAtLevel` reads the level off the apiVersion and returns `(nil, nil)` at alpha, because alpha promises nothing (0010 D34). A promotion **from** alpha (D5 permits it) has an alpha operand, so a naive reading of the existing entry point skips the comparison entirely and every alpha-to-GA promotion passes unchecked. If that is what happens, D2 needs to say which operand's level decides.

2. **The metadata delta swamps the comparison.** The two operands differ by construction in `apiVersion` and `fqn`, and the promoted one additionally carries `promotedFrom`. If those fields reach the walk, every promotion reports violations that are artifacts of being a promotion. Enhancement 0010 D30 already excludes provenance from the *match* comparison via a fixed denylist; whether the publish-side comparator has an equivalent exclusion, and whether `promotedFrom` is on it, is OQ6's concrete half.

3. **Predecessor selection has no cross-level path.** 0011 D23's scan enumerates published versions and walks newest-first looking for `name` at a given `apiVersion`. Handing it a *different* `apiVersion` than the member carries is a new call shape, not new logic, but "not new logic" is a claim, and this is where it gets checked.

**The hypothesis holds** if the walk returns D27-correct verdicts on a matrix of cross-level pairs with the identity fields excluded, and the alpha-operand case is unambiguously decidable.

**The hypothesis is refuted** if the comparison cannot be made correct without changing the comparator itself, rather than only its inputs. `04-graduation.md` makes this experiment a gate on `accepted → implemented` precisely so that outcome sends D2 back for redesign rather than shipping on assumption.

## Setup

Not yet performed. Planned shape, following the copy-never-reference rule:

- Copy the comparator from `library/opm/compat` into this directory as a Go module. Do not import it: the claim is about the comparator **as of the moment this ran**, and an upstream change would silently invalidate a referenced experiment.
- Copy the relevant fixture shapes from `0011/experiments/03-d27-compat-gate`, re-keyed so each case exists at two levels.
- Build a case matrix over (origin level, target level) × (change class). Origin levels: `v1alpha1`, `v1beta1`, `v1beta2`. Target levels: `v1beta2`, `v1`, `v2`. Change classes are D27's own: field added optional, field added required, field removed, type narrowed, disjunction option added, default changed, and identical.
- Record for each case what D27 says the verdict should be, independently of what the code returns, so the comparison is against the rule rather than against the implementation.

## Run

Not yet performed. Commands will be recorded here verbatim when the experiment runs, including the exact `cue` version, matching `0011/experiments/03`'s practice of pinning the evaluator version in the outcome (that experiment ran against cue v0.17.1).

## Outcome

Not yet recorded.

Three things must be stated when it is:

- The verdict matrix, case by case, with agreement or disagreement against D27 called out per cell rather than summarised.
- Which fields had to be excluded for the comparison to be meaningful, which settles OQ6's concrete half.
- Which operand's level decides whether the gate runs at all, which D2 currently leaves implicit and must not.
