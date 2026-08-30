# Graduation Criteria: CUE Testing and Conformance

Entry-specific gates for `draft → accepted`. Repo-wide checks live in `gates.cue` and `task vet`; per-question blocking rules live on the questions in `07-questions.md`.

## draft → accepted

- The location of the conformance suite is decided (OQ5), and if it is a new repo, the `#Area` value and the workspace routing row exist or are part of the first delivery.
- The upstream-snapshot-to-Kubernetes-release mapping question (OQ2) has an answer that lets "each version of Kubernetes is represented" be stated mechanically, or the entry states that the axis is `k8s.io` snapshots and not Kubernetes releases.
- Whether the raw family's coverage report can become a gate (OQ3) is decided, so D4's coverage clause is either a gate or explicitly a report.
- Whether product repos fail or report on suite drift (OQ9) is decided; D3's "fails unless explained" names where that failure is observed.
- The corpus for the first cells is identified in prose: at minimum the 0019 D16 behaviours (seven cases) and one render case per catalog transformer family, so the suite's first delivery has a defined shape without a forecast plan.
- `05-risks.md` and `06-operational.md` carry concrete content; `config.yaml.affects` lists every repo that ships changes.
