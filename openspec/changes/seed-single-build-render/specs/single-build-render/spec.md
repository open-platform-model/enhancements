## Purpose

Render an instance against a platform as one build. The kernel stages the instance and platform sources into a generated render module, evaluates it once in a context that ends with the render, and reads the matching verdicts and the rendered objects off the built value.

## ADDED Requirements

### Requirement: Render inputs are source-carrying artifacts

A render SHALL take an instance and a platform that both carry their source, plus a non-empty runtime name and a version skew policy. It SHALL refuse an input that carries no source, naming the input. An evaluated value alone is never enough, because the render build imports packages.

#### Scenario: A platform without source is refused

- **WHEN** a render is given a platform built from a bare evaluated value
- **THEN** it is refused with an error naming the platform's missing source, and no build is attempted

#### Scenario: An instance held in memory is accepted

- **WHEN** a render is given a synthesized instance whose source is an in-memory tree
- **THEN** the tree is served to the build from memory, no file of it is written, and the build proceeds

#### Scenario: An empty runtime name is refused

- **WHEN** a render is given an empty runtime name
- **THEN** it is refused before staging

### Requirement: The render's dependency list is derived by promotion

The render SHALL derive its module's dependency list by promotion: the platform's tidied list whole, the instance's entries added for paths only the instance carries, and the platform winning every shared path. It SHALL run no tidy and consult no registry to compute the list. Both inputs SHALL enter the build from local directories. Each input's own path SHALL be listed with a placeholder version and marked the default major, so its unqualified self-import resolves.

#### Scenario: The platform wins a shared path

- **WHEN** the instance requires catalog build 1.3.0 and the platform carries 1.2.0 for the same path
- **THEN** the render lists 1.2.0, and the build evaluates the platform's catalog

#### Scenario: Instance-only paths survive

- **WHEN** the instance depends on a path the platform does not carry
- **THEN** the render lists the instance's entry for that path, and the instance's import resolves

#### Scenario: An input's unqualified self-import resolves

- **WHEN** the instance's root package imports one of its own subpackages without a major qualifier, and the instance enters the build from a directory
- **THEN** the render marks the instance's major as the default, and the build resolves the import from that directory

### Requirement: Local replacements are promoted under dependency precedence

When local replacements are enabled, each input's local replacements SHALL be promoted under the precedence its dependencies get: the platform's whole, the instance's only for paths the platform's list does not name. A relative directory target SHALL be resolved against that input's own root. A replaced path the list lacks SHALL be listed with a placeholder version. A dependency with no version and no covering replacement SHALL be refused before staging, naming the path and the input.

#### Scenario: A platform replacement of its catalog is honoured

- **WHEN** local replacements are enabled and the platform replaces its catalog path with a directory whose transformer output differs from the published build
- **THEN** the build evaluates the directory's transformers, and the render's replacement rows name the path, the directory and the platform as the source

#### Scenario: An instance replacement on a platform-named path is inert

- **WHEN** local replacements are enabled and the instance replaces a path the platform's list carries
- **THEN** the render carries no replacement for that path, the build evaluates the platform's pinned bytes, and no replacement row names the path

#### Scenario: An instance replacement on an instance-only path is honoured

- **WHEN** local replacements are enabled and the instance replaces a path the platform does not carry with a relative directory
- **THEN** the build resolves the instance's import from that directory, taken against the instance's root, and a replacement row names the path, the absolute directory and the instance

#### Scenario: A replace-only dependency is listed with a placeholder

- **WHEN** local replacements are enabled and the instance lists a dependency with no version that its replacement file replaces with a directory
- **THEN** the render lists the path with a placeholder version of its major, and the render proceeds

#### Scenario: A version-less dependency without a replacement is refused

- **WHEN** an input lists a dependency with no version and no promoted replacement covers the path
- **THEN** the render fails before staging with an error naming the path and the input, and no module-file formatting error is shown

### Requirement: Local replacements need the caller's opt-in

A render SHALL take a per-render opt-in for local replacements, off by default. With it off, an input that carries at least one replacement SHALL be refused before staging, naming the input and its replacement file, and the file SHALL NOT be ignored. With it on, each honoured replacement SHALL be reported as a data row with the replaced path, the absolute target and the supplying input, in path order. An input without the file SHALL behave the same either way.

#### Scenario: A replacement without the opt-in is refused

- **WHEN** a render runs with the opt-in off and the platform's replacement file replaces its catalog path
- **THEN** it is refused with an error naming the platform and the file, no render module is staged, and no staging file is written

#### Scenario: Inputs without a replacement file are unaffected

- **WHEN** a render runs with the opt-in on and neither input carries a replacement file
- **THEN** its output and diagnostics are byte-identical to the same render with the opt-in off, and the replacement rows are empty

#### Scenario: Replacement rows are data

- **WHEN** a render with the opt-in on honours one platform replacement and one instance replacement
- **THEN** the diagnostics carry exactly two replacement rows, sorted by path, each naming its source input, and no field of the result holds a formatted message about them

### Requirement: A render refuses an uncovered OPM-namespace path

After writing the dependency list, the render SHALL check, against the list the build is actually served, that every OPM-namespace path either input requires is listed. It SHALL otherwise refuse, naming the uncovered path as a defect of the renderer. No caller SHALL be able to configure this refusal away.

#### Scenario: An uncovered path refuses

- **WHEN** promotion produces a list that lacks an OPM-namespace path one input requires
- **THEN** the render fails before evaluation with an error naming the path, whatever skew policy is set

### Requirement: Version skew follows a caller-chosen policy

For each OPM-namespace path, the render SHALL compare the instance's requirement with the platform's own entry, never with the promoted list. When the instance requires a newer build, the caller's policy decides: warn-and-render, the default, marks the path's row as newer, and refuse fails the render before evaluation. Order SHALL follow SemVer precedence, prereleases included. An older requirement SHALL give no mark, and every path's comparison SHALL be present as plain data.

#### Scenario: A newer module warns and renders by default

- **WHEN** the instance requires catalog 1.3.0, the platform carries 1.2.0, and no policy is set
- **THEN** the render proceeds against 1.2.0, the row for that path names both versions and is marked newer, and the result carries no message for it

#### Scenario: The refuse policy stops the render

- **WHEN** the same skew exists and the caller chose the refuse policy
- **THEN** the render fails before evaluation with an error naming the path and both versions

#### Scenario: An older module is data, not a warning

- **WHEN** the instance requires 1.1.0 and the platform carries 1.2.0
- **THEN** the render proceeds, the row for that path is present in the diagnostics, and it is not marked newer

#### Scenario: Prerelease builds compare by SemVer precedence

- **WHEN** an instance requires 2.0.0-beta.10 of a path, against a platform carrying 2.0.0-beta.2 and against one carrying 2.0.0
- **THEN** the row against 2.0.0-beta.2 is marked newer and the row against 2.0.0 is not

### Requirement: Matching runs in the build and yields data

The render SHALL match components to transformers inside the one build and SHALL decode the verdicts as data, without deriving, joining or re-sorting them: matched pairs, unresolved demands, refused candidates with the contracts they conflicted at, unmatched components with their candidates and any missing labels, unhandled traits and over-subscription rows. The unification and label rungs SHALL run only for the transformers the demand walk reached for a component.

#### Scenario: An unmatched component carries its candidates

- **WHEN** a component's only candidate is refused by the label predicate on one required label
- **THEN** the diagnostics list the component as unmatched with that candidate and the missing label, and the typed unmatched-components cause carries the same row

#### Scenario: A unify refusal names its conflicts once

- **WHEN** a candidate's required body conflicts with the component's body at two contracts
- **THEN** the diagnostics carry one unify-refusal row for that component and transformer listing both, and the demand's disqualified list names the same transformer with the same contracts

### Requirement: The demand gate fails closed

An unresolved demand, or an unmatched component, SHALL refuse the render while the diagnostics stay readable and decoded. The matched pair set SHALL equal the set plain predicate matching gives over the same inputs. The unification rung SHALL be plain unification with no provenance exclusion.

#### Scenario: Verdicts decode beside a failing gate

- **WHEN** a component demands a resource that no transformer on the platform requires
- **THEN** the render fails, and the returned error carries a decoded unresolved-demand row for that instance, component and key, with the platform's same-base alternatives in ladder order

#### Scenario: The pair set equals plain predicate matching

- **WHEN** a render runs over inputs that plain predicate matching also matches
- **THEN** the reported pair set equals the set plain predicate matching gives

### Requirement: Failed pairs are named from their rendered output

The render SHALL unify each matched pair's transform once and SHALL name the failed pairs, in pair order, from each pair's rendered output. A pair is failed when its output is an error anywhere inside it, or when its root cannot be resolved to a struct or a list. An output whose only defect is non-concrete fields SHALL NOT be listed; the concreteness check refuses it. The failed pairs SHALL be filled on every refusal raised after the build, a gate refusal included, and left empty on success.

#### Scenario: Healthy pairs render beside a failing pair

- **WHEN** one matched pair's transformer errors while sibling pairs are healthy
- **THEN** the failing pair is reported as data naming the pair, and the sibling verdicts remain readable

#### Scenario: Failed pairs are reported on a gate refusal

- **WHEN** one component's demand is unresolved, so the gate refuses, while another component's matched pair has a transformer whose output conflicts
- **THEN** the render fails with a refusal whose cause is the gate's, and its failed pairs name the conflicting pair and no other

#### Scenario: A non-concrete output is not a failed pair

- **WHEN** a matched pair's output is a struct whose only defect is a non-concrete field
- **THEN** the pair is not listed as failed, and the concreteness check refuses the render at a path naming the pair

### Requirement: Rendered output carries provenance and is concrete

On a passing gate the render SHALL return the rendered objects in the build's deterministic order, each carrying its instance, its component and its transformer. The render SHALL check per-pair concreteness itself: an incomplete pair output that is not an error SHALL fail the render at a path naming the pair.

#### Scenario: Provenance on every object

- **WHEN** a render of two matched pairs succeeds
- **THEN** every returned object names its instance, component and transformer

#### Scenario: Incomplete pair output refuses

- **WHEN** a transformer's output evaluates non-concrete without erroring
- **THEN** the render fails with an error whose path names the component and transformer pair

### Requirement: Render is the kernel's sole render path

The kernel SHALL render an instance against a platform by one verb only. It SHALL offer no separate compile, match or materialize step; a dry run is a render with its output discarded, since the build evaluates every matched pair regardless. A render SHALL be refused for a platform that does not carry its catalogs by import: a registry entry that names no embedded catalog is not rendered, because the entry's version is read from the catalog's stamped identity.

#### Scenario: The old entry points are gone

- **WHEN** a consumer inspects what the kernel offers
- **THEN** it finds no compile, match or materialize verb and no materialized-platform type

#### Scenario: A subscription-shaped platform is not rendered

- **WHEN** a render is asked for a platform that declares a registry entry with a version and no embedded catalog
- **THEN** the render is refused with a missing-required-field error that names the entry's version, and no build is attempted

### Requirement: The single-provider guard runs inside the build

The render SHALL read the provider count from the platform's contract inventory and compute none of its own. A provider-fulfilled contract that transformers of two or more enabled registry entries require SHALL be an over-subscription row naming the key and the entries, and SHALL refuse the render. An entry is counted as the contract-fulfilment capability states. Catalog-fulfilled contracts SHALL admit any number of suppliers.

#### Scenario: A second provider is refused in the build

- **WHEN** two catalogs embedded in the platform each supply a transformer requiring a contract declared provider-fulfilled
- **THEN** the render fails with a typed over-subscription cause whose row names the key and both registry keys, and the diagnostics remain readable beside the refusal

#### Scenario: Catalog-fulfilled plurality is allowed

- **WHEN** many transformers across catalogs require a contract with default catalog fulfilment
- **THEN** the render proceeds, and every candidate takes part in matching

#### Scenario: Two majors of one catalog are two providers

- **WHEN** the platform enables two majors of one catalog, and a transformer of each requires the first major's provider-fulfilled gateway contract
- **THEN** the render fails with one over-subscription row naming the gateway key and both registry keys, and the platform's inventory reads the same key as over-subscribed and not routable

#### Scenario: Providers count when the defining catalog is disabled

- **WHEN** the platform carries the defining catalog entry disabled, and enables two other entries whose transformers both require the gateway contract
- **THEN** the render fails with one over-subscription row naming the key and those two entries, and the inventory reads the same key as over-subscribed

#### Scenario: The inventory and the render agree on every served platform

- **WHEN** every served render platform is acquired, its inventory read, and its classified instance rendered against it
- **THEN** the inventory's over-subscribed keys equal the keys of the render's rows, every row's entries equal the inventory's providers for its key, and the routable verdict is true exactly when the render carries no over-subscription row

### Requirement: Unresolved demands are diagnosed with alternatives

A demand with no candidate, or only disqualified ones, SHALL be an unresolved row carrying the component, key, kind, the same-base alternatives in ladder order, the defining catalog, an unprovided mark and the disqualified candidates. It SHALL tell three cases apart: defined but implemented by nothing, implemented at another apiVersion, and defined by no enabled catalog. The defining catalog is diagnostic only.

#### Scenario: An undemandable resource fails the render

- **WHEN** a component demands a resource contract that no embedded catalog implements or lists
- **THEN** the render fails with an unresolved-demands cause whose row has no alternatives and no defining catalog, and the message says no enabled catalog defines the contract

#### Scenario: A different apiVersion is named

- **WHEN** the platform implements one contract base at alpha, beta and GA versions only, and the component demands another version
- **THEN** the row lists the alternatives in ladder order, alpha before beta before GA

#### Scenario: A defined but unimplemented contract names its catalog

- **WHEN** an enabled catalog lists a trait in its contract maps, no transformer requires it, and a component attaches it load-bearing
- **THEN** the render fails with a row that carries the catalog's registry key as the defining catalog and no alternatives, and the message names the catalog beside the component and key

#### Scenario: A disabled catalog defines nothing

- **WHEN** the only catalog listing the demanded key is a registry entry that is disabled
- **THEN** the row carries no defining catalog

#### Scenario: An unprovided row says so

- **WHEN** a component attaches a load-bearing trait whose contract an enabled catalog lists as provider-fulfilled, and no transformer requires it
- **THEN** the row is marked unprovided, and its message names the defining catalog and then says that the contract is provider-fulfilled and nothing on the platform provides it

#### Scenario: A catalog-fulfilled row is not marked

- **WHEN** a component attaches a load-bearing trait with default catalog fulfilment that no transformer handles
- **THEN** the row is not marked unprovided, and its message carries no provider-fulfilled text

### Requirement: Trait posture governs unhandled traits

An unhandled trait's effect SHALL follow its effective optional value on the component's attachment. An effectively optional trait SHALL be reported in the unhandled-trait table and the render proceeds. An effectively load-bearing trait SHALL fail exactly as an unresolved resource. A posture that is not stated SHALL fail closed as a build error naming the trait's own optional field.

#### Scenario: An optional trait warns

- **WHEN** an unhandled trait's effective optional value is true
- **THEN** the render proceeds, the unhandled-trait table maps the component to the trait, and the result carries no message for it

#### Scenario: A load-bearing trait fails

- **WHEN** an unhandled trait's effective optional value is false
- **THEN** the render fails with an unresolved-demands cause carrying a row for the trait

#### Scenario: An unstated posture fails closed

- **WHEN** an unhandled trait has no stated optional value
- **THEN** the render fails with a build error that names the trait's optional field

### Requirement: The label predicate covers every admitted label type

The label predicate SHALL compare a transformer's required labels with the component's matching labels by unification, so every value type the label schema admits takes part, and a mismatch on any admitted type SHALL disqualify the candidate.

#### Scenario: A non-string label value is compared

- **WHEN** a transformer requires a label whose value is a non-string type the schema admits, and the component carries a different value
- **THEN** the candidate is disqualified, not silently skipped

### Requirement: A render result carries no presentation strings

A render result and a render refusal SHALL expose verdicts as structured rows only. The kernel SHALL attach no human-readable warning to a result. Every advisory fact SHALL be readable from the diagnostics rows, and the diagnostics SHALL document where each lives. Each row-carrying typed gate cause SHALL carry the same rows as the diagnostics, in the same order, and SHALL NOT synthesize a cause of another kind. The not-routable cause carries no rows.

#### Scenario: Advisory facts are rows

- **WHEN** a render succeeds with one unhandled optional trait and one path in warn-mode skew
- **THEN** the result shows the trait in the unhandled-trait table and the path in a row marked newer, and no field of the result holds a formatted message

#### Scenario: A gate cause is the diagnostics rows

- **WHEN** a render is refused on two unresolved demands, or on an over-subscribed contract
- **THEN** the unresolved-demands cause, or the over-subscription cause, found through the error chain carries exactly the rows the diagnostics carry, and unwrapping it yields no cause of a different kind

### Requirement: The render module's gate agrees with the kernel

The generated render module SHALL carry a gate that evaluates to an error exactly when the kernel refuses the render on a decoded verdict, and to true otherwise, so a staged module refuses by itself under plain CUE evaluation. The kernel's decoded refusal SHALL remain the authoritative one, since it carries the typed causes, and SHALL be decided from decoded rows only, never by reading the gate.

#### Scenario: A refusal is visible in the module

- **WHEN** a render is refused on an unmatched component, or on an over-subscribed contract
- **THEN** the built value's gate is an error, and the diagnostics beside it decode

#### Scenario: Success is visible in the module

- **WHEN** a render passes the gate
- **THEN** the built value's gate is true

### Requirement: A platform with an old core is refused

Before staging, a render SHALL check that the platform's core carries the provider count, as recorded when the platform was built. A platform pinning a core older than 2.0.0-alpha.12, or with no contract inventory, SHALL be refused with a typed error naming the platform, the missing field and the first release that carries it. The refusal SHALL stage nothing, SHALL NOT be a render refusal, and SHALL NOT fall back to a count of its own. A platform SHALL stay shareable across concurrent renders.

#### Scenario: An older-core platform is refused before staging

- **WHEN** a platform identical to a served one but pinning core 2.0.0-alpha.10 is rendered
- **THEN** the error names the platform, the field for the provider count and the release 2.0.0-alpha.12, it is not a render refusal, no result is returned, and no staging file is written

#### Scenario: A current-core platform is not affected

- **WHEN** a platform pinning core 2.0.0-alpha.12 or later is rendered
- **THEN** the core check raises no error and the render proceeds to staging

#### Scenario: A platform shared by concurrent renders stays race-free

- **WHEN** one acquired current-core platform is shared by several goroutines, each rendering on one kernel
- **THEN** every render passes the core check and produces the same objects, with no data race under the race detector

#### Scenario: A render reads no evaluated platform value

- **WHEN** a current-core platform is acquired, its evaluated value is replaced with an empty one, and it is rendered with an acquired instance
- **THEN** the core check raises no error and the render produces the same objects as a render of the unchanged platform

### Requirement: An unexplained not-routable platform is refused

The render SHALL decode the platform's routable verdict onto the diagnostics, and SHALL refuse with a typed not-routable cause when it reads false and the diagnostics carry no over-subscription row. That cause SHALL be the last joined cause. It keeps the kernel's decision in step with the render module's gate when a later core adds a term to the verdict that no row reports.

#### Scenario: No served platform raises the catch-all

- **WHEN** every served render platform is rendered
- **THEN** no refusal carries the not-routable cause, and the decoded routable diagnostic equals the inventory's verdict

#### Scenario: An unexplained verdict refuses

- **WHEN** the gate is given diagnostics whose routable verdict is false and which carry no over-subscription row
- **THEN** the gate refuses with the typed not-routable cause, joined after every other cause present

### Requirement: Each render is its own in-memory build

Each render SHALL create a fresh evaluation context, build its staged module once with it, and release its own references when it returns. A result the caller still holds keeps the build alive. No built value SHALL be shared between renders. The render module SHALL be staged in memory under a fixed synthetic root, absolute on every operating system, that does not exist on disk. Staging SHALL refuse, naming the root, when anything exists there. Nothing of either input is copied or written.

#### Scenario: Repeated renders share nothing

- **WHEN** a render is run twice with the same inputs
- **THEN** each run stages, builds and decodes independently, and the results are byte-identical

#### Scenario: The render module is served from memory

- **WHEN** a render of an in-memory instance against an in-memory platform is staged
- **THEN** the staged overlay carries the generated module files and glue under the synthetic root, and every input file under that root's instance or platform directory, and the synthetic root does not exist on disk before or after the build

#### Scenario: An existing render root is refused

- **WHEN** a directory holding a CUE file of the render package, or a plain file, exists at the synthetic root and a render module is staged
- **THEN** staging fails with an error naming the root, and nothing is staged or built

#### Scenario: A render works on every operating system

- **WHEN** a render runs on any operating system the library supports
- **THEN** the staged module is accepted by the build, because its synthetic root is an absolute path there

#### Scenario: Local replacements resolve from an in-memory render module

- **WHEN** a render module whose replacement file replaces input and catalog paths with on-disk directories is served from memory under the synthetic root
- **THEN** the one build resolves every replaced path from its directory, and the same build with the replacement file left out of the overlay fails to resolve the replaced input

#### Scenario: Concurrent renders share the synthetic root

- **WHEN** several goroutines build render modules staged under the same synthetic root at the same time
- **THEN** every build succeeds with the same result as a sequential build, and the race detector reports nothing

### Requirement: A render writes no staging file

A render SHALL create, write or remove nothing under the process temp directory and nothing at the synthetic root, on success, on a refusal before staging, on a refusal before evaluation, and on a build failure. The CUE module cache is not staging: a build that fetches a dependency fills it as any load does.

#### Scenario: A successful render leaves the temp directory untouched

- **WHEN** the process temp directory is a directory the check owns and empty, and a served instance is rendered against a served platform
- **THEN** the render succeeds, the directory is still empty, and the synthetic root does not exist on disk

#### Scenario: A refusal leaves the temp directory untouched

- **WHEN** the temp directory is empty and a render is refused for an older-core platform, for a local replacement without the opt-in, for an instance dependency with no version and no replacement, and for catalog skew under the refuse policy, and another render fails to load a module nothing serves
- **THEN** each call returns its refusal, the directory is still empty, and the synthetic root does not exist on disk

#### Scenario: A fetched dependency fills only the module cache

- **WHEN** a render's build fetches a dependency from a registry
- **THEN** the CUE module cache is filled as for any load, and nothing is created under the process temp directory or at the synthetic root
