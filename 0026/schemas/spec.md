# Specification changes: Module-Dictated Catalog Versions and the Generated Platform

<!--
Pre-drafts the core/SPEC.md co-update the core slice will need. One section
per NEW or CHANGED construct in SPEC.md's four-part format.
-->

## #PlatformSpec (NEW)

### Definition

`#PlatformSpec` is the authored platform: the statement of which catalog lineages a platform admits and within what range of releases. It is pure data. It imports nothing and has no dependencies of its own, so the same value serves as the Platform CR's spec and as an offline file. The render-time `#Platform` is not authored from it by hand; the kernel generates one per resolution from this value, the module's committed catalog pins, and the accepted registrations.

### Shape

```
#PlatformSpec: {
	kind: "PlatformSpec"
	metadata: {name!: #NameType, description?: string}
	type!: string
	catalogs: [Path=#ModulePathType]: #Subscription & {path: Path}
}
```

### Constraints

- `catalogs` MUST be keyed by the lineage's module path with its major, and the key MUST equal the entry's `path`; the binding is structural, so drift is a conflict naming the entry.
- There MUST be exactly one entry per path.
- A `#PlatformSpec` MUST NOT import a catalog or carry a `cue.mod` dependency on one. Loading is never the spec's act.
- A module importing a catalog path with no enabled entry MUST be refused as not admitted.

### Rationale

- **Why data and not a module.** A static import cannot float. Once the module's pin decides the version, the platform value has to be produced after the pin is known; a spec that carries no import is what can be authored before and generated after.
- **Why one form for offline and cluster.** Two authored forms, a hand-written platform module and a CR, were kept in step by tests and by convention. One data shape with two carriers removes the drift.
- **Why admission is separate from loading.** One number was admitting a lineage and picking every instance's version at once, and the two jobs conflict as soon as two modules want different releases. The spec does the first job only.

## #Subscription (NEW)

### Definition

`#Subscription` is one admitted catalog lineage: its identity, whether it is enabled, optionally where it resolves, and the range of releases admitted. It admits and bounds. It never loads: a catalog enters a render build by a consumer module's import or by an accepted registration, and the entry decides whether that is allowed and within what range.

### Shape

```
#Subscription: {
	path!:     #ModulePathType
	enable:    bool | *true
	registry?: string
	floor!:    #VersionType
	ceiling?:  #VersionType
}
```

### Constraints

- `floor` MUST be present. It is the lowest release admitted and the version the platform's own module-less build imports this catalog at.
- `ceiling` MAY be absent. Absent admits every release of the major at or above the floor.
- Every version named MUST carry the path's major; this is checked structurally.
- `floor` MUST be at most `ceiling` when both are present; a consumer pin MUST lie in `[floor, ceiling]` or be refused naming the module, the path, the pin and the bound. These orderings are kernel checks: CUE has no semver comparison.
- A pin below the floor MUST be refused, never promoted.
- For a provider catalog's path an entry is OPTIONAL; when present its range replaces the registration's declared window, and acceptance MUST record which one is in effect.
- `registry`, when present, names where the path resolves and MUST NOT be read as identity; identity is the path.

### Rationale

- **Why the floor is required.** The module-less readiness build and the contract inventory need a version to import each static catalog at. The floor is that version; an absent floor would leave nothing to build against.
- **Why the ceiling is optional.** A required ceiling means a platform edit per catalog release before any module may use it, which is the throttle the design removes. The additive discipline within a major is what makes an open upper bound tolerable, and a platform that wants to validate first authors one.
- **Why refuse rather than promote.** Promotion is a silent move of an instance to a version its owner never named, applied on every reconcile. Refusal names the instance and leaves the owner the act. Raising the floor is therefore a loud fleet-wide lever.
- **Why the same shape for provider catalogs.** One vocabulary for static and dynamic catalogs; only the version source differs, and that is a resolution rule, not a schema.

## #CatalogEntry (CHANGED vs SPEC.md §3.4, meaning only)

### Definition

No field changes. `version` keeps its derivation from the embedded catalog's stamped identity and widens in meaning: it is the version this build holds, which is the module's pin when a consumer pins the path, the registration's version for a provider catalog nobody pinned, and the floor in the platform's own module-less build.

### Shape

Unchanged.

### Constraints

- Unchanged. The stamped-expected-versus-derived `version` tripwire holds per build: the kernel stamps the version it wrote into the generated platform's dependency list.

### Rationale

- **Why widen rather than add a field.** The readout already answers "what does this build hold"; only the sentence describing it assumed the platform's pin was the sole answer.
