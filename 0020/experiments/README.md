# Experiments — Contract Promotion and Retirement

| # | Concept | Status |
| - | ------- | ------ |
| 01 | cross-level-promotion | Draft |

Experiment 01 is a **graduation gate**, not an optional validation. The acceptance criteria block `accepted → implemented` until it concludes, following the precedent enhancement 0011 set for its own D9: that decision shipped with no named implementation because `cue.Value.Subsume`'s cross-build behaviour was unmeasured, its graduation document made sequencing the measurement a gate, and `0011/experiments/03-d27-compat-gate` then returned a negative on Subsume and a positive on the field-wise walk. D2 inherits that walk but hands it operands at two different levels, which is the part nobody has run.
