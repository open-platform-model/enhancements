# Design: OPM Portal V1

A new service, `opm-portal`, reads what the opm-operator and the API server already record and serves it twice: as a versioned JSON and server-sent-events read API, and as a server-rendered web UI that is that API's first consumer. V1 is read-only. It runs first on the user's own machine with their kubeconfig, then in-cluster behind OIDC with every read authorized as the signed-in user.

## Design Goals

- **One place shows what OPM runs.** From the Platform's catalogs and registrations down to each instance's components, objects and Pods, with events and logs beside them.
- **Status never lies by omission.** Applied state (what the operator did) and workload health (what is running) are always shown apart, and a broken rollout shows as broken within seconds, not after a ten-minute deadline.
- **The read API is the product.** Anything the UI shows, a script, an adapter or another UI can read through a versioned, documented API under the same identity.
- **A person sees what their RBAC allows, and nothing else.** Locally that is the kubeconfig's identity, and each read is checked first with a SelfSubjectAccessReview. In-cluster it is the signed-in user, checked with a SubjectAccessReview before every read, failing closed.
- **No new source of truth.** Every fact comes from a Kubernetes object the operator or the API server wrote. The portal does not render modules, store state, or invent edges.
- **Secrets stay unread.** The portal never reads Secret data and does not show instance values in V1.

## Non-Goals

- **Writes of any kind.** No create, edit or delete of a stored object, and no scale, restart or order. The only creates are access reviews the API server evaluates and never stores: the self reviews of 0030:D5:R6 locally and the SubjectAccessReview of 0030:D6:R9 in-cluster. Writes arrive with the module marketplace, which builds on the self-service kinds of entry 0027 and gets its own entry.
- **A general Kubernetes dashboard.** Objects are reachable only through an OPM inventory. Pods outside an inventory, arbitrary namespaces and cluster browsing are out.
- **Contract demand and transformer provenance.** Which provider contract an instance demands, and which transformer produced an object, need operator status the operator does not write yet. They move to a follow-up once it does.
- **Persisted history.** No event store, no metrics backend. The portal is stateless apart from sessions.
- **Multi-cluster.** One portal reads one cluster.
- **Module presentation.** Icons, cards, descriptions and forms belong to the marketplace entry.

## High-Level Approach

```
 Browser (HTMX pages)          Scripts, adapters, MCP
          |                             |
          v                             v
 +--------------------------------------------------+
 | opm-portal                                       |
 |   web UI  --in-process-->  read API (JSON + SSE) |
 |                               |                  |
 |   authorize as the user  -----+                  |
 |                               v                  |
 |   watched view of OPM kinds, inventory objects,  |
 |   runtime children; events and logs on demand    |
 +--------------------------------------------------+
          | get / list / watch (never write)
          v
 Kubernetes API: Platform, ModuleInstance, ModulePackage,
 TransformerRegistration, inventory objects, Pods, events
```

**Two milestones, one design.** Milestone 1 is a binary on the user's machine, bound to loopback, reading with the user's kubeconfig. The user's RBAC is the whole boundary, and there is no login code. Each read is checked first with a SelfSubjectAccessReview, so a node the user may not read shows as locked before it is read. Milestone 2 runs the same binary in-cluster: users sign in with OIDC, every read is authorized by a SubjectAccessReview for that user, and the portal then reads with its own narrow, read-only ServiceAccount.

**The portal keeps a watched view.** The four OPM kinds are watched. Inventory objects are watched per kind, selected by the OPM instance label, from the moment an inventory names that kind. Pods and ReplicaSets below an instance are watched only while someone has that instance open. Events and logs are read on demand. Where the reading identity can only `get` a kind, the portal polls it and says how old the answer is. The live capture made this tier mandatory: serving one instance's graph with request-time reads took 7.4 to 9.4 s (measured, [experiment 01](experiments/01-live-cluster-capture/), observation 12).

**Two status axes, computed apart.** The operator's `Ready=True` is shown as **Applied**. Health is the portal's own computation: per object from its status (the same kstatus rules the operator links), plus one Pod rule the capture showed is needed, then worst-of up through components to the instance. An object the reader cannot see makes the result partial, not healthy.

**Graphs come from status, not from a render.** The Platform view joins the Platform's registry, the TransformerRegistrations and the instances. The instance view runs module, instance, components, inventory objects, then Pods and ReplicaSets found through ownerReferences below inventory workloads. Every edge kind has exactly one source.

## Schema / API Surface

V1 adds no CUE and changes no OPM schema. Its contract surface is the read API, named here by what a client relies on, not by its route table.

- **Versioned path.** Every resource lives under `/api/v1alpha1`, including the change stream. A breaking change gets a new version prefix once the API leaves alpha.
- **Portal-shaped documents.** Instance, package, platform, registration, contract, graph and event documents with a `kind` and the portal's own `apiVersion` (`portal.opmodel.dev/v1alpha1`). Raw objects appear only in explicit YAML views, stripped as D8 requires.
- **An instance document carries both axes.** A `reconcile` block (state, reason, message, since; in-cluster the message is withheld, D8:R5) and a `health` block (state, per-state counts, `partial`, `evaluatedAt`, `live`), never one merged status.
- **Graph documents.** Nodes with stable ids that never embed a UID, an access state (`ok`, `forbidden`, `notReadable`) and an optional collapsed summary; edges with a kind and the source they came from.
- **One change stream per client.** Server-sent events carrying the same document shapes as the GETs (snapshot, upsert, delete), plus Kubernetes events and log lines as topics on the same stream, resumable or answered with an explicit resync.
- **Problem documents.** Errors are RFC 9457 problem documents with a closed but extensible `code` set: unauthenticated, forbidden, not readable by the portal, not found, bad request, too many streams, upstream unavailable.

## Affected Surfaces

- **opm-portal (new repo).** The read API and its change stream, the web UI, the local mode, the in-cluster mode with OIDC and per-user authorization, release binaries and an image, and later an install manifest. Consumers observe the API contract in D2 and the security posture in D5 to D8.
- **opm-operator.** One addition: viewer roles a cluster administrator can bind so non-admins may read Platforms, ModulePackages and TransformerRegistrations (D11). Nothing else is required for V1, which reads today's status as it is. Two status additions are follow-ups, not V1: per-entry provider fulfilment (or a provider-contract field) for "requires" edges, and a transformer per inventory entry for provenance.
- **opmodel.dev.** The portal's documentation bundle joins the site: a tutorial for local mode, how-tos for in-cluster install and granting read access, the API reference, and an explanation of Applied versus healthy.

## Before / After

The podinfo image break from `01-problem.md`, seen through each interface:

```
BEFORE (kubectl)                          AFTER (portal instance page, live)
podinfo  Ready=True                       podinfo        Applied     Health: Degraded
deploy   Available=True                     component podinfo        Degraded
pod      ImagePullBackOff (if you look)       Deployment podinfo     Degraded (1 Pod waiting)
                                                Pod ...-cc5ql        ImagePullBackOff
                                          Events (last hour): Failed to pull image ... x3
```

The cert-manager install, seen from the Platform page:

```
BEFORE: four kubectl commands and a manual join of status.registry,
        TransformerRegistrations and providerRef.
AFTER:  Platform cluster  ->  catalog opm@v4 (Subscription, 4.5.2)
        Contracts fulfilled: 2 provider contracts unfulfilled (informational)
        Registrations: backup.k8up  Refused: ProvidesMismatch
        Instances: cert-manager  Applied, Healthy, 42 objects in 20 components
                   (configuration-only components grouped into one node)
```
