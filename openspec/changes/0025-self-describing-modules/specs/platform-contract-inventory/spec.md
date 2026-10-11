## MODIFIED Requirements

### Requirement: Defined contracts name their defining catalog

The inventory SHALL hold every resource, trait and blueprint that exactly one enabled catalog lists, keyed by the contract's fully qualified name and carrying the member as that catalog lists it. It SHALL map each such contract to the registry key of its catalog, which is the catalog path with its major. A contract that more than one enabled catalog lists SHALL appear in neither the contracts nor the map, because it is a collision. The inventory SHALL also list the module traits that its enabled catalogs define and the module transformers that require them.

#### Scenario: Listed members of an enabled catalog are defined

- **WHEN** an enabled entry embeds a catalog that lists one resource, two traits and one blueprint
- **THEN** the inventory defines exactly those four contracts and maps each to that entry's registry key

#### Scenario: A defined contract keeps its own fulfilment

- **WHEN** an enabled catalog lists a trait that declares provider fulfilment
- **THEN** the defined contract carries that declaration as the catalog lists it

#### Scenario: A catalog with a module trait

- **WHEN** an enabled catalog defines a module trait and a transformer that requires it
- **THEN** the inventory lists both

#### Scenario: A trait nobody requires

- **WHEN** an enabled catalog defines a module trait that no enabled module transformer requires
- **THEN** the inventory lists the module trait and lists no transformer that requires it
