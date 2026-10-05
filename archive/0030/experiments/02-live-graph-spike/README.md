# 02-live-graph-spike — OPM Portal V1

Status: Concluded

## Hypothesis

A column-per-kind graph built only from operator-written status (Platform registry, instance inventory, registrations) plus an ownerReference walk below inventory workloads, rendered server-side as SVG, is readable at real instance sizes; and computing health on the request path, one read per inventory object, is fast enough for an interactive page.

## Setup

A throwaway prototype written for the portal design (a Go binary bound to loopback, about 800 lines of Go over a dynamic client, a discovery-based kind-to-resource mapper and the kstatus fork the operator links). It was first run on hand-written fixtures and then against the live cluster of [experiment 01](../01-live-cluster-capture/) while cert-manager was healthy and podinfo was broken. The prototype source is not copied here: it is disposable, and its rendering defects (an inline style block in the SVG, htmx loaded from a CDN, label truncation that can split a UTF-8 character) are exactly what the real portal must not copy.

[`out/`](out/) holds the small outputs from the live run: the instance list, and podinfo's graph one minute after the image break and again after the progress deadline. The cert-manager graph JSON and SVG (about 80 KB) and the screenshots were left out.

## Run

The prototype was served on loopback against the throwaway cluster and its four endpoints fetched with `curl`; screenshots were taken with a pinned Playwright image. Re-running needs the prototype and a cluster in the state experiment 01 describes, so this experiment is recorded rather than reproducible from this directory.

## Outcome

Measured on the live cluster:

- **Sizes.** podinfo's graph had 18 nodes and 17 edges. cert-manager's had 86 nodes and 85 edges: 20 component nodes, 15 contract nodes, 10 ClusterRoles, 10 ClusterRoleBindings, 6 CRDs, 3 Deployments with their ReplicaSets and Pods, and the RBAC, webhook and namespace objects. At podinfo's size the column layout reads well; at cert-manager's it does not without grouping configuration-only components.
- **Latency.** Serving cert-manager's graph took 7.4 to 9.4 s, about 45 Kubernetes reads at client-go's default limit of 5 queries per second. Request-path health is not viable for an interactive page.
- **Health.** One minute after the break, kstatus rated the broken Pod "InProgress: Pod is in the Pending phase" and the Deployment InProgress. After `ProgressDeadlineExceeded` the Deployment turned Failed, but the Pod still read InProgress. The operator's Ready stayed True throughout.
- **Contracts.** The prototype drew every entry of the instance's recorded contracts as a node and labelled each "no provider registered". All seven of podinfo's are catalog-fulfilled, so every one of those labels was wrong.

**Hypothesis partly refuted.** A status-only graph is buildable and readable at small sizes, so D4's source rule holds, but it needs default grouping (D4:R5), contract nodes from the recorded contracts are wrong (D4:R3), health needs a Pod waiting-reason rule (D3:R2), and request-path reads are too slow (D3:R9).
