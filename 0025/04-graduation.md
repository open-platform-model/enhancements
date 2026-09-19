# Graduation Criteria: Self-Describing Modules and Self-Service Kinds

These are design acceptance criteria, not implementation milestones: delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`. Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs resolve) live in `gates.cue` and `task vet`. Per-question blocking rules live on the questions in `07-questions.md`. What belongs here is what is true of this design and no other.

## draft → accepted

Seven gates must all hold before promoting this design from draft to accepted:

- **The definition has a kind name, and it is used everywhere.** OQ1 is resolved into a decision; the placeholder noun is gone from prose, the CUE identifiers in `schemas/` carry the decided name, and `spec.md`'s section headings match.
- **The layering question is answered in scope.** OQ2 is resolved: the README's scope states whether the binding layer ships alone, and `semver` reflects the answer.
- **The projection is exercised, including its refusals.** `examples.cue` unifies a definition, a served-kind instance and a module through the projection and pins the resulting name, namespace, bound value and consumer value. A bound-versus-consumer conflict and a release outside the bound major are recorded as must-fail cases with the observed error text.
- **The rebinding contract is stated.** OQ3 is resolved: the update-policy vocabulary, its default, and what each value does to live instances are a decision, and `05-risks.md` names the blast radius under each.
- **The aspect pass is exercised, including its refusals.** `examples.cue` unifies a module carrying at least two aspects, pins the key-defaulted name, the label stamp, the derived matching labels and the instance-qualified resource name after projection, and runs a module transformer over one aspect pinning the rendered object's name and one field read from `#config`. The zero-trait aspect, the self-contributed matching key, a module trait carrying `appliesTo`, and a spec key no trait declares are recorded as must-fail cases with the observed error text.
- **Declaration-only fulfilment is decided.** OQ13 is resolved into a decision so the `offering` trait and 0009's lifecycle trait state a fulfilment the contract inventory reads truthfully.
- **Prior art is compared, not cited.** Kratix's Promise and KRO's ResourceGraphDefinition are compared against D3, D6 and D9 with the specific divergences named, in `05-risks.md ## Alternatives` or a `research/` dossier the decisions point at.
