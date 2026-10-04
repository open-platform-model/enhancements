# Graduation Criteria: The Operator Ships as an OPM Module

These are design acceptance criteria, not implementation milestones: delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`. Repo-wide checks live in `gates.cue` and `task vet`; per-question blocking rules live on the questions in `07-questions.md`.

## draft → accepted

- **Both experiments have concluded and their outcomes are linked.** [`experiments/01-operator-module-render/`](experiments/01-operator-module-render/) from D2, and [`experiments/02-cli-bootstrap-install/`](experiments/02-cli-bootstrap-install/) from D3 and D8, each as measured evidence under the decision it constrains. A decision the evidence contradicts has been revised in place, with the old position under *Alternatives considered*.
- **The migration contract is settled against entry 0012.** OQ3 is resolved, and D8 reads consistently with 0012:D8:R3: either install sets no adopt annotation itself, or entry 0012 has been amended to allow what install does.
- **The operator's own instance is refused at both ends of the transfer.** Entry 0029 states, as requirements, that its transfer command and the operator's adoption refusal both refuse the instance that deploys the operator, and carries a `**Depends:**` line on 0028:D4.
- **The supervisor defaults are confirmed or replaced by the owner.** D1's tag-only image reference and signing clause, D5's list of typed values, D6, D7 and D9 each carry an owner decision in their `Source:` lines, or have been revised.
- **The install refusal rules are decided.** OQ4 (an operator version newer than the CLI) and OQ5 (which platform install renders against) are resolved as decisions with requirements.
- **`config.yaml.semver` is set** from OQ9's answer.
- **Every decision passes the admission test**, every contract decision lists requirements, and no document prescribes a file, an identifier or a layout in the operator or CLI repositories.
