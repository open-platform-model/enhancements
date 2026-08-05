# Migration Inventory — Module and Catalog Identity (0010)

Measured 2026-07-30. This is the `draft → accepted` gate that makes the manual migration credible: D18 rejected an operator-side tolerance window on the ground that the fleet is *enumerable*, so the enumeration has to exist before that argument can be relied on.

Two collection sources: the workspace OCI registry (`localhost:5000`, per `CUE_REGISTRY`) and a live cluster reachable at time of measurement. Both were read directly, not derived from committed source.

> **Redacted 2026-08-05.** Deployment-side detail — cluster and environment identifiers, namespaces, instance names, instance UUIDs, and which modules run at which versions — has been removed from this document. What that detail existed to establish is a *property*, not a list: that the fleet is bounded and enumerable, which is the ground D18 stands on when it rejects an operator-side tolerance window. The property is stated below with counts and shape, which is what the argument consumes. The identifying enumeration is kept out of band. Registry-side inventories are unaffected — published artifacts are public by construction.

## Finding first — the fleet does not run on the registry this workspace publishes to

The live cluster references module coordinates that **do not exist** in `localhost:5000`. Measured across the deployed set: **three modules have no repository there at all**, and **five more exist only at tags below the deployed version** — in two cases below the deployed *major*. Ten of twelve live instances, across eight of ten distinct modules, name coordinates the workspace registry cannot serve.

The cause is visible in the operator's own deployment, which carries **no `CUE_REGISTRY` environment variable, no registry argument, and no mounted registry config** — env is `[]`, args are the three kubebuilder defaults, the only volume mount is `/tmp`. The workspace's `localhost:5000` is a developer-side registry that the cluster has never read.

So **the migration spans two registries**, and a migration runbook written only against `localhost:5000` would silently skip every artifact the cluster actually consumes.

> **Corrected 2026-07-31 — the second registry is GHCR, and it is fully enumerable.** The observations above are accurate; the inference originally drawn from them was not. This section first concluded that with nothing configured CUE resolves through *its own* default central registry, and that the registry was therefore un-enumerable from this environment (no egress; connection failed). Both halves were wrong, and the reason the Deployment carries no configuration is that it does not need any: `opm-operator/cmd/main.go:94-98` gives the `--registry` flag a **compiled-in default** of `testing.opmodel.dev=ghcr.io/open-platform-model,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works`. The fleet resolves `opmodel.dev/*` against **`ghcr.io/open-platform-model`**, with `registry.cue.works` only as a trailing fallback. Nothing in the cluster object could have shown this — the value is in the binary.
>
> **A latent surprise found while confirming it, worth its own line.** `resolveRegistry` (`main.go:334-342`) documents its precedence as *`--registry` flag > `OPM_REGISTRY` env > CUE's built-in default*, and returns the flag value whenever it is non-empty. Because the flag's default is non-empty, **the two lower tiers are unreachable**: setting `OPM_REGISTRY` on the operator does nothing, and CUE's own default resolution is never used, unless a caller explicitly passes `--registry=""`. The comment describes a precedence chain the flag default silently truncates.
>
> **The collection gap this section opened is closed, by data rather than by a stated absence.** GHCR enumerates through `gh api --paginate "/orgs/open-platform-model/packages?package_type=container"` — **53 packages**, in §3b below. Every coordinate in §1 exists there at the deployed version, **including all three the table above reports as having no repository at all**: `radarr`, `sabnzbd` and `sonarr` each carry `v1.0.0`–`v1.0.2` on GHCR. The table remains correct about `localhost:5000`; it was measuring a registry the fleet does not use. The two-registry finding survives intact and is the operative one — but both are now inventoried, so it constrains the runbook rather than blocking it from being written.
>
> A dedicated central registry on **Zot** is planned to replace the GHCR arrangement. It does not change this inventory, but it does mean the 0011 D5 namespace migration should not be scheduled without knowing which registry it republishes *into* — see `06-operational.md`.

### 3b. The fleet-facing registry — `ghcr.io/open-platform-model`, 53 packages

Read 2026-07-31 via `gh api --paginate`. **Every live-fleet coordinate is present there at its deployed version**, including all three modules the workspace registry lacks entirely. One deployed module sits one release behind the head published on GHCR; the rest are at head. That closes the collection gap §5 opened — the enumeration exists, so D18's *enumerable* premise is satisfied by data rather than by assertion.

One package-level fact is load-bearing for a later section rather than for the fleet: the `test/podinfo` module carries roughly **seventy `-e2e.g<sha>` prerelease tags** alongside its three release tags.

Three things the GHCR read changes about the defect list:

1. **The spelling collision exists in *both* registries.** `opmodel.dev/catalogs/opm-experimental` and `opmodel.dev/catalogs/opm_experimental` are both published to GHCR as well as to `localhost:5000`, so the canonicalisation recorded in `06-operational.md` is a two-registry cleanup.
2. **`opmodel.dev/modules/opm-platform` is absent from GHCR** — it exists only on `localhost:5000`, as does the `opmodel.dev/library/testdata/modules/web-app` fixture. Both are therefore workspace-local rather than fleet-facing, which shrinks them from migration inputs to dev-registry hygiene.
3. **`test/podinfo` carries roughly seventy `-e2e.g<sha>` prerelease tags in module space.** This is enhancement 0006 OQ18's dev-tag pollution in a namespace that entry did not examine. Under D14 a platform names one build, so nothing can select them by accident — but they are noise the 0011 D5 namespace move has to carry or drop deliberately.

The two registries are neither subset nor superset: **74 repositories on `localhost:5000` against 53 packages on GHCR.** Most of the local-only excess is developer detritus that should never be migrated — `pagero.com/*`, `repro4423/*`, `testing.opmodel.dev/exp0003*`, `test/cleanmod` — alongside the `mc_*` module family, `releases/*`, and the two workspace-local defects above.

## 1. Live `ModuleInstance` fleet — 12 instances, 10 distinct modules

Every one is `READY=True`, `prune=true`, `suspend=false`. **The per-instance enumeration — namespaces, instance names, module coordinates and pre-migration `instanceUUID` values — is held out of band** and is not reproduced here; see the redaction note at the top. Each instance's UUID was captured at measurement time because D18's migration changes it exactly once, and `opm-operator/internal/apply/prune.go:107` skips deletes — silently — when a live resource's owner label disagrees with `Status.InstanceUUID`, so the pre-migration values are what a verification pass compares against.

**The size and shape are what the gate needs, and both are small.** Twelve instances over ten distinct modules, one cluster, one platform. That is the whole surface D18's *enumerable* argument rests on: a single operator can walk it in one pass, which is why no tolerance window, transition period or dual-identity mechanism is warranted.

Three structural facts shape the runbook, stated without identifying the instances:

- **Two modules carry two instances each**, differing only by instance name within one namespace. They share a module UUID, so they exercise the `SHA1(module-uuid : name : namespace)` path rather than the module path alone — the right pair to migrate first if the relabel-vs-recreate question (OQ4's residue) is being tested.
- **Exactly one instance is a `@v0` test artifact** rather than a real workload. It is the cheapest positive-check subject for the D18 gate ("remove a resource from the module, re-render, assert it is actually deleted"), because losing it costs nothing. **Re-measured 2026-08-05: it is gone from the cluster**, so the positive check needs a new subject — a purpose-created throwaway instance is the natural replacement and is cheaper than borrowing a real one.
- **The set is not stable between measurements.** Between 2026-07-30 and 2026-08-05 one instance was added, one removed, and one module upgraded across a minor. Any runbook built from a fixed list is stale on arrival; the enumeration must be re-taken at execution time rather than read from this document.

## 2. Live `Platform` — 1 platform, 3 subscriptions, all using `range`

One platform of type `kubernetes`, `READY=True`, reason `Materialized`. It subscribes to the three published catalogs — `opmodel.dev/catalogs/kubernetes`, `opmodel.dev/catalogs/opm` and `opmodel.dev/catalogs/opm_experimental` — and **every subscription uses `filter.range`**, which is what D14 deletes. The concrete constraint strings are environment configuration and are held out of band.

This is the entire D14 migration surface in production: **three lines**, each collapsing to one scalar `version`. Two observations worth carrying into the runbook, both statable without the constraints themselves:

- **One subscription carries an explicit upper bound, and that bound is enhancement 0006's A5 patch still doing its job.** The `catalogs/opm` repository holds a `v1.0.0-dev.<n>.g<sha>` CI tag alongside its `alpha` releases, and SemVer orders `alpha` before `dev`, so the dev tag sorts *above* every alpha and would win any prerelease-tolerant range. The bound is what excludes it. Under D14 the exclusion becomes structural — an unnamed build is simply not selected — which closes 0006 OQ18 as a side effect rather than as a separate fix. **This is the one place the rewrite is not mechanical:** collapsing that range to a scalar must name the alpha it currently pins to, not the highest tag present, or the dev build is selected by the migration itself.
- **The platform subscribes to the underscore spelling** of the experimental catalog. The registry held **both** `catalogs/opm_experimental` and `catalogs/opm-experimental` as distinct repositories at measurement time — see §4. The subscription was already on the surviving spelling, which is why the canonicalisation needed no platform edit.

## 3. Published artifacts on `localhost:5000` — the `opmodel.dev/*` namespace

70 repositories total in the registry; 66 under `opmodel.dev/`. Grouped by what the migration must do with them.

### 3a. Modules under `opmodel.dev/modules/` — 39 repositories

Thirty-nine repositories, held out of band by name. Composition is what the migration needs: **35 first-party application modules** (most carrying two to six tags, four carrying more than ten), and **4 under the nested `opmodel.dev/modules/test/` namespace** covered separately below. Every repository is `opmodel.dev/modules/<name>` — one flat segment, no owner scoping, no kind ambiguity within the set.

~~Every one of these moves to `opmodel.dev/m/<owner>/<name>` under 0011 D5~~ — **superseded 2026-08-04 by enhancement 0011 D13 and D17. None of them moves.** 0011 D13 keeps first-party modules at `opmodel.dev/modules/<name>`; owner-scoping under `opmodel.dev` was dropped once path ownership became domain ownership, and the `m` spelling was declined on exactly the cost this line describes. `registryPath` is therefore unchanged for every repository above, and with it the instance identity 0010 D41 derives from it.

What *does* change is `fqn` and `uuid` under D1 — the module path gains its `@vN` suffix and `metadata.fqn` becomes that string — but this is **artifact** identity, not the owner label. The `@vN` suffix moves no OCI repository either: `opmodel.dev/modules/jellyfin@v2` addresses repository `opmodel.dev/modules/jellyfin` with `v2.*` tags.

**Names requiring a rename under D8** (snake_case, leaf equals path leaf): `opm-platform` is hyphenated, and `test/hello-web` is hyphenated. Both are the only two violations in the module namespace; every other module is already snake_case, which is why D8 reads as a formalisation rather than a sweep.

**`opmodel.dev/modules/opm-platform` is probably not a module.** The name, and the fact that a `#Platform` is not a `#Module`, suggest it is a platform artifact sitting in module space. It needs classification before the namespace migration, not during it — 0011 D5's whole point is that module space, catalog space and schema space are distinguishable by path alone, and this artifact currently defeats that.

**`opmodel.dev/modules/test/*` (4 repos, 21 tags)** is a nested test namespace. Three of them carry `-e2e.glocaltest` prerelease tags (`test/hello` `v0.0.2-e2e.glocaltest`, `test/hello-web` `v0.1.0-e2e.glocaltest`, `test/podinfo` `v0.1.0-e2e.glocaltest`, `test/redis` `v0.1.0-e2e.glocaltest`) — CI residue in a published namespace. Decide explicitly whether these migrate, get deleted, or move to `testing.opmodel.dev`.

### 3b. Catalogs — 4 repositories, and two of them are the same catalog

| Repository | Tags |
| --- | --- |
| `opmodel.dev/catalogs/opm` | `v1.0.0-alpha`, `v1.0.0-alpha.1`, `v1.0.0-alpha.2`, `v1.0.0-alpha.3`, `v1.0.0-dev.1785176190.g76f3cc6` |
| `opmodel.dev/catalogs/kubernetes` | `v0.1.0`, `v1.1.0-alpha` |
| `opmodel.dev/catalogs/opm_experimental` | `v1.2.0-alpha.1`, `v1.2.0-alpha.2`, `v1.3.0-alpha` |
| `opmodel.dev/catalogs/opm-experimental` | `v1.3.0-alpha` |

**The last two are a spelling collision** — underscore and hyphen forms of one catalog, both published, both holding a `v1.3.0-alpha`. The live platform subscribes to the underscore form. Under D24 a catalog path is the permanent prefix of every contract FQN a module matches on, so two spellings are two key spaces, and a module built against one cannot match a platform subscribed to the other. This is not a cosmetic duplicate; it is the exact failure D1 and D8 exist to prevent, already present in the registry. Resolve which spelling is canonical *before* the migration, not as part of it.

`catalogs/kubernetes` spans two majors (`v0.1.0` and `v1.1.0-alpha`), so it is the one catalog where D1's `@vN`-keyed `#registry` genuinely matters today.

### 3c. Schema — 2 repositories

`opmodel.dev/core` (`v0.4.0`, `v0.5.0`, `v1.0.0-alpha.1`, `v1.0.0-alpha.3`, `v1.0.0-alpha.4`) and the legacy `opmodel.dev/core/v1alpha1` (`v1.3.10`). The live `v1` line is `core`; `core/v1alpha1` belongs to §4.

## 4. Non-module artifacts sharing the namespace

The gate names two of these by hand; measurement found five classes.

**The `library` test fixture — 1 repository, 11 tags.** `opmodel.dev/library/testdata/modules/web-app` at `v1.0.0`–`v1.0.11`. A test fixture published into the production namespace under a hyphenated name. It is also the reason 0011's own graduation gate calls this out separately: it is not a module, it is not a catalog, and it is not schema, so no reserved-segment rule accommodates it.

**Legacy `…/v1alpha1` paths — 10 repositories.** `cert_manager/v1alpha1` (`v1.3.3`) · `ch_vmm/v1alpha1` (`v1.0.2`) · `clickhouse_operator/v1alpha1` (`v1.0.1`) · `core/v1alpha1` (`v1.3.10`) · `gateway_api/v1alpha1` (`v1.3.6`) · `istio/v1alpha1` (`v1.0.2`) · `k8up/v1alpha1` (`v1.0.3`) · `mongodb_operator/v1alpha1` (`v1.0.1`) · `opm/v1alpha1` (`v1.5.8`, `v1.5.9`, `v1.6.0`, `v1.8.0`) · `opm_experiments/v1alpha1` (`v1.1.2`). These are the deprecated `catalog/` tree's published output — the OPM v0 line that `modules`' `v0_legacy` branch still consumes. They sit directly under `opmodel.dev/<name>/` with no reserved segment, which is precisely the flat namespace 0011 D5 replaces.

**A legacy path that is not `v1alpha1`-suffixed — 1 repository.** `opmodel.dev/kubernetes/v1` (`v1.0.2`). Same shape, different spelling; easy to miss when grepping for `v1alpha1`.

**Release artifacts — 4 repositories under `opmodel.dev/releases/`.** One is an environment bundle (9 tags; the environment's name is held out of band), the other three are test fixtures (`releases/test/hello`, `releases/test/podinfo`, `releases/web_app`). `ModuleRelease`/`ModuleInstance` configs published as artifacts. Under 0002 these are `Instance` vocabulary; **0011 D14 resolves them out of scope** — they are pushed with `flux push artifact` and fetched as a Flux source, never resolved by CUE's module resolver, so they are not in the namespace D5 partitions and need no reserved segment.

**An empty repository — 1.** `opmodel.dev/test/cleanmod` has no tags at all. Delete during migration rather than carrying it.

**Foreign namespaces — 4 repositories, out of scope but present.** `pagero.com/catalog`, `pagero.com/iac/cloudsql/instances`, `pagero.com/iac/cloudsql/users`, plus `repro4423/opmodel.dev/catalogs/opm` and `repro4423/opmodel.dev/core` (bug-reproduction copies) and `testing.opmodel.dev/*` (5 repos: `exp0003/cat_a`, `exp0003/cat_b`, `exp0003h/cat`, `exp0003h/mod`, `modules/hello`, `modules/hello-web`). None carry the `opmodel.dev/` prefix the migration operates on. Listed so a future reader does not mistake their absence from the migration for an oversight.

## 5. What this inventory does not cover

Stated plainly, because a gate satisfied by an incomplete inventory is worse than an open gate:

1. ~~**The central registry the live fleet actually resolves against.**~~ **CLOSED 2026-07-31** — it is `ghcr.io/open-platform-model`, enumerated at 53 packages in §3b, and every live coordinate is present there at its deployed version. This was the single largest gap and it gated *scheduling* the migration; what survives is the two-registry finding, which constrains the runbook instead.
2. **The workspace source tree and the dev registry disagree in both directions.** `modules/` holds 12 module directories — `cdi`, `cert_manager`, `istio_ambient`, `jellyfin`, `k8up`, `metallb`, `radarr`, `sabnzbd`, `seerr`, `snapshot_controller`, `sonarr`, `web_app` — on branch `fix/startup-threshold-default` (not `main`, so re-check against `main` before treating this as the module set). So `radarr`, `sabnzbd` and `sonarr` **do** have source here and were simply never published to `localhost:5000`; and conversely `cdi` and `snapshot_controller` have source with no published artifact anywhere measured. The 39 module repositories in §3a are therefore neither a subset nor a superset of the source tree, and the migration needs both lists reconciled — a published artifact with no source cannot be re-published under the new identity, and a source with no artifact does not need migrating at all.
3. **The deployment directory named in the workspace directory map.** It does not exist at workspace root (present: `backup/`, `catalog/`, `catalog_kubernetes/`, `catalog_opm/`, `catalog_opm_experimental/`, `cli/`, `core/`, `enhancements/`, `hatch/`, `library/`, `modules/`, `mycelium/`, `opm/`, `opm-kind-demo/`, `opmodel.dev/`, `opm-operator/`, `research/`). The per-environment instance configs D18 cites as an enumeration source have moved or been renamed; `/CLAUDE.md`'s directory map is stale on this point.

## Method

- Registry catalog: `GET localhost:5000/v2/_catalog?n=200`; tags per repository via `GET /v2/<repo>/tags/list`, filtered to drop `.module` metadata tags and digest-shaped entries.
- Live fleet: `kubectl get moduleinstances -A -o json`, reading `spec.module.{path,version}`, `spec.prune`, `status.instanceUUID`.
- Platform: `kubectl get platform <name> -o json`.
- Operator configuration: `kubectl get deploy -n opm-operator-system opm-operator-controller-manager -o json`, reading container `env`, `args`, `volumeMounts`.
- All measurements 2026-07-30, single pass, no caching. Deployment-side results were reduced to counts and shape on 2026-08-05; the commands above reproduce the full readings for anyone with cluster access, which is the point — this document records the *method* and the *conclusion*, and the identifying data is re-derivable on demand rather than stored.
