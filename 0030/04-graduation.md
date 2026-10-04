# Graduation Criteria: OPM Portal V1

These are design acceptance criteria, not implementation milestones: delivery is logged in this entry's `delivery.yaml` and read back with `task delivery`. Repo-wide checks (semver set, placeholders gone, cross-refs resolve) live in `gates.cue` and `task vet`; per-question blocking rules live on the questions in `07-questions.md`. What belongs here is what is true of this design and no other.

## draft → accepted

- **The four acceptance-blocking questions are answered.** The Kubernetes floor (OQ2), read access to cluster-scoped kinds and viewer-role aggregation (OQ6), whether the embedded kernel redacts messages (OQ8), and the API stability policy (OQ10). Each answer lands as a decision or as an edit to D2, D8, D9 or D11.
- **The two states the capture missed are observed.** An accepted and active TransformerRegistration with a consumer of its contract, and a ModulePackage that reconciles from a real Flux source, are captured on a throwaway cluster and added to [experiment 01](experiments/01-live-cluster-capture/). D4:R4's acceptance and activation pills are otherwise designed from refusal samples only.
- **The two operator defects the capture found have an answer that D3 and D11 can live with.** opm-operator issue 209 (drift checks ignore the instance's ServiceAccount) does not change D3:R7, which already ignores the counters; issue 210 (registration version needs a `v` prefix) is fixed or documented, so the fixtures that exercise D4:R4 apply as written.
- **Every decision is still a contract, policy or scope statement.** Mechanism the capture tempted into the log (cache tiers, rate limits, the Pod waiting-reason list as an implementation table) stays out, except where it is the observable rule itself, as in D3:R2.
- **Every `contract` decision lists at least one requirement that a reader outside the portal's code can check**, and the requirements cite no Go symbol, flag or file path.
- **`semver` is set** in `config.yaml`. The expected value is `minor`: the operator gains viewer roles and nothing existing changes.
- **The single-question gate holds.** All eleven decisions answer one question, how OPM's runtime state is shown read-only and to whom; nothing about presentation metadata or writes has leaked in from the marketplace entry.

## Delivery evidence

Not a gate and not a plan: delivery state is derived from `delivery.yaml`. These are the observations a delivering change must be able to show for the requirements it claims, so the claims in the log can be checked.

- **Milestone 1 (local).** On a kind cluster with the released operator and a fixture bundle covering a cluster-scoped module, a provider registration, a consumer, a ModulePackage and a CLI-owned instance: every page renders from the read API; a change to an OPM resource or a watched object reaches an open page within seconds and a polled one shows its evaluation time (D3:R5, D3:R9); the scripted image break turns health Degraded while Applied stays (D3:R2, D3:R3); and golden API documents are seeded from captured cluster state, never from hand-written fixtures.
- **Milestone 2 (in-cluster).** With a test OIDC issuer: two users with different namespace RBAC see different instance sets; a user without Platform read sees the hidden notice (D11:R5); a bearer-token client sees what the browser sees (D6:R5); empty claims, `system:` groups, a failing review and a wrong-audience token each produce the refusal D6 requires, with zero Kubernetes calls for empty identity (D6:R2); the portal's role passes the no-write, no-impersonate, no-Secret check and the catalog-coverage check (D11:R1, D11:R2).
- **Both milestones.** A security audit with no critical findings, and the authorize-before-lookup test of D7:R1 green.
