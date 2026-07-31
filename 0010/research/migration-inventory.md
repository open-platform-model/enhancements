# Migration Inventory — Module and Catalog Identity (0010)

Measured 2026-07-30. This is the `draft → accepted` gate that makes the manual migration credible: D18 rejected an operator-side tolerance window on the ground that the fleet is *enumerable*, so the enumeration has to exist before that argument can be relied on.

Two collection sources: the workspace OCI registry (`localhost:5000`, per `CUE_REGISTRY`) and the live cluster (`kubectl`, context reachable at time of measurement). Both were read directly, not derived from committed source.

## Finding first — the fleet does not run on the registry this workspace publishes to

The live cluster references module coordinates that **do not exist** in `localhost:5000`:

| Live instance | Coordinate in cluster | Present in `localhost:5000`? |
| --- | --- | --- |
| `nzb/radarr`, `nzb/radarr-uhd` | `opmodel.dev/modules/radarr@v1` `v1.0.2` | **no repository at all** |
| `nzb/sonarr`, `nzb/sonarr-uhd` | `opmodel.dev/modules/sonarr@v1` `v1.0.2` | **no repository at all** |
| `nzb/sabnzbd` | `opmodel.dev/modules/sabnzbd@v1` `v1.0.2` | **no repository at all** |
| `jellyfin/jellyfin` | `opmodel.dev/modules/jellyfin@v2` `v2.3.0` | repo exists, highest tag is `v2.0.2` |
| `k8up-system/k8up` | `opmodel.dev/modules/k8up@v2` `v2.0.0` | repo exists, tags are `v1.0.19`–`v1.0.21` |
| `cert-manager/cert-manager` | `opmodel.dev/modules/cert_manager@v1` `v1.1.0` | repo exists, tags are `v0.0.8`, `v0.0.9` |
| `istio-system/istio` | `opmodel.dev/modules/istio_ambient@v1` `v1.1.0` | repo exists, tags are `v0.0.3`, `v0.0.4` |
| `seerr/seerr` | `opmodel.dev/modules/seerr@v1` `v1.2.0` | repo exists, highest tag is `v1.0.2` |

The cause is visible in the operator's own deployment: `opm-operator-controller-manager` in namespace `opm-operator-system` carries **no `CUE_REGISTRY` environment variable, no registry argument, and no mounted registry config** — env is `[]`, args are the three kubebuilder defaults, the only volume mount is `/tmp`. The workspace's `localhost:5000` is a developer-side registry that the cluster has never read.

So **the migration spans two registries**, and a migration runbook written only against `localhost:5000` would silently skip every artifact the cluster actually consumes.

> **Corrected 2026-07-31 — the second registry is GHCR, and it is fully enumerable.** The observations above are accurate; the inference originally drawn from them was not. This section first concluded that with nothing configured CUE resolves through *its own* default central registry, and that the registry was therefore un-enumerable from this environment (no egress; connection failed). Both halves were wrong, and the reason the Deployment carries no configuration is that it does not need any: `opm-operator/cmd/main.go:94-98` gives the `--registry` flag a **compiled-in default** of `testing.opmodel.dev=ghcr.io/open-platform-model,opmodel.dev=ghcr.io/open-platform-model,registry.cue.works`. The fleet resolves `opmodel.dev/*` against **`ghcr.io/open-platform-model`**, with `registry.cue.works` only as a trailing fallback. Nothing in the cluster object could have shown this — the value is in the binary.
>
> **A latent surprise found while confirming it, worth its own line.** `resolveRegistry` (`main.go:334-342`) documents its precedence as *`--registry` flag > `OPM_REGISTRY` env > CUE's built-in default*, and returns the flag value whenever it is non-empty. Because the flag's default is non-empty, **the two lower tiers are unreachable**: setting `OPM_REGISTRY` on the operator does nothing, and CUE's own default resolution is never used, unless a caller explicitly passes `--registry=""`. The comment describes a precedence chain the flag default silently truncates.
>
> **The collection gap this section opened is closed, by data rather than by a stated absence.** GHCR enumerates through `gh api --paginate "/orgs/open-platform-model/packages?package_type=container"` — **53 packages**, in §3b below. Every coordinate in §1 exists there at the deployed version, **including all three the table above reports as having no repository at all**: `radarr`, `sabnzbd` and `sonarr` each carry `v1.0.0`–`v1.0.2` on GHCR. The table remains correct about `localhost:5000`; it was measuring a registry the fleet does not use. The two-registry finding survives intact and is the operative one — but both are now inventoried, so it constrains the runbook rather than blocking it from being written.
>
> A dedicated central registry on **Zot** is planned to replace the GHCR arrangement. It does not change this inventory, but it does mean the 0011 D5 namespace migration should not be scheduled without knowing which registry it republishes *into* — see `06-operational.md`.

### 3b. The fleet-facing registry — `ghcr.io/open-platform-model`, 53 packages

Read 2026-07-31 via `gh api --paginate`. Every live-fleet module is present at the deployed version:

| Module | GHCR tags | Deployed |
| --- | --- | --- |
| `cert_manager` | `v0.0.7`–`v0.0.9`, `v0.1.0`, `v1.0.0`, `v1.1.0` | `v1.1.0` ✓ |
| `istio_ambient` | `v0.0.2`–`v0.0.4`, `v1.0.0`, `v1.0.1`, `v1.1.0` | `v1.1.0` ✓ |
| `jellyfin` | `v1.0.29`–`v1.0.32`, `v2.0.2`, `v2.1.0`, `v2.2.0`, `v2.3.0`, `v2.4.0` | `v2.3.0` ✓ (not at head) |
| `k8up` | `v1.0.18`–`v1.0.21`, `v2.0.0` | `v2.0.0` ✓ |
| `metallb` | `v0.0.6`–`v0.0.8`, `v1.0.0` | `v1.0.0` ✓ |
| `radarr` | `v1.0.0`–`v1.0.2` | `v1.0.2` ✓ |
| `sabnzbd` | `v1.0.0`–`v1.0.2` | `v1.0.2` ✓ |
| `sonarr` | `v1.0.0`–`v1.0.2` | `v1.0.2` ✓ |
| `seerr` | `v0.0.6`–`v0.0.9`, `v1.0.2`, `v1.1.0`, `v1.2.0` | `v1.2.0` ✓ |
| `test/podinfo` | `v0.1.0`, `v0.1.2`, `v0.1.3` **plus ~70 `-e2e.g<sha>` prereleases** | `v0.1.2` ✓ |

Three things the GHCR read changes about the defect list:

1. **The spelling collision exists in *both* registries.** `opmodel.dev/catalogs/opm-experimental` and `opmodel.dev/catalogs/opm_experimental` are both published to GHCR as well as to `localhost:5000`, so the canonicalisation recorded in `06-operational.md` is a two-registry cleanup.
2. **`opmodel.dev/modules/opm-platform` is absent from GHCR** — it exists only on `localhost:5000`, as does the `opmodel.dev/library/testdata/modules/web-app` fixture. Both are therefore workspace-local rather than fleet-facing, which shrinks them from migration inputs to dev-registry hygiene.
3. **`test/podinfo` carries roughly seventy `-e2e.g<sha>` prerelease tags in module space.** This is enhancement 0006 OQ18's dev-tag pollution in a namespace that entry did not examine. Under D14 a platform names one build, so nothing can select them by accident — but they are noise the 0011 D5 namespace move has to carry or drop deliberately.

The two registries are neither subset nor superset: **74 repositories on `localhost:5000` against 53 packages on GHCR.** Most of the local-only excess is developer detritus that should never be migrated — `pagero.com/*`, `repro4423/*`, `testing.opmodel.dev/exp0003*`, `test/cleanmod` — alongside the `mc_*` module family, `releases/*`, and the two workspace-local defects above.

## 1. Live `ModuleInstance` fleet — 12 instances, 10 distinct modules

Every one is `READY=True`, `prune=true`, `suspend=false`. `instanceUUID` is recorded because D18's migration changes each of them exactly once, and `opm-operator/internal/apply/prune.go:107` skips deletes — silently — when a live resource's owner label disagrees with `Status.InstanceUUID`.

| Namespace / name | Module path | Version | `instanceUUID` (pre-migration) |
| --- | --- | --- | --- |
| `cert-manager/cert-manager` | `opmodel.dev/modules/cert_manager@v1` | `v1.1.0` | `c6a842db-2ca6-52e9-bf7d-99a42c000a8f` |
| `default/podinfo` | `opmodel.dev/modules/test/podinfo@v0` | `v0.1.2` | `6371824d-8e80-5a5b-9d17-1503b0c95b21` |
| `istio-system/istio` | `opmodel.dev/modules/istio_ambient@v1` | `v1.1.0` | `6fe50656-56a5-5b23-a0f4-c6e6c512ac87` |
| `jellyfin/jellyfin` | `opmodel.dev/modules/jellyfin@v2` | `v2.3.0` | `b634d42a-d7dd-53cf-b759-bfa3f7201730` |
| `k8up-system/k8up` | `opmodel.dev/modules/k8up@v2` | `v2.0.0` | `80a9e11f-e3b3-515d-9f66-505e649eb8e3` |
| `metallb-system/metallb` | `opmodel.dev/modules/metallb@v1` | `v1.0.0` | `f1a04491-3511-5d07-b5cd-2fdb487db95d` |
| `nzb/radarr` | `opmodel.dev/modules/radarr@v1` | `v1.0.2` | `132dac81-5eff-543e-b661-271ef4ab902f` |
| `nzb/radarr-uhd` | `opmodel.dev/modules/radarr@v1` | `v1.0.2` | `7b0617fa-d65d-5087-a7ed-67e479398f50` |
| `nzb/sabnzbd` | `opmodel.dev/modules/sabnzbd@v1` | `v1.0.2` | `6eb77a7e-5cca-5325-aa0f-69dbbd87769e` |
| `nzb/sonarr` | `opmodel.dev/modules/sonarr@v1` | `v1.0.2` | `8e97bdbd-5323-522d-a7d3-214c98f5fefe` |
| `nzb/sonarr-uhd` | `opmodel.dev/modules/sonarr@v1` | `v1.0.2` | `7127cc1a-bd4a-5e1b-a48d-d4bc174a40d9` |
| `seerr/seerr` | `opmodel.dev/modules/seerr@v1` | `v1.2.0` | `3c255652-7b12-501e-b525-ed986f0d6c0a` |

Two facts that shape the runbook:

- **Two modules carry two instances each** (`radarr`/`radarr-uhd`, `sonarr`/`sonarr-uhd`, both in `nzb`). They share a module UUID and differ only by instance name, so they exercise the `SHA1(module-uuid : name : namespace)` path rather than the module path alone — the right pair to migrate first if the relabel-vs-recreate question (OQ4's residue) is being tested.
- **`default/podinfo` is the only `@v0` module and the only test artifact in the live fleet.** It is the cheapest positive-check subject for the D18 gate ("remove a resource from the module, re-render, assert it is actually deleted"), and losing it costs nothing.

## 2. Live `Platform` — 1 platform, 3 subscriptions, all using `range`

`platform/cluster`, type `kubernetes`, `READY=True`, reason `Materialized`, operator `v1.0.0-alpha.7`, `observedGeneration: 9`.

| Subscription path | Current `filter.range` | Registry tags on `localhost:5000` | D31 rewrite |
| --- | --- | --- | --- |
| `opmodel.dev/catalogs/kubernetes` | `>=1.0.0-alpha` | `v0.1.0`, `v1.1.0-alpha` | one scalar `version` |
| `opmodel.dev/catalogs/opm` | `>=1.0.0-alpha.1, <=1.0.0-alpha.6` | `v1.0.0-alpha`, `.1`, `.2`, `.3`, plus `v1.0.0-dev.1785176190.g76f3cc6` | one scalar `version` |
| `opmodel.dev/catalogs/opm_experimental` | `>=1.2.0-alpha.2, <=1.2.0-alpha.4` | `v1.2.0-alpha.1`, `v1.2.0-alpha.2`, `v1.3.0-alpha` | one scalar `version` |

This is the entire D29/D31 migration surface in production: **three lines**. Two observations worth carrying into the runbook:

- The `catalogs/opm` upper bound `<=1.0.0-alpha.6` is enhancement 0006's A5 patch still doing its job. The registry holds `v1.0.0-dev.1785176190.g76f3cc6`, and SemVer orders `alpha` before `dev`, so the dev tag sorts *above* `alpha.6` and the bound is what excludes it. Under D31 the exclusion becomes structural — an unnamed build is simply not selected — which is 0006 OQ18 closed as a side effect rather than as a separate fix.
- The platform subscribes to `opmodel.dev/catalogs/opm_experimental` (underscore). The registry holds **both** `catalogs/opm_experimental` and `catalogs/opm-experimental` (hyphen) as distinct repositories — see §4.

## 3. Published artifacts on `localhost:5000` — the `opmodel.dev/*` namespace

70 repositories total in the registry; 66 under `opmodel.dev/`. Grouped by what the migration must do with them.

### 3a. Modules under `opmodel.dev/modules/` — 39 repositories

`cert_manager` (`v0.0.8`–`v0.0.9`) · `cert_manager_config` (`v0.0.5`–`v0.0.6`) · `ch_vmm` (`v0.0.6`–`v0.0.7`) · `clickhouse_operator` (`v0.0.5`–`v0.0.6`) · `clickstack` (`v0.0.15`–`v0.0.16`) · `discord_bridge` (7 tags, `v0.0.1`–`v0.3.0`) · `garage` (`v0.0.3`–`v0.0.4`) · `gateway` (`v0.0.27`–`v0.0.28`) · `intel_gpu_device_plugin` (`v0.0.13`–`v0.0.14`) · `intel_gpu_exporter` (`v0.0.8`–`v0.0.9`) · `istio_ambient` (`v0.0.3`–`v0.0.4`) · `jellyfin` (6 tags, `v1.0.30`–`v2.0.2`) · `k8up` (`v1.0.19`–`v1.0.21`) · `linstor` (`v0.0.1`, `v0.1.1`–`v0.1.2`) · `luckperms_rest` (`v0.1.0`–`v0.1.1`) · `mariadb` (`v0.1.0`–`v0.1.2`) · `mc_java_fleet` (13 tags) · `mc_java_server` (8 tags) · `mc_ops` (`v0.1.0`–`v0.1.1`) · `mc_router` (4 tags) · `mc_velocity` (4 tags) · `metallb` (`v0.0.7`–`v0.0.8`) · `metric_server` (`v0.0.7`–`v0.0.8`) · `mongodb_operator` (`v0.0.11`–`v0.0.12`) · `northbyte_web` (`v0.0.1`, `v0.1.0`) · `openebs` (`v0.0.3`–`v0.0.4`) · `openebs_zfs` (17 tags, `v0.0.9`–`v0.0.25`) · `opm` (`v1.0.0`–`v1.0.7`) · `opm-platform` (`v1.0.0`–`v1.0.1`) · `otel_collector` (`v0.0.6`–`v0.0.7`) · `seafile` (`v0.0.1`, `v0.2.0`) · `sealed_secrets` (`v0.0.5`–`v0.0.6`) · `seerr` (6 tags, `v0.0.7`–`v1.0.2`) · `test/hello` (4 tags) · `test/hello-web` (4 tags) · `test/podinfo` (5 tags) · `test/redis` (8 tags) · `web_app` (`v0.0.1`–`v0.0.2`) · `wolf` (`v0.1.2`–`v0.1.3`) · `zot_registry_ttl` (`v0.0.7`–`v0.0.8`)

Every one of these moves to `opmodel.dev/m/<owner>/<name>` under 0011 D5, and every one's `fqn` — and therefore `uuid` — changes under D1/D2.

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

**Release artifacts — 4 repositories.** `opmodel.dev/releases/kind_opm_dev` (9 tags, `v0.0.50`–`v0.0.58`) · `opmodel.dev/releases/test/hello` (3 tags) · `opmodel.dev/releases/test/podinfo` (1 tag) · `opmodel.dev/releases/web_app` (1 tag). `ModuleRelease`/`ModuleInstance` configs published as artifacts. Under 0002 these are `Instance` vocabulary and under 0011 D5 they need a reserved segment of their own or an explicit decision that they stop being published.

**An empty repository — 1.** `opmodel.dev/test/cleanmod` has no tags at all. Delete during migration rather than carrying it.

**Foreign namespaces — 4 repositories, out of scope but present.** `pagero.com/catalog`, `pagero.com/iac/cloudsql/instances`, `pagero.com/iac/cloudsql/users`, plus `repro4423/opmodel.dev/catalogs/opm` and `repro4423/opmodel.dev/core` (bug-reproduction copies) and `testing.opmodel.dev/*` (5 repos: `exp0003/cat_a`, `exp0003/cat_b`, `exp0003h/cat`, `exp0003h/mod`, `modules/hello`, `modules/hello-web`). None carry the `opmodel.dev/` prefix the migration operates on. Listed so a future reader does not mistake their absence from the migration for an oversight.

## 5. What this inventory does not cover

Stated plainly, because a gate satisfied by an incomplete inventory is worse than an open gate:

1. **The central registry the live fleet actually resolves against.** No egress at measurement time. Every coordinate in §1 that is missing from §3a lives there, and so does whatever else has been published to it. This is the single largest gap and it should be closed before the migration is scheduled.
2. **The workspace source tree and the dev registry disagree in both directions.** `modules/` holds 12 module directories — `cdi`, `cert_manager`, `istio_ambient`, `jellyfin`, `k8up`, `metallb`, `radarr`, `sabnzbd`, `seerr`, `snapshot_controller`, `sonarr`, `web_app` — on branch `fix/startup-threshold-default` (not `main`, so re-check against `main` before treating this as the module set). So `radarr`, `sabnzbd` and `sonarr` **do** have source here and were simply never published to `localhost:5000`; and conversely `cdi` and `snapshot_controller` have source with no published artifact anywhere measured. The 39 module repositories in §3a are therefore neither a subset nor a superset of the source tree, and the migration needs both lists reconciled — a published artifact with no source cannot be re-published under the new identity, and a source with no artifact does not need migrating at all.
3. **The `releases/` directory named in the workspace directory map.** It does not exist at workspace root (present: `backup/`, `catalog/`, `catalog_kubernetes/`, `catalog_opm/`, `catalog_opm_experimental/`, `cli/`, `core/`, `enhancements/`, `hatch/`, `library/`, `modules/`, `mycelium/`, `opm/`, `opm-kind-demo/`, `opmodel.dev/`, `opm-operator/`, `research/`). The per-environment instance configs D18 cites as an enumeration source have moved or been renamed; `/CLAUDE.md`'s directory map is stale on this point.

## Method

- Registry catalog: `GET localhost:5000/v2/_catalog?n=200`; tags per repository via `GET /v2/<repo>/tags/list`, filtered to drop `.module` metadata tags and digest-shaped entries.
- Live fleet: `kubectl get moduleinstances -A -o json`, reading `spec.module.{path,version}`, `spec.prune`, `status.instanceUUID`.
- Platform: `kubectl get platform cluster -o json`.
- Operator configuration: `kubectl get deploy -n opm-operator-system opm-operator-controller-manager -o json`, reading container `env`, `args`, `volumeMounts`.
- All measurements 2026-07-30, single pass, no caching.
