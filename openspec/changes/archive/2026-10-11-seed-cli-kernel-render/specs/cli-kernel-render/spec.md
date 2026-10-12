## Purpose

Describe what the CLI adds around the kernel render. Every command that renders sends the instance and the platform through the library's kernel, the render the operator also runs. The CLI names itself as the runtime and words the kernel's advisory facts and refusals for the user.

## ADDED Requirements

### Requirement: Every render goes through the library kernel

Every command that renders a module or an instance SHALL do so through the library's kernel, the same one the operator runs. The rendered objects and the refusals SHALL be the kernel's.

#### Scenario: Apply renders the kernel's objects

- **WHEN** an instance is built or applied
- **THEN** the rendered resource set is the set of compiled objects the kernel returned

#### Scenario: A refusal is the kernel's own

- **WHEN** the kernel refuses a render
- **THEN** the command shows the kernel's message and not a message of its own making

### Requirement: Values files and the registry reach every render

A further values file given to a render command SHALL take effect in the render, whether the input is an instance file or a module. The registry the configuration names SHALL serve every acquisition of a command: module, instance and platform alike.

#### Scenario: An instance file takes extra values

- **WHEN** an instance build runs on an instance file with a further values file
- **THEN** the rendered objects reflect the values in that file

#### Scenario: One registry setting serves every acquisition

- **WHEN** the configuration names a registry and a command acquires a module, an instance and a platform
- **THEN** each of them resolves its dependencies through that one registry

### Requirement: The CLI renders under its own runtime name

The CLI SHALL give the kernel the runtime name `opm-cli` for every render, so that the objects it renders carry the CLI as their managing runtime, the way objects the operator renders carry the operator's own name.

#### Scenario: The managed-by label names the CLI

- **WHEN** the CLI renders an instance
- **THEN** each rendered object carries the managed-by label with the value `opm-cli`

### Requirement: Advisory facts reach the user as warnings

The kernel reports advisory facts as structured rows, without message text. The CLI SHALL word each one as a warning and SHALL print every one, dropping none: an optional trait that no matched transformer handles, naming the component and the trait, and a module that requires a newer build of the OPM catalogs than the platform carries, naming the path and both versions. A warning SHALL NOT stop the render.

#### Scenario: Version skew warns and the render goes on

- **WHEN** a module requires a newer catalog build than the platform pins and the skew policy in force is to warn
- **THEN** the command prints a warning naming the path, the version the module requires and the version the platform carries, and the render completes

#### Scenario: An unhandled optional trait warns

- **WHEN** a render succeeds with a trait that no matched transformer handles and whose posture is optional
- **THEN** the command prints a warning naming the component and the trait

### Requirement: Kernel refusals exit as validation failures

When the kernel refuses a render, the command SHALL exit as a validation failure and SHALL print the kernel's message under a render-failed header, with the diagnostic rows beside it where the kernel carries any. This holds for unresolved demands, unmatched components, a failed transform, an over-subscribed provider contract, a skew refusal and a refused local replacement. No manifest SHALL be printed.

#### Scenario: Unresolved demands refuse with diagnostics

- **WHEN** a render fails with unresolved demands or unmatched components
- **THEN** the command exits as a validation failure with the kernel's message and prints the diagnostic rows beside it

#### Scenario: A failed transform and an over-subscribed contract exit the same way

- **WHEN** a transformer fails, or two enabled catalogs both provide one provider-fulfilled contract
- **THEN** the command exits as a validation failure, with the diagnostics printed beside the refusal

#### Scenario: A skew refusal exits as a validation failure

- **WHEN** the skew policy in force is to refuse and a module requires a newer catalog build than the platform pins
- **THEN** the command fails as a validation failure naming the path, the version the module requires and the version the platform carries

#### Scenario: A malformed replacement file is refused

- **WHEN** the replacement file does not parse, or a replacement directory declares a different module path than the replaced one
- **THEN** the command fails as a validation failure with the kernel's message naming the file or the two paths, and renders nothing

### Requirement: Honoured local replacements warn

Every render SHALL turn on the kernel's local replacements, for the module context and the platform module directory, under the precedence the render capability states. For each replacement honoured, the CLI SHALL warn, naming the replaced path, where its bytes were served from and which side supplied it, and saying the rendered bytes may match no published build. The warnings SHALL NOT stop the render or change its output. A context with no replacement SHALL produce none.

#### Scenario: A replaced dependency warns

- **WHEN** an instance render's module context replaces a dependency, which the platform does not name, with a local checkout
- **THEN** the rendered objects reflect the checkout's bytes and one warning names the path, the checkout and the module side, with the published-bytes caveat

#### Scenario: A platform's replacement of its catalog warns

- **WHEN** a render's platform module directory replaces its catalog with a local checkout
- **THEN** the rendered objects reflect the checkout's transformer bytes and one warning names the catalog path, the checkout and the platform as its source

#### Scenario: A module directory with no platform named is honoured

- **WHEN** a module build runs from a module directory whose replacement file replaces a catalog it pins, and no platform is named
- **THEN** the rendered objects reflect the checkout and one warning names the path, the checkout and the module side

#### Scenario: A clean context stays silent

- **WHEN** neither the module context nor the platform module carries a replacement
- **THEN** no replacement warning is printed

### Requirement: An ignored module replacement is reported

A module-context replacement of a path the platform names is not honoured, and SHALL be reported. The CLI SHALL warn that the replacement is ignored and that the redirect belongs in the platform module's own replacement file.

#### Scenario: A module-side redirect of a platform path is reported inert

- **WHEN** a render against a named platform runs from a module context that replaces a path the platform names
- **THEN** a warning names the path and says to redirect it in the platform module

### Requirement: An older-core platform gets a re-pin hint

When the kernel refuses a render because the platform pins a core release older than a field the kernel reads, every command that renders, and the platform check when it reads the inventory, SHALL fail as a validation failure printing the kernel's message. When the platform is a directory the user named, the command SHALL add a hint naming that directory and the exact command that re-pins core there to the release the CLI was verified against. The CLI SHALL NOT fall back to another platform.

#### Scenario: A named older-core directory is refused with the re-pin command

- **WHEN** an instance build runs against a platform directory that pins an older core than the kernel reads
- **THEN** the command fails as a validation failure, prints the kernel's message naming the platform, the missing field and the core release required, adds a hint naming the directory and the re-pin command, and prints no manifest

#### Scenario: A refused named directory gets no fallback

- **WHEN** an instance build against a platform directory the user named is refused because that directory pins an older core
- **THEN** the command does not render against the cluster Platform or a platform generated from the instance package's pins, and prints no manifest

#### Scenario: The platform check gets the hint too

- **WHEN** the platform check runs against a platform directory the user named whose core pin is older than the inventory read requires
- **THEN** it fails with the validation code, names the missing field and the first core release carrying it, adds a hint naming the directory and the re-pin command, and prints no partial report
