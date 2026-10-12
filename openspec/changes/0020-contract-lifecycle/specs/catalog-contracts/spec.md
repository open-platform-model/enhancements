## MODIFIED Requirements

### Requirement: A catalog lists the contracts it defines

A `#Catalog` SHALL carry three member maps beside its transformers: one for resources, one for traits and one for blueprints. It SHALL also carry a fourth map, `#removed`, keyed by the versioned contract key (the name with its level), whose values are tombstones. Each member map SHALL accept any number of members, none required, so a catalog that lists nothing stays valid and every existing field keeps its meaning. A member listed under a map of the wrong kind SHALL be refused.

#### Scenario: A listed trait is readable from the catalog value

- **WHEN** a catalog lists a trait whose fulfilment is "provider" under its trait map
- **THEN** the trait is readable from the catalog by its key, and its fulfilment reads "provider" without any transformer being consulted

#### Scenario: A catalog listing no contracts stays valid

- **WHEN** a catalog declares only its metadata and transformers, as every catalog published before the maps did
- **THEN** the catalog validates, and each of the three maps is empty

#### Scenario: A resource under the trait map is refused

- **WHEN** a catalog lists a resource under its trait map
- **THEN** validation fails with a conflict between the kinds Resource and Trait

#### Scenario: A retired contract

- **WHEN** a catalog retires a contract
- **THEN** its tombstone is an entry of the catalog's removed map under the contract's versioned key
