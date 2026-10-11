## Purpose

Turn a published module into a standalone instance package that a user can commit and build at once. The command writes three files, pins every dependency, fills the starting values from the author's intended source, and leaves nothing behind when it fails.

## ADDED Requirements

### Requirement: Init writes a standalone instance package

`opm instance init` SHALL write a standalone CUE package for a published module, made of a module file, an instance file and a values file. The package evaluates to a `#ModuleInstance` with the chosen name and namespace and the deployed module set as its module. Every line derives from the acquired module. The package builds and vets at once, with no step in between, and loads from the module cache when the registry is unreachable.

#### Scenario: Package for a published module

- **WHEN** the user runs `opm instance init cert-manager opmodel.dev/modules/cert_manager -n cert-manager` and the newest release of the highest core-compatible major is `2.0.1`
- **THEN** the package holds a module file, an instance file and a values file
- **AND** the instance file imports core and the module at their majors, embeds `#ModuleInstance` with name `cert-manager` and namespace `cert-manager`, and sets the module to the imported cert_manager package

#### Scenario: Builds with no step in between

- **WHEN** init has written a package whose values satisfy the module's config
- **THEN** `opm instance build` and `opm instance vet` of its instance file both succeed with no other command in between, and the package still loads when the registry is unreachable

### Requirement: The package pins its dependencies and is tidy

The package's module file SHALL pin the deployed module at the exact resolved version, pin core at the version that module itself declares, and list the rest of the dependency closure. Its content SHALL be exactly what `opm module tidy` leaves, so a tidy check passes. The package's own module path SHALL default to the local placeholder `instance.local/<instance-name>@v0`, and a path the user gives SHALL replace it. That path is never looked up in a registry.

#### Scenario: Pins and placeholder path

- **WHEN** init writes a package for cert_manager `2.0.1` named `cert-manager`
- **THEN** the module file declares the module `instance.local/cert-manager@v0`, pins `opmodel.dev/modules/cert_manager@v2` at `v2.0.1`, pins `opmodel.dev/core@v2` at the version cert_manager `2.0.1` declares, and lists the rest of the closure

#### Scenario: The written package is tidy

- **WHEN** init has written a package
- **THEN** running `opm module tidy` in it changes no file

#### Scenario: The user names the package module

- **WHEN** the user gives the package module path `example.com/deploy/cert-manager@v0`
- **THEN** the module file declares that module path, and no registry request names it

### Requirement: Init takes its inputs from arguments or prompts

Init SHALL take an instance name, a module path and a namespace. With one positional argument, a value with a slash or a dot is the module path, and any other value is the instance name. A module path named both positionally and by option SHALL be refused with exit 2. When an input is missing, init SHALL prompt for it in that order on a terminal, and without a terminal SHALL refuse with exit 2 naming it. The target directory SHALL default to the instance name.

#### Scenario: Positional module path

- **WHEN** the user runs `opm instance init web opmodel.dev/modules/web_app -n demo`
- **THEN** the instance is named `web` in namespace `demo` and is written to `./web`

#### Scenario: Module path named twice

- **WHEN** the user gives the module path positionally and again by option
- **THEN** init exits 2 stating that the module path was named more than once

#### Scenario: Missing namespace without a terminal

- **WHEN** init runs with standard input not a terminal and no namespace
- **THEN** it exits 2 naming the namespace as the missing input, and writes nothing

#### Scenario: Missing module path on a terminal

- **WHEN** the user runs `opm instance init web -n demo` on a terminal and answers the prompt for the module path
- **THEN** init continues with the answer as if it had been given as an argument

### Requirement: Inputs are checked before any registry access

The instance name and the namespace SHALL each be a lowercase label of letters, digits and hyphens that starts and ends with a letter or digit and has at most 63 characters. Init SHALL check both, and every prompted value as it checks the argument it replaces, before any registry access. It SHALL refuse a bad one with exit 2. It SHALL also refuse with exit 2 a package module path that is not a valid module path.

#### Scenario: Invalid instance name

- **WHEN** the instance name is `Web_App`
- **THEN** init exits 2 before any registry access, naming the name rule

#### Scenario: Invalid prompted namespace

- **WHEN** the user answers the namespace prompt with `Demo NS`
- **THEN** init exits 2 before any registry access, naming the name rule

#### Scenario: Invalid package module path

- **WHEN** the user gives the package module path `not a path`
- **THEN** init exits 2 before any registry access, stating that it is not a module path

### Requirement: Values start from the author's intended source

Init SHALL fill the values file from the first applicable source. First, the module's `initValues`, rendered even when not concrete: a default shows as its default, an undefaulted choice stays a choice, an optional field is left out. Second, its `debugValues`, when the whole value is concrete once defaults apply. Otherwise an empty value. `debugValues` content SHALL NOT reach the package when `initValues` exists, and a partly concrete `debugValues` SHALL NOT be used in part.

#### Scenario: initValues takes precedence

- **WHEN** the module declares both `initValues` and `debugValues` with different content
- **THEN** the values file carries the `initValues` content only

#### Scenario: Non-concrete initValues

- **WHEN** `initValues` holds a defaulted field, an undefaulted choice and an optional field
- **THEN** the values file carries the default value, the choice as written, and no line for the optional field

#### Scenario: Concrete debugValues used

- **WHEN** the module declares no `initValues` and its `debugValues` is concrete
- **THEN** the values file carries the `debugValues` content

#### Scenario: Partly concrete debugValues

- **WHEN** the module declares no `initValues` and its `debugValues` is `{image: "nginx:1.27", replicas: int}`
- **THEN** the values file holds an empty value

#### Scenario: A value that is not a struct

- **WHEN** the chosen source is the concrete list `[1, 2]`
- **THEN** the values file carries the list as written

### Requirement: The values source is named and flagged

The values file SHALL open with a comment naming its source, and the report SHALL name the source. A source of `debugValues` SHALL carry a warning to review the file before deploying. An empty values file SHALL carry a warning that it is empty and name `opm instance vet` for the contract the user must now satisfy, whatever its source.

#### Scenario: debugValues flagged

- **WHEN** init fills the values file from `debugValues`
- **THEN** the values file opens with a comment naming `debugValues`
- **AND** the report names `debugValues` and warns to review the file before deploying

#### Scenario: No usable source

- **WHEN** the module declares no `initValues` and its `debugValues` is not concrete
- **THEN** all three files are written, the report names the source as empty, and it warns that the values file is empty and names `opm instance vet`

#### Scenario: Empty debugValues keeps its name

- **WHEN** the module declares no `initValues` and its `debugValues` is `{}`
- **THEN** the report names `debugValues`, warns to review it, and also warns that the file is empty

### Requirement: Init writes all or nothing

Init SHALL refuse with exit 2, before any registry access, when the target directory already exists or would sit inside an existing CUE module, and in the second case SHALL name the enclosing module root and suggest a target directory outside it. It SHALL write the package completely or not at all: after any failure nothing is left at the target path or beside it, so a retry into the same directory is never refused because of init's own leftovers.

#### Scenario: Existing directory refused

- **WHEN** `./web` already exists, empty or not
- **THEN** `opm instance init web opmodel.dev/modules/web_app -n demo` exits 2 naming `./web` and changes nothing

#### Scenario: Inside a CUE module refused

- **WHEN** the target directory would sit inside a module tree
- **THEN** init exits 2 naming the enclosing module root and suggests a target directory outside it

#### Scenario: Failure leaves nothing behind

- **WHEN** dependency resolution fails after the files were staged
- **THEN** no directory exists at the target path, nothing remains beside it, and rerunning the same command after the cause is fixed succeeds

### Requirement: Init reports its result without validating

On success init SHALL report the values source and any warning, the files written, and a closing line that names `opm instance vet` for the new instance file. It SHALL NOT evaluate the package against the module's config. A values file that violates the contract still initializes, and the violation surfaces at the user's first vet.

#### Scenario: Success report

- **WHEN** init succeeds from `debugValues`
- **THEN** the output names `debugValues` with a review warning, the three files, and ends with the `opm instance vet` line for the instance file, and the exit code is 0

#### Scenario: Values that violate the contract still initialize

- **WHEN** the module's `debugValues` does not satisfy its config
- **THEN** init writes the package and exits 0

### Requirement: Unreachable means the registry gave no response

Init SHALL exit 0 when it wrote the package, 2 when it refused, and 3 when the registry is unreachable: no response at all, such as a refused connection, a DNS or TLS failure or a timeout. Exit 3 also holds while init acquires the module, resolves the dependency closure and reads the module's own module file (every failure there); module resolution states the path. A registry answer that a dependency is not held SHALL exit 1 naming the failure, as does an unexpected internal failure.

#### Scenario: Registry unreachable while resolving dependencies

- **WHEN** the module was acquired and the registry cannot be reached while the dependency closure of the package is resolved
- **THEN** init exits 3 naming the registry, and nothing is left at the target path or beside it

#### Scenario: A dependency the registry does not hold

- **WHEN** the registry answers that a dependency of the package is not held
- **THEN** init exits 1, not 3, and nothing is left at the target path or beside it
