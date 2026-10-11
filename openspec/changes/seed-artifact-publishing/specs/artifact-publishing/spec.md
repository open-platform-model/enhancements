## Purpose

State the identity-driven pipeline behind publishing a module or a catalog. The registry coordinate comes from the identity the artifact commits, every gate runs and reports together in one fixed shape, the resolved plan doubles as the dry run, and a published version is never replaced.

## ADDED Requirements

### Requirement: One pipeline serves module and catalog publish

Publishing a module and publishing a catalog SHALL share one implementation. It SHALL load the artifact tree and its identity package, validate the identity package by unifying it with core's `#IdentityPackage` so that CUE's own diagnostic reaches the author, run the gates, and push through CUE's module machinery with the credentials that reads use.

#### Scenario: A clean artifact publishes at its declared version

- **WHEN** a conformant artifact with a concrete identity is published
- **THEN** the plan prints, the push targets the declared repository at the tag of the declared version, and the command exits 0

#### Scenario: Identity is validated by unification

- **WHEN** the identity package has a renamed, mistyped or missing required field
- **THEN** publish refuses with CUE's unification error, carrying the file and line
- **AND** it prints no hand-written expected-versus-found message

#### Scenario: A tree that does not load surfaces the load error

- **WHEN** the artifact tree fails to load
- **THEN** publish surfaces the load error verbatim
- **AND** it reports no refusal derived from identity

### Requirement: Coordinates are read, never composed

The registry repository and the major SHALL come from the module path the artifact declares, and the tag from the version it declares. Publish SHALL NOT compose a coordinate from parts. It SHALL NOT edit the artifact to match a coordinate.

#### Scenario: The coordinate follows the declared path

- **WHEN** an artifact declares a module path that ends in major v2
- **THEN** the plan shows the repository without the major and the major v2

#### Scenario: Publish leaves a concrete artifact untouched

- **WHEN** the declared path and version are both concrete
- **THEN** publish writes nothing to the artifact tree

### Requirement: The pushed bytes are the artifact directory

What publish pushes SHALL be the artifact directory as it stands, zipped whole. Publish SHALL NOT push a copied build directory and SHALL NOT add generated files. The only change publish makes to the tree is filling an open version, and it makes that change before the bytes are formed.

#### Scenario: No generated files are pushed

- **WHEN** publish forms the bytes to push
- **THEN** they hold the files of the artifact directory and nothing generated

#### Scenario: A dry run changes nothing on disk

- **WHEN** a dry run is made with an open version and a version to fill it
- **THEN** the plan shows the fill and the tree is not written

### Requirement: Every evaluable gate runs in a fixed order

Publish SHALL evaluate every gate it can and report all refusals in one pass. The order SHALL be: the tree loads, identity conforms, the kernel accepts a module, the agreement and namespace gates, the override gate, the catalog member gates, the registry gates. A tree with no module configuration or that does not load SHALL stop at once. One cause SHALL yield one refusal.

#### Scenario: Several defects are reported in one pass

- **WHEN** an artifact has both a coordinate disagreement and a namespace defect
- **THEN** one invocation reports both refusals

#### Scenario: A tree with no module configuration stops at once

- **WHEN** the tree has no module configuration
- **THEN** publish reports that refusal alone

#### Scenario: Local gates run before the registry is asked

- **WHEN** a local gate refuses and the registry is also unreachable
- **THEN** the local refusal is reported with the registry failure

### Requirement: A refusal has one fixed shape

Every refusal SHALL state the condition, then the evidence, the consequence and the action, leaving a part out only where it adds nothing. Disagreeing values SHALL print in aligned columns that name the file, and the line where known, that declares each. The action SHALL name what clears the condition, as a runnable command where one exists. A refusal whose diagnostic is CUE's SHALL carry CUE's own error.

#### Scenario: Disagreeing values name their files

- **WHEN** the version in the metadata differs from the version in the identity package
- **THEN** the refusal prints both values in aligned columns with the file and line of each
- **AND** the action shows how to derive the one from the other

#### Scenario: A CUE diagnostic is kept

- **WHEN** a refusal comes from CUE's evaluation
- **THEN** it carries CUE's error with its file and line

### Requirement: Identity must be concrete and consistent

Publish SHALL refuse an identity field that is absent or unfilled, since nothing then derives a coordinate or a tag. A field that carries a default SHALL count as concrete at that default. The path and the version in the artifact's metadata SHALL equal those of its identity package, and publish SHALL refuse when they differ.

#### Scenario: An unfilled module path is refused

- **WHEN** the identity declares the module path but gives it no value
- **THEN** publish refuses, saying there is nothing to derive a coordinate from

#### Scenario: A defaulted version is concrete

- **WHEN** the identity version carries a default
- **THEN** the tag derives from that default and the plan says so

#### Scenario: Metadata that does not derive from identity is refused

- **WHEN** the metadata states a path that the identity package does not
- **THEN** publish refuses, naming both values and the file of each

### Requirement: The module configuration must agree with the artifact

The module configuration SHALL declare the same module path as the identity package and SHALL declare the committed directory as its source. When it is absent, publish SHALL refuse and point to the module init command; it SHALL NOT create or edit it. A module's root package name SHALL equal its declared name.

#### Scenario: Two declarations of the path disagree

- **WHEN** the module configuration declares a path other than the identity's
- **THEN** publish refuses, naming both values and the file of each, and does not choose between them

#### Scenario: A missing module configuration is not created

- **WHEN** the tree has no module configuration
- **THEN** publish refuses, points to the init command and writes no file

#### Scenario: A package name that differs from the module name is refused

- **WHEN** a module's root package name differs from its declared name
- **THEN** publish refuses and names the package line to rename
- **AND** a catalog publish applies no such check

### Requirement: Namespace gates bind owned domains only

On a domain OPM owns, the declared path SHALL fit the namespace shape of that domain, and its kind segment SHALL agree with the command: a module under a module segment, a catalog under the catalog segment. Outside the owned domains publish SHALL assert nothing about the path, because path ownership is domain ownership.

#### Scenario: A catalog filed under a module segment is refused

- **WHEN** a catalog on an owned domain declares a path under a module segment
- **THEN** publish refuses and names the segment the kind belongs under

#### Scenario: Unowned domains are not policed

- **WHEN** a third-party artifact under its own domain is published
- **THEN** no namespace or kind-segment gate refuses it

### Requirement: Local overrides are ignored and refused

Publish SHALL always resolve dependencies as published, so local replacements SHALL be ignored and never baked in. When replacements are present, publish SHALL report each beside the registry version that supersedes it and SHALL refuse. A module author MAY waive that refusal, and the waiver SHALL NOT change resolution. A catalog SHALL have no waiver.

#### Scenario: A catalog with an override is always refused

- **WHEN** a catalog tree carries local replacements and the waiver is supplied
- **THEN** publish refuses

#### Scenario: A module waives the gate only

- **WHEN** a module tree carries local replacements and the waiver is supplied
- **THEN** publish proceeds and the published artifact resolves against published dependencies

### Requirement: The version option fills or asserts

The version option of either command SHALL fill an open identity version, writing the working tree, or assert one already concrete. A disagreement with a concrete value SHALL refuse, naming both values and the command that sets a version. The option SHALL NOT fill an absent field. An open version with no option SHALL refuse.

#### Scenario: An open version is filled, then published

- **WHEN** the identity version is open and the option supplies 1.3.0
- **THEN** the identity file holds 1.3.0 and the publish proceeds at tag v1.3.0

#### Scenario: An assertion fails

- **WHEN** the identity declares 2.4.0 and the option supplies 2.4.1
- **THEN** publish refuses, printing both values and the command that sets a version

#### Scenario: An open version with no option is refused

- **WHEN** the identity version is open and no option is supplied
- **THEN** publish refuses and offers both ways to supply it

### Requirement: A published version is never replaced

Publish SHALL ask the registry which versions it holds and SHALL refuse when it already holds the resolved tag, naming the artifact, the version and a command that bumps it. No option or mode SHALL turn that refusal into success, and the lookup SHALL run in a dry run too.

#### Scenario: An already published tag is refused

- **WHEN** the registry already holds the resolved tag
- **THEN** publish refuses, naming the artifact, the version and the bump command

#### Scenario: A dry run asks the registry

- **WHEN** a dry run is made on an artifact whose tag is already held
- **THEN** the plan reads REFUSED and the command exits 2

### Requirement: The plan is the dry run

Every publish SHALL print the resolved plan before any push: kind, declared path, module configuration path, repository, major, tag and its source, the state of each identity field and the override outcome. The dry run SHALL stop after the plan with every gate evaluated, exit 0 on GO and 2 on REFUSED, and push nothing. A refusal-free plan whose registry check did not finish SHALL read INCOMPLETE, never GO.

#### Scenario: A dry run surfaces refusals

- **WHEN** a dry run is made on a defective artifact
- **THEN** the plan prints REFUSED with the accumulated refusals and the command exits 2

#### Scenario: A clean dry run pushes nothing

- **WHEN** a dry run is made on a clean artifact
- **THEN** the plan reads GO, the command exits 0 and nothing is pushed

#### Scenario: An unfinished registry check is not a GO

- **WHEN** every local gate passes and the registry cannot be reached for the lookup
- **THEN** the plan reads INCOMPLETE and nothing is pushed

### Requirement: Publish refuses a module the kernel refuses

Module publish SHALL load the tree through the kernel's module loader, the loader that building a module and the operator use. When it refuses, publish SHALL refuse with the loader's own error, as the one refusal that cause yields. Publish SHALL NOT judge a module loadable by a test the kernel does not apply. A catalog is not loaded this way.

#### Scenario: A module the kernel refuses is refused by publish

- **WHEN** a module tree loads as CUE but the kernel's loader refuses it, because its version is a defaulted disjunction
- **THEN** publish and a dry run refuse with exit code 2, quoting the loader's error
- **AND** the module vet command reports the same refusal
- **AND** the same tree with the defect corrected passes the gate

#### Scenario: An unfilled identity is refused once

- **WHEN** the identity version is open and no version is supplied
- **THEN** the identity gate refuses and the kernel loader adds no second refusal

### Requirement: The compatibility gate compares against history

For every beta or GA member of a catalog, publish SHALL compare the member under the additive-only rule with the last published build of the same major that shipped a member of that name at that API version. It SHALL scan published versions below the one being published, newest first, release prereleases included and dev builds excluded. A member no earlier build carried SHALL pass. Transformers SHALL be exempt, and a member the comparison does not bind SHALL pass.

#### Scenario: A field removal is refused against the true predecessor

- **WHEN** a beta member removes a field relative to the newest published build that carried it
- **THEN** publish refuses with the violation path and the predecessor coordinate

#### Scenario: A prerelease predecessor counts

- **WHEN** the newest build carrying the member is a prerelease newer than the latest stable
- **THEN** the comparison runs against that prerelease

#### Scenario: Removal then re-adding is refused

- **WHEN** a member absent from the immediate predecessor is shipped incompatibly reshaped and an older build carried it
- **THEN** the scan finds the older build and publish refuses

#### Scenario: A new API version escapes the history

- **WHEN** a member ships at an API version no build has carried
- **THEN** it passes the gate

### Requirement: A compatibility refusal names its member and predecessor

A compatibility refusal SHALL open with a header that names the member, its API version and the coordinate it was compared against. Path-located violation lines SHALL follow. The action SHALL tell the author to make the change additive or to ship it alongside at a new API version. The member and posture gates of a catalog cover every level; only this gate skips a member the comparison does not bind.

#### Scenario: A violation names its path

- **WHEN** a member narrows a field of its earlier build
- **THEN** the refusal names the member, the compared coordinate and the path of the field

#### Scenario: An alpha member is exempt only here

- **WHEN** an alpha member narrows a field and also fails the member gate
- **THEN** the compatibility gate does not refuse it and the member gate does

### Requirement: Dev builds and prerelease lines are exempt, visibly

A dev build, a tag whose prerelease segment carries a dev identifier, SHALL NOT be judged by the gate and SHALL NOT serve as any build's predecessor. While the tag is a release prerelease (alpha, beta or rc), beta and GA members SHALL NOT be compared. The exemption SHALL end at the first stable tag of the major. The plan SHALL report each exemption on the compatibility row.

#### Scenario: A dev build is not judged

- **WHEN** the tag is a dev build and a beta member is incompatible with the newest release
- **THEN** publish does not refuse on compatibility and the compatibility row reads dev-exempt

#### Scenario: A dev build is never the baseline

- **WHEN** only a dev tag, newer than the latest release, carries an incompatible shape
- **THEN** a release publish compares against the release tag and passes

#### Scenario: A prerelease line is exempt, visibly

- **WHEN** the tag is an alpha prerelease and a beta member narrows a field of the previous alpha
- **THEN** publish does not refuse and the row counts the member as prerelease-exempt with nothing compared

#### Scenario: The first stable tag arms the gate

- **WHEN** the tag is the first stable one and a beta member narrows a field of the last alpha
- **THEN** publish refuses, naming the alpha as the compared build

### Requirement: Exit codes follow the cause

Publish SHALL exit 0 on success, 2 on any refusal, 3 when a registry operation fails for any reason but refused credentials, 4 when the registry refuses the credentials, and 1 on an unexpected failure. The registry operations are the core-schema fetch, the lookup and the push. When the lookup fails, the plan and every locally derived refusal SHALL still print before the registry error.

#### Scenario: Connectivity is not a refusal

- **WHEN** the registry cannot be reached for the lookup
- **THEN** the command exits 3 and the message names the registry operation that failed

#### Scenario: Local refusals survive a registry failure

- **WHEN** the artifact has a local defect and the registry is unreachable
- **THEN** the plan and the local refusal print, and the command exits 3

### Requirement: Registry failures are named by their cause

A failed registry operation SHALL be named by its cause and SHALL keep the operation and the registry's or transport's own error text. No response at all SHALL read "registry unreachable". A 401 or 403 answer that reaches the CLI as such SHALL exit 4, read as refused credentials, never read unreachable, and point to the login command, naming the host when known. Any other failure answer SHALL read "registry operation failed".

#### Scenario: A refused credential is not called unreachable

- **WHEN** the registry answers the lookup with 401, or the push with 401 or 403
- **THEN** the command exits 4 and the message says the credentials were refused
- **AND** it carries the registry's own error text and points to the login command with the host
- **AND** it does not say unreachable

#### Scenario: Another failure answer is not called unreachable

- **WHEN** the registry answers the lookup with 429 or 503
- **THEN** the command exits 3 and says "registry operation failed" with the registry's own error text

### Requirement: Some registry answers read as not found

A 403 answer to the lookup SHALL read as "this module is not published", so the lookup passes and the push is where a refusal shows. For a registry that hands out bearer tokens, a 401 from its token endpoint SHALL be refused credentials on the lookup, the core-schema fetch and the push, and a 403 from it SHALL be refused credentials on the push. On the lookup and the core-schema fetch a token endpoint 403 SHALL read as not found.

#### Scenario: A forbidden lookup reads as not published

- **WHEN** the registry answers the lookup with 403
- **THEN** the lookup reports no published version and no error

#### Scenario: A refusing token endpoint on the push

- **WHEN** the token endpoint answers 403 to the push
- **THEN** the command exits 4, carries "403 Forbidden" and points to the login command

#### Scenario: A refusing token endpoint on the core-schema fetch

- **WHEN** the token endpoint answers 403 to the core-schema fetch
- **THEN** the fetch reads "registry operation failed" and the command exits 3

### Requirement: An unconfigured registry is its own refusal

When the core-schema fetch fails and no registry is configured, publish SHALL exit 2 with a message that says no registry is configured, keeps the cause and says how to supply one. No registry is configured when no option, environment setting or config field sets one and CUE's own registry setting is absent.

#### Scenario: No registry is configured

- **WHEN** publish runs with no registry set anywhere and the core schema cannot be loaded
- **THEN** the command exits 2
- **AND** the message says no registry is configured and points to the config init command

### Requirement: A connectivity failure mid-walk is never a GO

A transport failure while publish lists or loads predecessors SHALL abort as a connectivity failure, and the plan SHALL NOT read GO, because the artifact was never fully judged. A package absent at a published version, whether the registry lacks the version or the version holds no CUE files for it, SHALL be a negative signal, never an error. A predecessor's dependency the registry lacks SHALL abort with exit 3.

#### Scenario: A mid-walk failure is not a GO

- **WHEN** the registry becomes unreachable after some members have compared clean
- **THEN** the command exits 3 and the plan reads INCOMPLETE

#### Scenario: A package absent at a published version

- **WHEN** a predecessor version is published but holds no CUE files for a member's package
- **THEN** the scan moves on to the next older version and reports no error

#### Scenario: A predecessor's dependency is not held

- **WHEN** a predecessor build is published but the registry does not hold one of its dependencies
- **THEN** the command exits 3 and the plan does not read GO
