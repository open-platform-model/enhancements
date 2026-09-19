# Specification changes: Module-Dictated Catalog Versions and the Generated Platform

<!--
Pre-drafts the core/SPEC.md co-update the core slice will need. One section
per NEW or CHANGED construct in SPEC.md's four-part format.
-->

## #Platform (CHANGED: now the authored platform)

### Definition

`#Platform` is the authored platform: the statement of which catalog lineages a platform admits and within what range of releases. It is pure data. It imports nothing and has no dependencies of its own, so the same value serves as the Platform CR's spec and as an offline file. The name moves to this value from the render-time registry 0019 D5 shipped under it, which becomes `#ResolvedPlatform`: what people author carries the public name, and what the kernel generates is named for what it is, a resolution. The kernel generates one `#ResolvedPlatform` per resolution from this value, the module's committed catalog pins, and the accepted registrations.

### Shape

```
#Platform: {
	kind: "Platform"
	metadata: {name!: #NameType, description?: string}
	type!: string
	catalogs: [Path=#ModulePathType]: #CatalogAdmission & {path: Path}
}
```

### Constraints

- `catalogs` MUST be keyed by the lineage's module path with its major, and the key MUST equal the entry's `path`; the binding is structural, so drift is a conflict naming the entry.
- There MUST be exactly one entry per path.
- A `#Platform` MUST NOT import a catalog or carry a `cue.mod` dependency on one. Loading is never the platform's act.
- A module importing a catalog path with no enabled entry MUST be refused as not admitted.

### Rationale

- **Why data and not a module.** A static import cannot float. Once the module's pin decides the version, the render-time value has to be produced after the pin is known; a platform that carries no import is what can be authored before and generated after.
- **Why one form for offline and cluster.** Two authored forms, a hand-written platform module and a CR, were kept in step by tests and by convention. One data shape with two carriers removes the drift.
- **Why admission is separate from loading.** One number was admitting a lineage and picking every instance's version at once, and the two jobs conflict as soon as two modules want different releases. The platform does the first job only.
- **Why this value takes the name.** The authored value is the one a platform team writes, reviews and versions; the CR is already called Platform. A `PlatformSpec` kind beside a `Platform` value is a Kubernetes nesting convention leaking into core, and it would have left the public name on a kernel artefact nobody authors. Core is pre-GA, so the rename is admissible now and would be a major later.

## #CatalogAdmission (NEW)

### Definition

`#CatalogAdmission` is one admitted catalog lineage: its identity, whether it is enabled, optionally where it resolves, the range of releases admitted, and whether prereleases count. It admits and bounds. It never loads: a catalog enters a render build by a consumer module's import or by an accepted registration, and the entry decides whether that is allowed and within what range.

### Shape

```
#CatalogAdmission: {
	path!:       #ModulePathType
	enable:      bool | *true
	registry?:   string
	prereleases: bool | *false
	floor!:      #VersionType
	ceiling?:    #VersionType
}
```

### Constraints

- `floor` MUST be present. It is the lowest release admitted and the version the platform's own module-less build imports this catalog at.
- `ceiling` MAY be absent. Absent admits every release of the major at or above the floor.
- Every version named MUST carry the path's major; this is checked structurally.
- With `prereleases` false, a pin carrying a prerelease suffix MUST be refused as not admitted even when its ordering falls inside the range, and `floor` and `ceiling` MUST NOT carry a prerelease suffix; the bound rule is checked structurally. With `prereleases` true, prerelease pins and bounds are admitted by ordering alone.
- `floor` MUST be at most `ceiling` when both are present; a consumer pin MUST lie in `[floor, ceiling]` or be refused naming the module, the path, the pin and the bound. These orderings are kernel checks: CUE has no semver comparison.
- A pin below the floor MUST be refused, never promoted.
- For a provider catalog's path an entry is OPTIONAL; when present its range replaces the registration's declared window, and acceptance MUST record which one is in effect.
- `registry`, when present, names where the path resolves and MUST NOT be read as identity; identity is the path.

### Rationale

- **Why the floor is required.** The module-less readiness build and the contract inventory need a version to import each static catalog at. The floor is that version; an absent floor would leave nothing to build against.
- **Why the ceiling is optional.** A required ceiling means a platform edit per catalog release before any module may use it, which is the throttle the design removes. The additive discipline within a major is what makes an open upper bound tolerable, and a platform that wants to validate first authors one.
- **Why refuse rather than promote.** Promotion is a silent move of an instance to a version its owner never named, applied on every reconcile. Refusal names the instance and leaves the owner the act. Raising the floor is therefore a loud fleet-wide lever.
- **Why GA releases by default.** Semver orders `4.3.0-dev.5` above `4.2.0`, so a range that admits by ordering alone admits every development tag that lands inside it. A platform team that has not opted in never meant that; the flag makes admitting prereleases a stated act, per lineage.
- **Why the same shape for provider catalogs.** One vocabulary for static and dynamic catalogs; only the version source differs, and that is a resolution rule, not a schema.

## #ResolvedPlatform (RENAMED from #Platform, shape unchanged)

### Definition

`#ResolvedPlatform` is the render-time value 0019 D5 shipped as `#Platform`: a path-keyed registry of `#CatalogEntry` values, each carrying its imported catalog whole, with the derived `#composedTransformers` fold and the `#contracts` inventory. Only the name moves. It is generated by the kernel per resolution from the authored `#Platform`, the consumer module's committed pins and the accepted registrations, and is never authored.

### Shape

Unchanged from SPEC.md § 3.4, under the new name; `kind` reads `"ResolvedPlatform"`.

### Constraints

- Unchanged. In addition: a `#ResolvedPlatform` MUST carry exactly one entry per catalog the build holds, at the version the build holds it (the consumer's pin, or the registration's version for a provider catalog nobody pinned), and an admitted lineage nothing imported MUST be absent.

### Rationale

- **Why rename rather than keep.** The shipped value is consumed by the kernel and nothing else; the authored value is what users read. Giving the public name to the generated artefact would have made every platform team's file a "spec" of something they never see.

## #CatalogEntry (CHANGED vs SPEC.md §3.4, meaning only)

### Definition

No field changes. `version` keeps its derivation from the embedded catalog's stamped identity and widens in meaning: it is the version this build holds, which is the module's pin when a consumer pins the path, the registration's version for a provider catalog nobody pinned, and the floor in the platform's own module-less build.

### Shape

Unchanged.

### Constraints

- Unchanged. The stamped-expected-versus-derived `version` tripwire holds per build: the kernel stamps the version it wrote into the generated platform's dependency list.

### Rationale

- **Why widen rather than add a field.** The readout already answers "what does this build hold"; only the sentence describing it assumed the platform's pin was the sole answer.
