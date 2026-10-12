# catalog-contracts Specification

## Purpose
State what a catalog publishes about the contracts it defines. A catalog lists its contracts as members of three maps, keyed by contract key and stamped with provenance. "This catalog defines a contract" is then a stated fact, apart from "this catalog implements it". The two differ for a provider-fulfilled contract, which its declaring catalog ships no adapter for.

## Requirements

### Requirement: A catalog lists the contracts it defines

A `#Catalog` SHALL carry three member maps beside its transformers: one for resources, one for traits and one for blueprints. Each map SHALL accept any number of members, none required, so a catalog that lists nothing stays valid and every existing field keeps its meaning. A member listed under a map of the wrong kind SHALL be refused.

#### Scenario: A listed trait is readable from the catalog value

- **WHEN** a catalog lists a trait whose fulfilment is "provider" under its trait map
- **THEN** the trait is readable from the catalog by its key, and its fulfilment reads "provider" without any transformer being consulted

#### Scenario: A catalog listing no contracts stays valid

- **WHEN** a catalog declares only its metadata and transformers, as every catalog published before the maps did
- **THEN** the catalog validates, and each of the three maps is empty

#### Scenario: A resource under the trait map is refused

- **WHEN** a catalog lists a resource under its trait map
- **THEN** validation fails with a conflict between the kinds Resource and Trait

### Requirement: Contract members are keyed by contract key

Each member map SHALL be keyed by the contract key, the form `path/name@version` filed under the primitive's own api version. A key in the transformer form, which carries a build version, SHALL be refused as a field not allowed, not accepted as a member nothing demands.

#### Scenario: A contract key is accepted

- **WHEN** a catalog lists a trait under a key in the contract form
- **THEN** the catalog validates

#### Scenario: A transformer-form key is refused

- **WHEN** a catalog lists a trait under a key that ends in a build version such as 4.1.0
- **THEN** validation fails with a field-not-allowed error naming that key

### Requirement: A member's key equals its fully qualified name

Each contract map SHALL bind every member's fully qualified name to the key it is listed under. A member whose authored fully qualified name differs from its key SHALL fail with a conflict naming both. A member that authors no fully qualified name SHALL receive the key. The binding SHALL NOT derive that name from the member's other fields, such as its plain name.

#### Scenario: A member listed under its own fully qualified name is accepted

- **WHEN** a catalog lists a trait under the key equal to the trait's own fully qualified name
- **THEN** the catalog validates, and the member's fully qualified name reads that key

#### Scenario: A member listed under another contract's key is refused

- **WHEN** a catalog lists a trait under the key of a different contract
- **THEN** validation fails with a conflict on the member's fully qualified name, naming the key and the authored name

#### Scenario: A mis-keyed resource or blueprint is refused alike

- **WHEN** a catalog lists a resource or a blueprint at a well-formed key that is not its own fully qualified name
- **THEN** validation fails with a conflict naming the key and the fully qualified name

#### Scenario: A member that authors no fully qualified name receives its key

- **WHEN** a catalog lists a trait that leaves its fully qualified name unset
- **THEN** the member's fully qualified name reads the key it is listed under

### Requirement: The catalog stamps provenance on every member

Each map SHALL stamp every member with the catalog's own version as its build, and with a module path: the catalog's major-free registry path, then the map's kind segment, then the member's own api version. A member MAY omit either field and receive the stamp. A member that authors a different value SHALL fail with a conflict naming the member.

#### Scenario: A member without provenance receives both stamps

- **WHEN** a catalog of version 4.1.0 lists a trait of api version v1beta1 that authors neither field
- **THEN** the member's module path is the catalog's registry path followed by traits and v1beta1, and its build is 4.1.0

#### Scenario: A member filed under another api version is refused

- **WHEN** a catalog lists a trait of api version v1alpha1 whose authored module path ends in the segment v1beta1
- **THEN** validation fails with a conflict on the member's module path, naming both paths

#### Scenario: A member naming another build is refused

- **WHEN** a catalog of version 4.1.0 lists a trait that authors the build 3.9.0
- **THEN** validation fails with a conflict between 4.1.0 and 3.9.0 on the member's build

### Requirement: Publishing a contract requires no adapter

A contract SHALL be listable whether or not the same catalog, or any catalog, ships a transformer that requires it. A catalog that lists a provider-fulfilled contract and ships no transformers SHALL validate.

#### Scenario: A provider-fulfilled contract with no adapter is a valid member

- **WHEN** a catalog declares no transformers and lists one trait whose fulfilment is "provider"
- **THEN** the catalog validates, and the trait is readable from the trait map by its key

### Requirement: A catalog derives the provider-fulfilled contracts it implements

A `#Catalog` SHALL derive the list of provider-fulfilled contracts its own transformers require. The list is sorted, without duplicates, and read from each requirement's own fulfilment, not from the catalog's member maps. Optional demands, labels and catalog-fulfilled contracts SHALL NOT count. An authored list that disagrees SHALL fail. A catalog that authors none SHALL validate unchanged.

#### Scenario: Two adapters requiring one provider contract derive it once

- **WHEN** a catalog ships two transformers that both require the same provider-fulfilled trait, and its trait map does not list it
- **THEN** the derived list holds that contract once

#### Scenario: Resources and traits are sorted together

- **WHEN** a transformer requires a provider-fulfilled resource and a provider-fulfilled trait
- **THEN** the derived list holds both contract keys in ascending order, not in demand order

#### Scenario: Defining a provider contract is not providing it

- **WHEN** a catalog lists a provider-fulfilled trait and its only transformer requires catalog-fulfilled contracts
- **THEN** the derived list is empty

#### Scenario: An optional demand does not count

- **WHEN** a transformer names a provider-fulfilled contract only among its optional demands
- **THEN** the derived list is empty

#### Scenario: A catalog with no transformers provides nothing

- **WHEN** a catalog has no transformers
- **THEN** the derived list is empty

#### Scenario: An authored list that disagrees is refused

- **WHEN** a catalog whose transformers require a provider-fulfilled trait authors an empty list
- **THEN** validation fails on the list, because it is derived and never authored
