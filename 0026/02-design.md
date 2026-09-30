# Design: Module-Dictated Catalog Versions and the Generated Platform

The platform stops holding catalog versions and starts bounding them. The authored `#Platform` is pure data: it names the catalog lineages a platform admits, each as a `#CatalogAdmission` with a required floor, an optional ceiling and a prerelease opt-in, and carries no imports. A module's committed catalog pin is the version its render holds, if it lies inside the range. The render-time registry 0019 shipped under the name `#Platform` moves, unchanged in shape, to `#ResolvedPlatform`: a value the kernel generates per resolution rather than a file anyone maintains. Trade-off reasoning lives in `03-decisions.md`.

## Design Goals

- **A module renders against the catalog release it was tidied against**, whenever the platform admits that release. What the author tested is what runs.
- **The platform admits lineages and bounds releases; it does not pick them.** A path with its major, a floor, an optional ceiling. Admission and version selection are two facts held by two parties.
- **A pin outside the range is refused by name, never promoted.** The refusal names the module, the path, the pin, the bound and whose bound it was. Nothing silent moves an instance to a version its owner did not name.
- **Raising the floor touches only the instances below it.** The platform keeps a lever that reaches the whole fleet, and it is loud: named refusals until owners bump, never a silent re-render.
- **Provider catalogs follow the same rule with the provider module as the pinning module.** The registration's derived `version` is the pick when no consumer pins the path, the provider author declares a compatibility window, and the platform's admission entry overrides it when present.
- **A catalog major can be upgraded one module at a time.** A platform admits several majors of one catalog side by side, and each render holds the one its module pins.

## Non-Goals

- **Changing how matching works, or how the transformer set is derived.** The render build's match glue and the fold over embedded catalogs are exactly as 0019 left them. This entry changes which version's bytes reach the fold, nothing about the fold.
- **Changing who admits a catalog.** Static catalogs are admitted by the authored platform, provider catalogs by the RBAC-gated registration of 0015 D3. Both stay.
- **Routing between providers, classes, or capability-based selection.** 0015 D2's successor material, untouched.
- **Automatic upgrade of instances within a range.** A floor refuses, it does not promote. Whether a future entry may float an instance forward within a range is gated on enhancement 0021's answers about what a compatible module change is, and is out of scope here.
- **Module-hosted transformers.** 0015 D10 stands. A version selects bytes from a published catalog artifact; nothing here lets a module ship code.

## High-Level Approach

Two layers replace one file.

```
#Platform (authored, pure data)              consumer module's cue.mod (committed pins)
  #CatalogAdmission per path, major in path    catalogs/opm@v4   v4.1.0
  floor required, ceiling optional             core, k8s.io, ... (tidied closure)
  prereleases off by default, registry optional
              └───────────────────┬────────────────────┘
                     kernel: admit, check, generate
                        for each catalog path the module imports:
                          admitted? in [floor, ceiling]? GA unless opted in? else refuse by name
                        for each accepted registration: add its catalog at its version
                                    ▼
             resolved platform module         <- #ResolvedPlatform: 0019's value, shape unchanged
               cue.mod  = the module's tidied list plus registration catalogs
               value    = one import and one #registry entry per catalog in the build
                                    ▼
                     one render build (0019 D9), unchanged from here on
```

**The platform is data.** It has no `cue.mod` dependencies and imports nothing, so it can be a Platform CR's spec and an offline CLI file with the same fields. It says which lineages exist on this platform, what range of each is admitted, and whether prereleases count. That is the whole of what the platform team authors.

**The module's pin is the version.** The kernel reads the module's committed dependency list, the same list 0019 D13 already stages, and writes the render module's list from it. No tidy runs at render, no resolver is consulted, no maximum-version selection happens. The list is a promotion from committed files, as before; what changes is which file is promoted on a catalog path.

**The resolved platform is generated per resolution.** The kernel writes a platform module whose `cue.mod` carries the catalog versions the build will hold and whose value is a `#ResolvedPlatform`, the registry 0019 shipped as `#Platform`: one import per catalog, one `#registry` entry per path, `#composedTransformers` folded as now. Two renders with the same resolved set share one resolved platform. A fleet clusters on a handful of catalog releases, so the set of resolved platforms stays small.

**Provider catalogs join the same rule.** The provider module pins its own catalog, and 0015 D11 already derives the registration's `version` from that pin. That version is the pick for any render that does not pin the provider catalog itself. The registration gains a window, `floor` and `ceiling` defaulting to `version`, that the provider author sets beside the operator release the module deploys. An admission entry for the provider catalog's path is optional; when present, its range replaces the author's window, and the registration's status reports which one is in effect.

**Refusal replaces promotion.** A consumer pin below the floor is refused. Raising the floor is therefore the platform's fleet-wide lever, and it is a lever that names every instance it stops rather than moving them.

**A render with no platform holds its own pins already.** The CLI already renders against the render's own pins when no platform is given: a module render without a platform directory, and an instance render or module apply that uses no cluster Platform. It generates a platform module from those pins, so the module's version is held and nothing is admitted or bounded, because there is no platform team and no fleet. That path stays platform-less (D3): a render takes a module and, optionally, an authored `#Platform`, and with none the resolved platform is generated from the render's pins alone, every pinned catalog is held, and D2's admission does not run. No `#Platform` is synthesized for it. Everything above applies when a platform is given. The kernel generates the resolved platform on both paths, so the platform-less generation the CLI does today moves into the kernel.

### Side-by-side catalog majors

A catalog major upgrade today moves every module at once. Contract keys carry no catalog major (0010 D4), so two majors of one catalog declare the same keys, and a build holding both fails to evaluate (`experiments/01-one-major-per-build/`, case A). The only working shape is one major enabled at a time.

This entry already has most of what side-by-side majors need. An admission entry is keyed by module path with its major, so admitting `opmodel.dev/catalogs/opm@v4` and `opmodel.dev/catalogs/opm@v5` is two entries. A render's resolved platform holds only the catalogs its module pins. D9 makes the consequence a rule: **the major is settled per resolution, before `#ResolvedPlatform` is written, and a resolution holds one major per catalog.** A render of a module on opm@v5 holds opm@v5 alone, so the resolved platform, the fold, the render glue and matching never meet two majors of one catalog and none of them changes.

```
#Platform (authored)                     module A cue.mod: opm@v4 4.4.1    module B cue.mod: opm@v5 5.0.0
  catalogs/opm@v4   floor 4.2.0
  catalogs/opm@v5   floor 5.0.0
  (registrations: k8up@v2 built on opm@v4, k8up@v3 built on opm@v5)
                │
       kernel: settle the major per resolution, before writing it
                │
      ┌─────────┴──────────────────────────┐
      ▼                                    ▼
resolution for A                     resolution for B
  opm@v4 at 4.4.1                      opm@v5 at 5.0.0
  k8up@v2 (serves opm@v4)              k8up@v3 (serves opm@v5)
  one major, one provider              one major, one provider
```

What changes is everything that looks at more than one resolution:

- **The module-less build is split.** The platform's own build for readiness and the contract inventory held every enabled static catalog at its floor in one build (D2 R7); with two majors admitted that build fails exactly like case A. It is now split so no build holds two majors of one catalog. Whether the split is one build per admitted major or one per consistent combination, and what Ready means when one slice is broken, is OQ11.
- **A provider joins only the resolutions holding the major it was built against.** A provider built on opm@v4 is refused by a v5 component at plain unification, because the trait value it requires carries a 4.x `catalogVersion` (`experiments/02-provider-serves-its-major/`). Serving opm@v5 takes a provider built against opm@v5. How resolution learns a provider's major is OQ9.
- **The one-provider rule is counted per resolution.** k8up@v2 for opm@v4 beside k8up@v3 for opm@v5 is legitimate: each resolution holds one of them. Counted across the authored platform the pair reads as over-subscribed (experiment 02). Where the platform-level report lives is OQ12.
- **Registration acceptance judges per declaring major.** A v4 provider and a v5 provider of the same contract do not refuse each other, and a provider's shared-path requirements are compared against the admitted entry of its own major (D7 R2). Whether acceptance derives the major or reads it from the registration is OQ13.

**Migration is per module.** A module whose own dependencies import two majors of one catalog is refused at resolution, naming the module, the catalog and both majors (D9 R6), and the platform-less path follows the same rule (OQ18). Whether a module may instead move component by component is OQ10. A provider's own major upgrade stays an atomic swap (OQ14), a new major ships no bridge to the old one's contracts in this entry (OQ15), and draining a major before disabling it rests on the held-version record of D1 R3 (OQ16).

**The alternatives measured and not taken.** Carrying the catalog major in every contract key works end to end but re-keys every contract on every catalog major and changes the publish gates. Keeping shared keys and scoping matching by the major also works but reshapes every consumer type and two operator CRD fields and puts provenance into matching. Both are recorded under D9.

## Schema / API Surface

Full shapes in [`schemas/target.cue`](schemas/target.cue).

- **`#Platform`** (CHANGED: the name moves to the authored value): the authored platform, pure data. `metadata`, `type`, and `catalogs`, a path-keyed map of `#CatalogAdmission`. Mirrors the Platform CRD's spec; enhancement 0008's generation is the intended route from one to the other.
- **`#CatalogAdmission`** (NEW): one admitted lineage. `path` with the major, `enable`, an optional `registry` naming where the path resolves, `prereleases` defaulting to false, a required `floor`, an optional `ceiling`. Same major is structural through the path, as is "no prerelease suffix on a bound unless opted in"; ordering is a kernel check, since CUE has no semver comparison.
- **`#ResolvedPlatform`** (RENAMED from the shipped `#Platform`, shape unchanged): the render-time value with its embedded catalogs and derived folds, generated per resolution and never authored.
- **`#CatalogEntry`** (UNCHANGED): `version` keeps its derivation and widens in meaning to "the version this build holds".
- **The registration window** is a catalog_opm contract change, not core: the `transformer-registration` resource's spec gains `floor` and `ceiling` defaulting to `version`, and the CR mirrors them in spec and reports the effective window in status.

## Affected Surfaces

**core.** One shipped definition renamed with its shape kept (`#Platform` to `#ResolvedPlatform`), one definition changed under the vacated name (`#Platform`, now the authored pure-data value) and one added (`#CatalogAdmission`). `#CatalogEntry.version`'s documented meaning widens from "the platform's pin" to "the version this build holds". SPEC.md gains sections for the authored platform and the admission entry and a paragraph on the resolved platform.

**library.** The render-module derivation of 0019 D13 changes its source on catalog paths: the module's committed list, bounded by the authored platform, instead of the resolved platform's. The kernel gains the resolved-platform generation, keyed by the resolved catalog set. Four refusals become kernel diagnostics: catalog not admitted, pin outside range, prerelease pin without opt-in, and a provider catalog whose shared-path requirement exceeds the consumer's pin. A fifth refuses a module importing two majors of one catalog (D9). Every render records the catalog versions it held. Each resolution holds one major per catalog and includes only the providers built against that major, and the module-less build for readiness and the inventory is split so no build holds two majors of one catalog (D9).

**opm-operator.** The Platform CRD's spec takes the authored `#Platform` shape: a map of catalogs with floor, optional ceiling, prerelease opt-in and optional registry, replacing an exact version per path. Registration acceptance reads the admission entry for the claimed catalog, if any, and writes the effective window and its source to the registration's status. A warning condition marks a platform range that exceeds the provider's declared window. Platform-package generation becomes per-resolution. Acceptance judges contract conflicts and the shared-path comparison per major of the declaring catalog, so providers serving different majors of one catalog are both accepted (D9), and readiness reports per slice of the split module-less build (OQ11).

**cli.** A render given a platform, by an explicit directory or by the cluster Platform, starts from an authored `#Platform` instead of a platform module, and its catalog versions come from the render's pins inside that platform's ranges rather than from the platform. A render given none stays platform-less (D3): it holds its own pins as today, but the resolved platform for it is generated by the kernel rather than by the CLI, so the CLI's own generation from the render's pins goes away. `opm platform check` evaluates against the static floors and the registration versions as reference versions, per slice when several majors of one catalog are admitted (OQ11).

**catalog_opm.** The `transformer-registration` contract gains `floor` and `ceiling` with `version` as their default, and the rendering transformer copies them to the CR.

## Before / After

**The three modules from the problem statement.** The platform admits `catalogs/opm@v4` with floor 4.0.0 and no ceiling.

| Module pins `opm` at | Before, platform at 4.3.0 | After |
| --- | --- | --- |
| 4.1.0 | renders at 4.3.0, silently | renders at 4.1.0 |
| 4.3.0 | renders at 4.3.0 | renders at 4.3.0 |
| 4.6.0 | refused, unknown key | renders at 4.6.0 |
| 3.9.0 | refused, different major | refused, `catalogs/opm@v3` not admitted |

Platform team later sets `floor: 4.2.0`. Before: a bump re-rendered all three. After: the 4.1.0 module is refused by name until its owner bumps; the other two do not move.

**The provider.** k8up module 2.1.0 pins `catalogs/k8up@v1` at 1.6.0 and declares floor 1.4.0, ceiling 1.8.0. No admission entry for the path.

| Consumer pins `k8up` at | Before | After |
| --- | --- | --- |
| nothing | 1.6.0, registration's version | 1.6.0, same |
| 1.7.0 | platform's version wins, pin inert | 1.7.0, inside the author's window |
| 1.9.0 | platform's version wins, pin inert | refused, above the installed provider's ceiling |

Platform team adds an admission entry for the path with ceiling 1.9.0. The 1.9.0 consumer renders, the registration's status reads `source: platform`, and a warning condition records that the platform exceeded the author's claim. Delete the entry and the author's window binds again.

## Worked Example

The same platform in the order data flows: the authored file, its CR form, one module's pin, and the resolved platform the kernel writes from them. The CUE forms compile in [`schemas/examples.cue`](schemas/examples.cue).

**The authored `#Platform`, the offline CLI file.** Pure data, no imports.

```cue
platform: core.#Platform & {
	metadata: name: "cluster"
	type: "kubernetes"
	catalogs: {
		"opmodel.dev/catalogs/opm@v4": {
			floor:   "4.0.0"
			ceiling: "4.6.0" // validated up to here
		}
		"opmodel.dev/catalogs/k8s@v1": floor: "1.0.0" // open ceiling: any GA v1 release from 1.0.0 up
		"opmodel.dev/catalogs/k8up@v1": {             // provider catalog: optional entry, overrides the author window (D6)
			floor:   "1.4.0"
			ceiling: "1.9.0"
		}
		"opmodel.dev/catalogs/experimental@v0": {
			floor:       "0.3.0"
			prereleases: true // -dev and -rc tags inside the range render
		}
		"opmodel.dev/catalogs/legacy@v3": {
			enable: false // kept on record, admits nothing
			floor:  "3.9.0"
		}
	}
}
```

**The same platform as the operator's CR.** Same fields, one nesting level down.

```yaml
apiVersion: opmodel.dev/v1alpha1
kind: Platform
metadata:
  name: cluster
spec:
  type: kubernetes
  catalogs:
    opmodel.dev/catalogs/opm@v4:
      floor: 4.0.0
      ceiling: 4.6.0
    opmodel.dev/catalogs/k8s@v1:
      floor: 1.0.0
    opmodel.dev/catalogs/experimental@v0:
      floor: 0.3.0
      prereleases: true
```

**A consumer module's committed pin**, unchanged from today.

```cue
deps: {
	"opmodel.dev/core@v2":         v: "v2.0.0-alpha.10"
	"opmodel.dev/catalogs/opm@v4": v: "v4.3.0"
}
```

**The `#ResolvedPlatform` the kernel generates for that render.** Its `cue.mod` carries opm at 4.3.0 from the module and k8up at 1.6.0 from the accepted registration. Nobody authors this file. `k8s@v1` is admitted but absent: the module never imported it and no registration supplied it (D4). A second module pinned at opm 4.5.0 gets its own resolved platform; one pinned at 4.3.0 shares this one.

```cue
package platform

import (
	core "opmodel.dev/core@v2"
	opm  "opmodel.dev/catalogs/opm@v4"  // resolves at v4.3.0: the module's pin
	k8up "opmodel.dev/catalogs/k8up@v1" // resolves at v1.6.0: the registration's version
)

platform: core.#ResolvedPlatform & {
	metadata: name: "cluster"
	type: "kubernetes"
	#registry: {
		"opmodel.dev/catalogs/opm@v4": {
			#catalog: opm
			version:  "4.3.0" // expected stamp: unifies with the catalog's readout, wrong bytes conflict here
		}
		"opmodel.dev/catalogs/k8up@v1": {
			#catalog: k8up
			version:  "1.6.0"
		}
	}
	// #composedTransformers and #contracts derive as before
}
```

**Admission outcomes against that platform.**

| Module pins | Outcome |
| --- | --- |
| `opm@v4` 4.3.0 | held at 4.3.0 |
| `opm@v4` 4.7.0 | refused: above ceiling 4.6.0, the platform's bound |
| `opm@v4` 4.3.0-dev.2 | refused: prerelease, entry admits GA only |
| `experimental@v0` 0.4.0-rc.1 | held: inside the range, prereleases on |
| `k8up@v1` 1.9.0 | held: inside the platform's override, warning on the registration since the author claimed 1.8.0 |
| `legacy@v3` 3.9.0 | refused: entry disabled |
| `foo@v1` any | refused: not admitted, no entry |
