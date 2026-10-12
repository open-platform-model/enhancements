## ADDED Requirements

### Requirement: The render list promotes the module's catalog pins

The render SHALL derive its module's dependency list by promotion. On a catalog path the module imports, it SHALL list the version its committed dependency list names, if admitted; on every other path, core included, the version in its tidied closure. It SHALL run no resolver, tidy or maximum-version selection and consult no registry. Both inputs SHALL enter the build from local directories. Each input's own path SHALL be listed with a placeholder version and marked the default major.

#### Scenario: The module wins a catalog path

- **WHEN** the platform admits a catalog and the module pins a version inside the range
- **THEN** the render lists the module's version, and the build evaluates the module's catalog

#### Scenario: Core follows the module's closure

- **WHEN** the module's tidied closure names core at one version
- **THEN** the render lists that version for core

#### Scenario: No lookup runs at render

- **WHEN** a render builds its dependency list
- **THEN** it runs no tidy and contacts no registry

#### Scenario: Instance-only paths survive

- **WHEN** the instance depends on a path the platform does not carry
- **THEN** the render lists the instance's entry for that path, and the instance's import resolves

#### Scenario: An input's unqualified self-import resolves

- **WHEN** the instance's root package imports one of its own subpackages without a major qualifier, and the instance enters the build from a directory
- **THEN** the render marks the instance's major as the default, and the build resolves the import from that directory

### Requirement: The single-provider guard counts per resolution

The render SHALL read the provider count of its resolution from the platform's contract inventory and compute none of its own. A provider-fulfilled contract required by transformers of two or more enabled entries serving the same major of the declaring catalog SHALL be an over-subscription row naming the key and the entries, and SHALL refuse the render. Providers serving different majors SHALL NOT count against each other. Catalog-fulfilled contracts SHALL admit any number of suppliers.

#### Scenario: A second provider is refused in the build

- **WHEN** two catalogs embedded in the platform each supply a transformer requiring a contract declared provider-fulfilled
- **THEN** the render fails with a typed over-subscription cause whose row names the key and both registry keys, and the diagnostics remain readable beside the refusal

#### Scenario: Providers of different majors are not counted together

- **WHEN** one provider serves the older major of the declaring catalog, another serves the newer, and the resolution holds the newer
- **THEN** the render does not count the older provider and proceeds

#### Scenario: Catalog-fulfilled plurality is allowed

- **WHEN** many transformers across catalogs require a contract with default catalog fulfilment
- **THEN** the render proceeds, and every candidate takes part in matching

#### Scenario: Providers count when the defining catalog is disabled

- **WHEN** the platform carries the defining catalog entry disabled, and enables two other entries whose transformers both require the gateway contract
- **THEN** the render fails with one over-subscription row naming the key and those two entries, and the inventory reads the same key as over-subscribed

#### Scenario: The inventory and the render agree on every served platform

- **WHEN** every served render platform is acquired, its inventory read, and its classified instance rendered against it
- **THEN** the inventory's over-subscribed keys equal the keys of the render's rows, every row's entries equal the inventory's providers for its key, and the routable verdict is true exactly when the render carries no over-subscription row

## REMOVED Requirements

### Requirement: The render's dependency list is derived by promotion

**Reason**: The platform no longer wins a shared catalog path. The module's committed pin is the version held.

**Migration**: Replaced by "The render list promotes the module's catalog pins"

### Requirement: The single-provider guard runs inside the build

**Reason**: The provider count is taken per resolution. Two majors of one catalog are no longer two providers of one contract across the whole platform.

**Migration**: Replaced by "The single-provider guard counts per resolution"
