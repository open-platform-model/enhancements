# Design Decisions: OPM Portal V1

## Summary

Decisions are numbered sequentially (D1, D2, D3, …) and recorded as they are made. **Numbers are permanent**, never reused, never renumbered, because other repos cite them from commit messages and OpenSpec changes.

**Decision text states what is true now.** While the entry is `draft`, decisions are living text: a changed choice is an in-place edit to the existing `DN`, and the log never contains two conflicting decisions. Evidence-backed old positions fold into *Alternatives considered* before overwriting. Once `accepted`, decision bodies are protected: a change lands as a new `DN` with `**Amends:**` / `**Supersedes:**` relation fields, and existing bodies are edited only through the `enhancement-compaction` skill.

Each decision carries a `**Kind:**` line (`contract` | `policy` | `scope`), the body fields Decision, Requirements, Alternatives considered, Rationale and Source. A decision that rests on another entry's decision carries a `**Depends:** MMMM:DN` line, and `config.yaml.depends_on` lists exactly the entries those lines name.

**The Kind gate.** A decision belongs here only if a from-scratch rewrite of the affected repos would still be bound by it. Mechanism (how the portal caches, which libraries it uses, how its packages are laid out) belongs in the implementing OpenSpec changes in `opm-portal` and `opm-operator`.

All eleven decisions are draft. Each was proposed from the portal design and then checked against a live cluster capture ([experiment 01](experiments/01-live-cluster-capture/)); where the capture contradicted the design, the decision below states the corrected position and the old one sits in *Alternatives considered*.

---

## Decisions

### D1: V1 is read-only

**Kind:** scope

**Decision:** The V1 portal creates, edits and deletes no stored object, in either milestone. The only requests it creates are access reviews the API server evaluates and never stores: the self reviews of D5:R6 locally and the SubjectAccessReview of D6:R9 in-cluster, which D11 grants. It reads the four OPM kinds, the objects their inventories name, the runtime children below those objects, events and Pod logs. Writes, including ordering a module, arrive with the module marketplace, a separate entry that builds on the self-service kinds of entry 0027. A CLI-owned ModuleInstance is shown like any other instance and is equally read-only.

**Requirements:** none (scope boundary; the observable consequences are D5's and D6's review-only creates and D11's read-only role)

**Alternatives considered:**

- **Simple writes in V1** (restart a workload, suspend an instance, delete). Each needs a write identity, which in-cluster means impersonation or token passthrough. Both reverse the posture D6 takes for reads and widen the blast radius of the empty-identity class of bug. Deferred to the marketplace entry, where the write identity is an open question in its own right.
- **Ordering modules in V1.** Needs the 0027 definition kind, which is a draft, plus a presentation contract that does not exist yet. V1 would block on two unaccepted entries.

**Rationale:** A read-only V1 can ship on today's operator with no dependency on unaccepted entries, and it removes every write-side security question from the first release.

**Source:** Owner decision 2026-10-04 (V1 read-only, writes in V2 through 0027 kinds); portal master plan, section 2. Owner decision 2026-10-04 ("Keep the seam": the only allowed creates are the non-persisted review APIs).

---

### D2: The versioned read API is the durable contract, and the web UI is its first consumer

**Kind:** contract

**Decision:** The portal's contract is a read API under a versioned path, `/api/v1alpha1`, serving JSON documents over `GET` and a server-sent-events change stream. The web UI renders from that API's documents, in-process, under the caller's identity: it has no read path of its own. The documents are shaped for the portal (instance, package, platform, registration, contract, graph, event), never a passthrough of a custom resource's status. The API stays at `v1alpha1` until a declared stability point (OQ10); within the version, changes are additive and clients ignore what they do not know.

**Requirements:**

- R1: Every fact the web UI shows is available from the read API to a client holding the same identity, with the same filtering.
- R2: The API version is part of every path; within one version, a field or enum value may be added but not removed or renamed without the release notes marking the change as breaking.
- R3: Clients are told to ignore unknown fields and to treat every enum as open; the portal's own UI renders an unknown enum value as "unknown", never as an error.
- R4: No API document embeds a raw custom-resource status; raw objects are served only by explicit YAML views, under D8's stripping rules.
- R5: The change stream carries the same document shapes as the corresponding `GET`, and a client that reconnects either resumes from its last event or is told to re-read.
- R6: Errors are RFC 9457 problem documents carrying a `code` from a closed but extensible set, so a client can tell "you may not read this" from "the portal may not read this" from "not found".

**Alternatives considered:**

- **HTMX pages with no public API** (the API added later). Fastest V1, but every adapter later re-derives the joins, and the UI's needs would shape an API retrofitted after the fact. Rejected by the owner.
- **A JavaScript single-page app over the JSON API.** Makes the browser the consumer, at the cost of a client build and client templates. Not chosen.
- **UI and API as two presenters over a shared service layer.** Simpler, but the API then has no consumer in V1 except tests, so nothing keeps it complete. Not chosen.
- **Version `v1` from day one.** Everything upstream is `opmodel.dev/v1alpha1` and may still change; promising more stability than the source has would make the portal absorb every upstream break.

**Rationale:** Standalone Kubernetes UIs have a poor survival record (Kubernetes Dashboard, Kubeapps and Glasskube are archived), and the portals that last expose a neutral read model that adapters build on ([research](research/prior-art-and-access.md)). Making the UI a real consumer is what keeps the API complete.

**Source:** Owner decision 2026-10-04 ("Go API + HTMX on top": a versioned JSON/SSE read API as the durable contract from day one, with the HTMX UI as its first consumer); [research/prior-art-and-access.md](research/prior-art-and-access.md), portals and dashboards.

---

### D3: Applied state and workload health are two axes, never merged

**Kind:** contract

**Depends:** 0015:D14, 0015:D18

**Decision:** Every instance and package shows two values side by side. **Applied** state comes from the operator's conditions: `Ready=True` is shown as "Applied" and never as healthy, because the operator's Ready means every apply succeeded, with no wait on workload health. **Health** is the portal's own computation from live objects: each object's status by the standard Kubernetes status rules (kstatus), plus one Pod rule, rolled up worst-of through components to the instance, with unreadable objects excluded and the result marked partial. The Pod rule exists because the live capture showed an image-pull failure stays invisible to both the operator and kstatus for the whole progress deadline: a container waiting with `ErrImagePull`, `ImagePullBackOff`, `CrashLoopBackOff`, `CreateContainerConfigError` or `InvalidImageName` marks the Pod's owning workload Degraded. A CLI-owned instance shows its applied state as managed externally, in a neutral style, and its health is still computed from the inventory the CLI wrote. The operator's failure counters and drift flag are diagnostics, never health.

**Requirements:**

- R1: An instance's applied state and its workload health are shown as two separate values; neither is derived from the other, and a `Ready=True` instance is never labelled healthy.
- R2: A Pod whose container waits with an image-pull, crash-loop, container-config or invalid-image reason marks its owning workload, and so its component and instance, Degraded, even while the workload's own conditions report it available.
- R3: In the scripted image break (the instance's image value set to a tag that does not exist, so the operator applies a Deployment whose new Pod cannot pull while the old replicas keep serving), the instance's health is Degraded within seconds of the new Pod reporting its waiting reason, while its applied state stays Applied.
- R4: An object the portal or the user cannot read is excluded from the roll-up and the result says it is partial; a Secret is never read and does not make a result partial.
- R5: An object whose health is refreshed by polling rather than by a watch shows when it was last evaluated, and the instance's health says it is not live.
- R6: A CLI-owned instance shows its applied state as managed externally, without an error style, and shows workload health computed from its inventory.
- R7: The operator's failure counters and drift flag never change either axis.
- R8: A Platform reporting unfulfilled provider contracts is shown as information, not as a failure.
- R9: An instance page and its graph are answered from state the portal already holds; their response time does not grow with one Kubernetes read per inventory object.

**Alternatives considered:**

- **One merged status badge.** What most dashboards show. With Ready meaning applied, it shows green for the whole ten-minute window in which a rollout is broken (measured: [experiment 01](experiments/01-live-cluster-capture/), observation 3).
- **kstatus alone for health** (previously adopted in the design, before the capture). The capture refuted it for image-pull failures: the Deployment stayed `Available=True` and kstatus said InProgress until `ProgressDeadlineExceeded`, about 600 s after the break.
- **Failure counters as a health hint** (previously shown in the design's instance document). The drift counter climbs on healthy instances because the operator's drift check ignores the instance's ServiceAccount (opm-operator issue 209), so the counter would mark healthy instances as suspect.
- **Wait for an operator `Healthy` condition.** No health wait exists in the operator or is planned (0015:D14 as revised), and health in the operator is an open question (OQ3), not a V1 prerequisite.
- **Health computed per request** (the spike's approach: one read per inventory object on every render). Measured at 7.4 to 9.4 s for cert-manager's graph at client-go's default rate limit; a watched view is required (R9).

**Rationale:** The portal's main promise is that a broken rollout looks broken. Ready is correct for what it says, apply success, so the portal keeps it and labels it honestly, and computes health itself from the objects that actually show the failure.

**Source:** Measured on a live cluster: [experiment 01](experiments/01-live-cluster-capture/), observations 3, 6, 11 and 12, and the CLI-owned instance addendum. 0015:D14 as revised (readiness means apply success, no health wait); 0015:D18 (an unfulfilled contract is reported, never refused), which R8 follows. Owner decision 2026-10-04 to capture a CLI-owned instance on the throwaway cluster.

---

### D4: Graphs derive only from operator- and API-server-written state

**Kind:** contract

**Depends:** 0015:D3

**Decision:** The portal never renders a module. Every node and edge comes from a field a Kubernetes object already carries, and each edge kind has exactly one source: subscriptions from the Platform's resolved registry; registration-to-catalog from the registry entries a registration contributed; registration-to-instance from the registration's provider reference, cross-checked against the provider's inventory; instance-to-module from the instance spec; component and object edges from the inventory; runtime children from ownerReferences walked below inventory workloads; package-to-package from the package's dependencies. **V1 draws no "requires" edge from an instance to a provider contract.** The live capture showed the instance's recorded contracts are every contract its render used, most of them fulfilled by the catalog itself, not the provider contracts it demands; V1 lists them on the instance as text, and requires edges wait for the operator to record provider demand. Registrations show acceptance and activation as separate states, read from the registration's `status.accepted` and `status.active` fields, never inferred from the `Stalled` and `Ready` conditions: the same condition pair marks both a refused claim and an accepted, active claim whose removal is blocked by dependents. A blocked removal is shown as its own state, not as a refusal. Configuration-only components are grouped into one expandable node by default.

**Requirements:**

- R1: Every node and edge in a portal graph is traceable to a field of a Kubernetes object; no graph is produced by rendering a module.
- R2: Where two sources for the same relation disagree (a registration's provider reference and the provider's inventory), the graph shows the disagreement instead of picking one.
- R3: V1 shows no edge from an instance to a contract; the contracts an instance's render used are listed on the instance as plain text, labelled as the render's contracts, not its provider demand.
- R4: A registration shows whether it was accepted and whether it is active as two separate states, taken from its `status.accepted` and `status.active`; a refused registration shows its refusal reason and message.
- R5: Components that own no workload are grouped into one expandable node by default.
- R6: Graph node identifiers are stable across portal restarts and do not change when the underlying object is deleted and recreated.
- R7: A registration that is being deleted while instances still demand its contracts is shown as removal blocked, naming the reason and message, and keeps showing as accepted and active; it is never shown as refused.

**Alternatives considered:**

- **Requires edges from `status.requiredContracts`** (previously adopted in the design). The capture refuted it: cert-manager lists 15 contracts and podinfo 7, nearly all catalog-fulfilled, so the edges would claim every instance depends on every core resource. Waiting for an operator field that records provider demand (per-entry fulfilment or a provider-contract list, OQ18) is the honest path.
- **Re-render modules in the portal** to recover transformer provenance and demand. A render costs tens of megabytes per module, needs registry access and a platform module on disk, and would create a second render path that can disagree with the operator's.
- **Draw instance-to-object edges from labels.** The uuid label is on every inventory object but not on Pods or ReplicaSets, and labels are a cross-check, not the record; the inventory is.
- **Read acceptance from the conditions** (previously in this decision). `Stalled=True` plus `Ready=False` marks a refusal, but phase 9 of the capture showed the same pair, reason `DependentsRemain`, on a claim that stayed accepted and active while its removal was blocked; reading the pair as refusal would mislabel it.
- **Show every component as its own node.** cert-manager's graph had 86 nodes and 85 edges, 20 of them components, most holding one RBAC or configuration object (measured, observation 13); unreadable without grouping.

**Rationale:** One source per edge kind makes every edge explainable and every disagreement visible. Drawing an edge the data does not support is worse than drawing none, because a platform team would act on it.

**Source:** Measured on a live cluster: [experiment 01](experiments/01-live-cluster-capture/), observations 2, 8, 9 and 13, with the refused, accepted and active, and removal-blocked registration samples of phases 7 to 9; [experiment 02](experiments/02-live-graph-spike/). Registration verdicts as 0015:D3 defines the registration resource and its status fields and conditions.

---

### D5: Milestone 1 runs locally, and the user's kubeconfig is the boundary

**Kind:** contract

**Decision:** In local mode the portal is a binary on the user's machine that reads the cluster only as the kubeconfig's identity. It binds to loopback only, refuses a request whose `Host` is not that loopback address, and admits a browser only through a one-time launch token exchanged for a session cookie. There is no login code against the cluster and nothing to install in it. Before each read the portal asks the API server whether the kubeconfig's identity may make it, with a SelfSubjectAccessReview for the exact verb, resource, namespace and name, and learns who that identity is with a SelfSubjectReview. A node the user may not read is shown locked up front, and in-cluster mode swaps the review for D6's SubjectAccessReview behind the same check. These two reviews are the only objects local mode creates; the API server evaluates them and stores nothing.

**Requirements:**

- R1: In local mode every cluster read is made as the kubeconfig's identity; the portal adds no credential and installs nothing in the cluster.
- R2: Local mode refuses to listen on a non-loopback address.
- R3: A request that does not carry the session established from the launch token is refused, so another local user or process cannot read the cluster through the portal.
- R4: A request whose `Host` header names anything other than the loopback address and port is refused.
- R5: A user who cannot list the OPM kinds cluster-wide can still use the portal on the namespaces they can read.
- R6: In local mode the only create requests the portal sends are `selfsubjectaccessreviews` and `selfsubjectreviews`; it sends no other create, update, patch or delete.
- R7: In local mode every read is preceded by an allowed SelfSubjectAccessReview for the kubeconfig's identity and the exact request attributes, and an object the identity may not read is shown as locked without being read.

**Alternatives considered:**

- **In-cluster first.** Needs OIDC, a session store, RBAC for the portal and an install manifest before anyone can see anything; local mode gives the same views with none of that.
- **Loopback without a launch token.** Any local process or user can reach loopback; the token is the same defence notebook servers use.
- **A container image as the only artifact.** A container cannot reach a kind API server on host loopback or serve a browser on loopback without host networking, so local mode ships as binaries.
- **No access review in local mode: read, and map the API server's refusal.** Creates nothing at all, but the UI learns a node is locked only after a failed read, and in-cluster mode would need a second authorization path instead of swapping one backend.

**Rationale:** The user's own RBAC is already the right boundary on their machine. Local mode exercises every read path and the whole API before any authentication code exists. A SelfSubjectAccessReview asks about whoever sends it, which locally is the user, so R6 allows the self reviews here and 0030:D6:R9 allows only the SubjectAccessReview in-cluster.

**Source:** Owner decision 2026-10-04 ("Local first, then in-cluster": milestone 1 runs on your machine with your kubeconfig, your RBAC is the boundary, no auth code). Owner decision 2026-10-04 ("Keep the seam": the only allowed creates are the non-persisted review APIs `subjectaccessreviews`, `selfsubjectaccessreviews` and `selfsubjectreviews`; milestone 1 shows locked nodes up front, and milestone 2 swaps the backend without rewriting the seam).

---

### D6: Milestone 2 authorizes every read as the signed-in user, then reads as the portal

**Kind:** contract

**Decision:** In-cluster, users sign in through OIDC (authorization code with PKCE); programmatic clients present a bearer JWT from the same issuer, naming the portal's configured audience. For every read the portal sends a SubjectAccessReview carrying the user's mapped name and groups for the exact verb, resource, namespace and name, and reads with its own ServiceAccount only on allow. Identity mapping fails closed: an empty mapped username is refused before any Kubernetes call, a `system:` username is refused, every `system:` group from the identity provider is stripped, and `system:authenticated` is added for every authenticated principal. Mapped names carry a non-empty prefix unless the deployment declares that the API server trusts the same issuer with the same prefixes. A review that errors or times out is a denial. The portal holds no impersonate permission and no write verb other than `create` on the review API of 0030:D6:R9; the only object it creates is the SubjectAccessReview, which the API server evaluates and does not store. It keeps a per-user log of reads because the API server's audit log sees only the portal's ServiceAccount.

**Requirements:**

- R1: In-cluster, every read is preceded by an allowed SubjectAccessReview for the signed-in user's mapped identity and the exact request attributes.
- R2: A principal whose mapped username is empty is refused with no Kubernetes call made on its behalf.
- R3: No `system:` group asserted by the identity provider reaches a SubjectAccessReview, a `system:` username is refused, and `system:authenticated` is present for every authenticated principal.
- R4: A SubjectAccessReview that errors, times out or returns an evaluation error without allowing is treated as a denial and is never cached.
- R5: A bearer-token client sees exactly what the same user sees in the browser.
- R6: Unless the deployment declares that the API server trusts the portal's issuer, the portal refuses to start with an empty username or groups prefix.
- R7: The portal records, per authenticated person, each read it authorized and each it denied.
- R8: A bearer token is accepted only when it is signed by the configured issuer and names the configured audience; any other token is refused with no Kubernetes call made on its behalf.
- R9: In-cluster, the only create request the portal sends is `subjectaccessreviews`; it sends no other create, update, patch or delete.

**Alternatives considered:**

- **Impersonation** (the Flux Operator UI's model). Requires the impersonate verb, which is the blast radius of the empty-identity bug class (CVE-2026-23990 in the Flux Operator UI: empty claims fell through to the server's own identity). SubjectAccessReview-then-read needs no impersonate grant at all. Revisiting it after V1 is OQ1.
- **Token passthrough.** Works only where the API server trusts the portal's issuer, which most clusters do not; it stays an option for writes in V2.
- **A shared portal identity with no per-user check.** Shows every user what the portal can see; rejected outright.

**Rationale:** Reads need the user's authorization, not the user's credential. Checking with a SubjectAccessReview and reading with a narrow ServiceAccount keeps the user's RBAC as the boundary without granting the portal the power to become anyone. The cost, users being invisible in the API server's audit log, is paid by R7. In-cluster a SelfSubjectAccessReview or SelfSubjectReview would describe the portal's own ServiceAccount, not the user, so R9 forbids them: a check that answers for the portal would turn it into a confused deputy.

**Source:** Owner decision 2026-10-04 (milestone 2: in-cluster Deployment, OIDC login, SubjectAccessReview-as-user, fail closed on empty identity). Owner decision 2026-10-04 ("Keep the seam": the only allowed creates are the non-persisted review APIs `subjectaccessreviews`, `selfsubjectaccessreviews` and `selfsubjectreviews`; milestone 1 shows locked nodes up front, and milestone 2 swaps the backend without rewriting the seam); [research/prior-art-and-access.md](research/prior-art-and-access.md), access model.

---

### D7: Authorize before lookup, and never reveal existence

**Kind:** contract

**Decision:** Every request is authorized on its attributes (verb, resource, namespace, name) before anything is looked up, in both milestones. A caller who may not read a kind in a namespace gets the same refusal whether or not the object exists. Lists return only what the caller may read. Partial access inside a response, such as an instance whose inventory names objects the caller cannot see, is reported per item as an access state, not as a failed request. Only objects reachable from an OPM inventory are served: the portal is not a general cluster browser.

**Requirements:**

- R1: A caller without read access to a kind in a namespace receives the same refusal for an existing and a non-existing object of that kind.
- R2: A list contains only items the caller may read, and a caller with no access receives an empty list with no count or name of hidden items.
- R3: Objects inside a readable response that the caller cannot read are marked forbidden, and objects the portal itself cannot read are marked not readable; neither fails the response.
- R4: A request for an object no OPM inventory reaches is refused as not in inventory, and only after the caller passed the authorization check for it.

**Alternatives considered:**

- **Look up first, then authorize.** Simpler handlers, but a missing-versus-forbidden difference leaks which objects exist.
- **Serve any object the caller may read.** Turns the portal into a general cluster browser and widens the role the in-cluster portal needs.

**Rationale:** A shared cache serving many users is exactly where a cross-tenant leak happens. Making authorization the first step of every read path, and testing that a caller without access sees nothing, is cheaper than auditing each handler.

**Source:** Portal V1 architecture, error model and access sections; [research/prior-art-and-access.md](research/prior-art-and-access.md), access model.

---

### D8: Secret data is never read, and values are not shown in V1

**Kind:** contract

**Decision:** The portal never reads a Secret's data, in any mode, so it can never serve one. In V1 it shows no instance's `spec.values`: users supply plain values that unification marks as secrets only inside the module's schema, and modules still take plain-string passwords, so no marker in the stored values identifies what to hide. The `kubectl.kubernetes.io/last-applied-configuration` annotation is stripped from every object the portal serves, because a client-side apply copies the full values into it. Hiding `spec.values` does not hide what the values became: a value a module renders into a non-Secret object (a ConfigMap entry, a container's environment) is shown in that object's YAML view to any user whose RBAC lets them read it, exactly as `kubectl` would show it. Keeping a value out of reach means rendering it into a Secret.

**Requirements:**

- R1: The portal reads no Secret's data in any mode, and its in-cluster role grants no access to Secrets.
- R2: No API document, YAML view or page in V1 contains an instance's or package's `spec.values`.
- R3: No object the portal serves carries the `kubectl.kubernetes.io/last-applied-configuration` annotation.
- R4: The portal's documentation states that values rendered into non-Secret objects are visible to anyone who may read those objects, in the portal as in `kubectl`.

**Alternatives considered:**

- **Show values with secret leaves masked** (an earlier revision of the design). There is nothing to mask on: secret markers are added by unification inside the module, not stored in `spec.values`, and plain-string password fields carry no marker at all.
- **Show values to users who may read Secrets in every namespace the inventory renders a Secret into.** Possible, but it still cannot find secret leaves without the module's schema walker, which V1 does not carry. Left for later (OQ7).

**Rationale:** The live capture confirmed the annotation leak: a client-side apply of an instance copies every value into the annotation (observation 14). Hiding values and stripping the annotation is the only rule V1 can keep without reading module schemas.

**Source:** Measured on a live cluster: [experiment 01](experiments/01-live-cluster-capture/), observation 14. Core's secret marker shape and the plain-string password fields in the first-party modules, read from source.

---

### D9: Conditions and history are the record; events are an expiring feed

**Kind:** contract

**Decision:** Status badges and the durable part of the timeline come from conditions and `status.history`. Kubernetes events are a recent-activity feed with the API server's roughly one-hour lifetime, labelled as such, and no displayed state is inferred from them. The portal deduplicates events itself: the event recorder folds a repeat into `series` only when it regards the same object version, so repeats after the object's status changed arrive as separate events, and kubelet events count through the deprecated count and timestamp fields, so repeated events about the same object with the same reason and message become one line with a count and the latest time, whichever way each repeat was recorded. Events about the cluster-scoped Platform and TransformerRegistrations, which Kubernetes records in namespace `default`, appear on those objects' pages. Render warnings the operator records only as events are labelled on the instance page as expiring with the feed.

**Requirements:**

- R1: Every status value the portal shows comes from conditions or status history; none is inferred from an event.
- R2: The events feed is labelled as recent activity that expires.
- R3: Repeated events about the same object with the same reason and message appear once, with a count and the latest occurrence time, for both operator and kubelet events, and whether each repeat was recorded as a separate event, in an event's `series`, or in its deprecated count.
- R4: Events about the Platform and about each TransformerRegistration appear on that object's page.
- R5: The instance page states that render warnings are kept only as events and that older ones are gone.

**Alternatives considered:**

- **Rely on event `series` for collapsing** (previously assumed in the design). In the capture the only operator events with `series` were three repeats (`count: 2`), two Platform `Generated` and one ModuleInstance `NoOp`, each regarding an unchanged object version and all from the unreleased library beta.4 rebuild, none from the released beta.5 controller; cert-manager's four `ApplyFailed` repeats, identical but for the regarded object's `resourceVersion`, were four separate events, and kubelet events have `eventTime: null` (observation 4).
- **Look for Platform events in the Platform's namespace.** It has none; the capture found them in `default` (observation 5).
- **Persist events in the portal.** Makes the portal stateful and a second record of history; whether anyone should persist them is OQ9.

**Rationale:** Events are transition-only and expire, so they cannot carry state. Labelling them honestly and folding repeats keeps the feed useful without pretending it is history.

**Source:** Measured on a live cluster: [experiment 01](experiments/01-live-cluster-capture/), observations 4, 5, 7 and 10.

---

### D10: Logs stream only for Pods an inventory reaches, bounded by the portal

**Kind:** contract

**Decision:** Pod logs can be streamed only for a Pod reachable from an instance's or package's inventory through workload ownership: Deployment to ReplicaSet to Pod, StatefulSet or DaemonSet to Pod, Job to Pod, and CronJob to Job to Pod. The user's `pods/log` access is checked before a stream starts and again on reconnect. The portal bounds each stream itself: an oversize line is truncated with a marker, lines beyond a per-stream rate are dropped and counted, and an oversize initial tail skips ahead to live output with a marker. It never uses the Kubernetes byte limit, which ends a followed stream outright.

**Requirements:**

- R1: A log stream is refused for any Pod no OPM inventory reaches through workload ownership.
- R2: A log stream starts only after the user's `pods/log` access is confirmed, and is re-checked on every reconnect.
- R3: A stream never ends because of a byte limit; truncated lines and dropped lines are marked in the stream, with a count of what was dropped.
- R4: A container that stops ends its stream with an explicit end-of-stream message.

**Alternatives considered:**

- **Logs for any Pod the user can read.** Makes the portal a general log viewer and widens its role.
- **The API server's `limitBytes`.** Ends the whole stream, followed output included, after that many bytes.

**Rationale:** Keeping logs inside the OPM view keeps the role narrow. Bounding in the portal protects the browser and the portal without cutting off the live tail a developer is watching.

**Source:** Portal V1 architecture, logs section. The Deployment to ReplicaSet to Pod chain was measured on a live cluster ([experiment 01](experiments/01-live-cluster-capture/), observation 8); the capture held no StatefulSet, DaemonSet, Job or CronJob, so those chains are design, read from the Kubernetes controllers' ownerReference behaviour.

---

### D11: The portal's role is read-only, follows the catalog, and the operator ships viewer roles

**Kind:** contract

**Decision:** The in-cluster portal's ClusterRole grants `get`, `list` and `watch` on the four OPM kinds and their status, on events, on every non-Secret kind the pinned OPM catalog's transformers can render, and on the runtime children those workloads own (Pods, `apps` ReplicaSets, and `batch` Jobs a CronJob creates), which D3's Pod rule, D4's runtime children and D10's reach check all read; `create` on `subjectaccessreviews`; and `get` on `pods/log`. That create stores nothing: the API server evaluates the review and returns it. The role grants no other create, no update, patch or delete, no impersonate and no Secrets. The kind list is checked against the pinned catalog, so a catalog bump that adds a kind fails before release. Kinds that provider modules define (cert-manager's Certificate, for example) are not covered in V1 and show as not readable. On the user side, the opm-operator ships viewer roles a cluster administrator can bind so non-admins may read Platforms, ModulePackages and TransformerRegistrations; whether they aggregate into the built-in `view` role is OQ6.

**Requirements:**

- R1: The in-cluster portal's role contains no impersonate verb, no access to Secrets, and no verb that stores or changes an object; its only `create` is on `subjectaccessreviews`.
- R2: Every non-Secret kind the pinned OPM catalog can render, and every runtime child kind below those workloads (Pods, ReplicaSets, Jobs), is readable by the portal's role, and a catalog that adds a kind the role does not cover is caught before the portal releases.
- R3: An inventory object of a kind the portal's role does not cover is shown as not readable, with the reason, never omitted.
- R4: A cluster administrator can grant a non-admin read access to Platforms, ModulePackages and TransformerRegistrations using a role the operator ships.
- R5: A user without read access to the Platform sees that it is hidden by their access, not an empty Platform.

**Alternatives considered:**

- **A wildcard read role.** Covers provider kinds for free and also covers Secrets and every other tenant's objects; rejected.
- **Aggregate provider kinds into the portal's role through a label in V1.** Needs an owner decision on which provider kinds a portal may read; moved to a follow-up.
- **No operator change, and document hand-written roles.** Leaves every installation to rediscover the same role, and no role the operator ships lets a non-admin read Platforms, ModulePackages or TransformerRegistrations.

**Rationale:** A read-only role is the in-cluster form of D1. Checking it against the catalog keeps "read-only" from silently turning into "cannot see half the objects" after a catalog bump.

**Source:** Owner decision 2026-10-04 ("Keep the seam": only the non-persisted review APIs may be created), which in-cluster leaves `subjectaccessreviews` (0030:D6:R9). opm-operator's shipped RBAC, read from source (one viewer role, ModuleInstances only, no aggregation label); kind list from the opm catalog's transformer outputs, read from source; [research/prior-art-and-access.md](research/prior-art-and-access.md), access model.

Open Questions live in [`07-questions.md`](07-questions.md), the entry-wide question register with its own numbering and status rules.
