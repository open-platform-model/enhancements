# Graduation Criteria: Self-Describing Modules

These are design acceptance criteria, not implementation milestones: delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`. Repo-wide checks (semver set, placeholders gone, CUE compiles, cross-refs resolve) live in `gates.cue` and `task vet`. Per-question blocking rules live on the questions in `07-questions.md`. What belongs here is what is true of this design and no other.

## draft → accepted

Four gates must all hold before promoting this design from draft to accepted:

- **The aspect pass is exercised, including its refusals.** `examples.cue` unifies a module carrying at least two aspects, pins the key-defaulted name, the label stamp, the derived matching labels and the instance-qualified resource name the aspect computes once a `#ModuleInstance` supplies its identity, and runs a module transformer over one aspect pinning the rendered object's name and one field read from `#config`. The zero-trait aspect, the self-contributed matching key, a module trait carrying `appliesTo`, and a spec key no trait declares are recorded as must-fail cases with the observed error text.
- **An unhandled aspect demand is exercised, not only asserted.** D14 is what separates an aspect from an annotation with a schema, and nothing in the delta currently runs it. `examples.cue` stands up a platform over two catalogs and pins what the inventory reports for a required module trait no enabled module transformer handles, and for an optional one.
- **Declaration-only fulfilment is decided.** OQ13 resolves into a decision, so a module trait consumed outside the render path states a fulfilment the contract inventory reads truthfully. The offering declaration in entry 0027 and the lifecycle trait in entry 0009 are the two consumers waiting on the answer.
- **Prior art is compared, not cited.** OAM's application scopes and KubeVela's application-level policies are compared against D11 and D13 with the specific divergences named, in `05-risks.md ## Alternatives` or a `research/` dossier the decisions point at. Both attach a fact to a group of components; what differs is who decides membership and what renders the result.
