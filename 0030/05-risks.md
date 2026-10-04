# Risks, Drawbacks, Alternatives: OPM Portal V1

Risks describe what could go wrong. Drawbacks describe what definitely costs something. Alternatives describe the high-level paths not taken; per-decision detail lives in `03-decisions.md`.

## Risks and Mitigations

**Highest: a security failure in a shared, multi-user service.**

- **A shared cache leaks across tenants.** The in-cluster portal reads with one ServiceAccount and serves many users, so one handler that skips the per-user check shows one team another team's objects. **Mitigation:** D7 makes authorization the first step of every read and requires the same refusal for existing and missing objects; tests assert a principal without access gets zero items from every list.
- **Empty or forged identity reaches the cluster.** The Flux Operator UI's CVE-2026-23990 ran empty-claim requests as the server's own identity ([research](research/prior-art-and-access.md)). **Mitigation:** D6 refuses an empty username before any Kubernetes call, strips every `system:` group, refuses to start without prefixes unless the API server trusts the issuer, and holds no impersonate grant at all.
- **Values leak through a side door.** `spec.values` reaches the portal through the instance spec and through the last-applied annotation a client-side apply writes (measured, [experiment 01](experiments/01-live-cluster-capture/), observation 14). Condition and event messages may carry values too if the embedded kernel does not redact them (OQ8). **Mitigation:** D8 strips both carriers everywhere; OQ8 blocks acceptance.

**Next: status that misleads.**

- **Health is wrong in a way the capture did not cover.** The Pod waiting-reason rule fixes image pulls and crash loops, but other failures (a stuck volume attach, a pending Pod with no node) may also stay InProgress for long. **Mitigation:** health never claims more than kstatus plus the stated rule; unknown and progressing are shown as such, not as healthy, and the rule list is a requirement that can grow by amendment.
- **Users read "Applied" as "healthy".** **Mitigation:** D3 shows both axes everywhere and never uses the word healthy for Ready; an explanation page ships with the docs.
- **Operator status is stale or wrong.** The drift counter climbs on healthy instances (opm-operator issue 209), the recorded contracts are not demand (observation 2), and status history keeps only five entries. **Mitigation:** D3:R7 ignores counters; D4:R3 draws no requires edges; OQ9 and OQ18 carry the gaps.

**Then: operational.**

- **The portal breaks on an operator upgrade.** It imports the operator's API types and reads `v1alpha1` status that may still change. **Mitigation:** the portal pins the operator version it reads, moves the pin by hand (OQ14), and tests against a captured cluster for that version; D2 isolates API clients from the change.
- **Many watched kinds on a provider-heavy cluster.** One watch per kind that appears in any inventory, and provider modules add many CRD kinds. **Mitigation:** watches are label-selected and drop everything but metadata and status; memory is recorded in the milestone 1 exit and a scale budget is follow-up work.
- **The project joins the archived dashboards.** Kubeapps, the Kubernetes Dashboard and Glasskube were all archived ([research](research/prior-art-and-access.md)). **Mitigation:** D2 makes the read API the product, so Headlamp, Backstage or MCP adapters can outlive the UI.

## Drawbacks

- **A new repo and a new release line to maintain**, with its own CI, release-please, image and docs bundle.
- **No writes in V1.** A platform team still uses `kubectl`, the CLI or GitOps to change anything.
- **No values in V1.** Debugging a misconfiguration means reading values elsewhere.
- **Two status values where users expect one.** Honest, and more to read.
- **Provider-defined kinds show as not readable** until a follow-up decides how a portal may read them.
- **Users are invisible in the API server's audit log in milestone 2.** The portal's own access log is the only record of who read what.

## Alternatives

- **A Headlamp plugin instead of a portal.** Headlamp is the SIG-UI successor to the Kubernetes Dashboard and has a plugin map API. **Why not:** plugins run only in the browser with no server-side hook seen, so per-user filtering of a shared cache, server-side health and log bounds cannot live there; a plugin over this entry's API stays a follow-up.
- **Embed the UI in the operator** (the Flux Operator model). **Why not:** the operator's manager role holds cluster-wide impersonate and write on ModuleInstances, so a UI bug there has the operator's blast radius.
- **Backstage as the base.** **Why not:** heavy Node platform, a shared server-side identity by default in its Kubernetes plugin, and an upgrade burden; it stays an adapter target.
- **Re-render modules in the portal** for provenance and demand. **Why not:** a second render path that can disagree with the operator's, at tens of megabytes per module and with registry access in the portal.
