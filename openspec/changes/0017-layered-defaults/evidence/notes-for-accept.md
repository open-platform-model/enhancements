# Notes for the owner at accept

This note comes from the alignment of 0017 with the seeds. The old entry did not hold it as an open question, so it is not in the proposal.

- **How the parity harness records the two accepted divergences.** The requirement "A divergence closes by removing kernel behaviour" of `render-parity` now says that the two accepted divergences are not kernel defects. The seed rules around it are unchanged. "Known divergences are recorded and asserted to reproduce" lets a case expect a divergence. "The oracle must render" makes a case with a failing oracle a broken fixture, also for a case that expects a divergence. Plain CUE reports the config-versus-blueprint collision as incomplete, so the oracle cannot render that case. The old text does not say whether that divergence has a parity case, is an expected-divergence case or has none. The owner decides, and whether "The oracle must render" changes with it.
