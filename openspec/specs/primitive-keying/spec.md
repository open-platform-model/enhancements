# primitive-keying Specification

## Purpose
Define what a `#Resource`, a `#Trait`, a `#Blueprint` and a `#ComponentTransformer` declare as their key, and why the four do not share one. What a module demands is a contract, keyed by that primitive's own API version, which a catalog release does not move. What a platform executes is an implementation, keyed by the build it shipped in. The capability covers the two key types, the API version ladder, the build version as provenance, the authored key and the map keys.

## Requirements

### Requirement: A contract key and an implementation key differ

A contract key SHALL name what a module demands: path, name and the contract's own API version. An implementation key SHALL name what a platform executes: path, name and the full build version. `core` SHALL type them apart as `#ContractFQNType` and `#ImplFQNType`. The union `#FQNType` serves a consumer that holds both. No member field and no map key of the four kinds, a component or a catalog takes it, except the publish gate's key field, which checks both kinds.

#### Scenario: A contract key is accepted in the contract form

- **WHEN** a value is `opmodel.dev/catalogs/opm/traits/scaling@v1beta1`
- **THEN** it validates against the contract key type

#### Scenario: An implementation key is accepted in the build form

- **WHEN** a value is `opmodel.dev/catalogs/opm/transformers/configmap-transformer@1.2.0`
- **THEN** it validates against the implementation key type

#### Scenario: A build-shaped key is refused where a contract key is required

- **WHEN** a resource declares the key `opmodel.dev/catalogs/opm/resources/backup@1.1.0`
- **THEN** validation fails against the contract key type

#### Scenario: A contract-shaped key is refused where an implementation key is required

- **WHEN** a transformer declares the key `opmodel.dev/catalogs/opm/transformers/backup-transformer@v1`
- **THEN** validation fails against the implementation key type

### Requirement: The API version follows the Kubernetes ladder

An API version SHALL take exactly one of three forms: a major with an alpha level, a major with a beta level, or a bare major. A semantic version SHALL NOT be an API version. The module major type SHALL stay a separate, narrower type and SHALL keep typing module majors, which have no alpha or beta rung.

#### Scenario: The three ladder forms are accepted

- **WHEN** a value is `v1alpha1`, `v1beta2` or `v2`
- **THEN** each validates against `#APIVersionType`

#### Scenario: A semantic version is refused as an API version

- **WHEN** a value is `1.2.0` or `v1.2`
- **THEN** validation fails against `#APIVersionType`

#### Scenario: A module major has no beta rung

- **WHEN** a value is `v1beta1`
- **THEN** validation fails against the module major type

### Requirement: The additive-only promise is readable off the level

A contract SHALL state from its API version alone whether the additive-only promise binds it: not at an alpha level, and at a beta level and a bare major. `#APIVersionGated` SHALL read this off one string. It SHALL compare no two levels, so that no ordering of levels enters the schema.

#### Scenario: Alpha is not gated

- **WHEN** `#APIVersionGated` is given `v1alpha1`
- **THEN** it reports not gated

#### Scenario: Beta and a bare major are gated

- **WHEN** `#APIVersionGated` is given `v1beta1`, and separately `v1`
- **THEN** it reports gated in both cases

### Requirement: Primitives declare an API version; adapters do not

A resource, a trait and a blueprint SHALL each declare a required API version. A transformer SHALL NOT declare one, and its identity shape SHALL be closed, so that supplying one is refused and not silently ignored. Nothing would read it. A transformer's key comes from its build, the match keys on the contracts it demands, and the additive-only promise binds contracts.

#### Scenario: A primitive without an API version is incomplete

- **WHEN** a resource declares no API version
- **THEN** evaluation reports the required field as missing

#### Scenario: An API version on a transformer is refused

- **WHEN** a transformer declares the API version `v1`
- **THEN** validation fails with a field-not-allowed error and does not accept it silently

### Requirement: The catalog version records the build

Each of the four kinds SHALL declare the catalog build it shipped in as a semantic version, the catalog version, in place of the former version field. On a resource, trait or blueprint it SHALL be provenance only and SHALL NOT appear in the key. A transformer's key SHALL end in a full build version.

#### Scenario: A primitive records its build without keying on it

- **WHEN** a resource declares the API version `v1beta1`, the catalog version `1.2.0` and a key ending `@v1beta1`
- **THEN** the key validates and the catalog version reads `1.2.0`

#### Scenario: A transformer keys on its build

- **WHEN** a transformer declares the catalog version `1.2.0` and a key ending `@1.2.0`
- **THEN** the key validates against the implementation key type

#### Scenario: The former version field is gone

- **WHEN** a value of any of the four kinds declares the former version field in its metadata
- **THEN** validation fails with a field-not-allowed error

### Requirement: A member's key is authored, not derived

`core` SHALL NOT derive the key of a resource, trait, blueprint or transformer. The key SHALL be declared with its type and left for the catalog to author from its identity package. `core` SHALL NOT check that an authored key agrees with the member's own path, name and API version. A publish-time gate checks that agreement.

#### Scenario: An authored key is accepted as written

- **WHEN** a resource named `backup` declares the key `opmodel.dev/catalogs/opm/resources/backup@v1beta1`
- **THEN** the value validates, and nothing is derived from its path, name or API version

#### Scenario: A key that disagrees with the member's name is not refused by core

- **WHEN** a resource named `backup` declares the key `opmodel.dev/catalogs/opm/resources/restore@v1beta1`
- **THEN** the value validates against `core`, because the agreement is checked at publish

### Requirement: The four kinds share no identity shape

Each of the four kinds SHALL declare its own identity shape. None SHALL inherit it from a parent that another kind also inherits. A field that one kind gains SHALL NOT reach another by default, so that the exclusion is structural and not remembered.

#### Scenario: A field of the primitives is refused on a transformer

- **WHEN** a transformer declares a fulfilment, or matching labels, as a resource or a trait does
- **THEN** validation fails with a field-not-allowed error

### Requirement: A primitive's specification is keyed by its name

A resource, a trait and a blueprint SHALL each hold their specification under one field. That field SHALL be named the camel-case form of the kebab-case name. A transformer SHALL derive no such name projection, because it has no specification field.

#### Scenario: The specification key follows the name

- **WHEN** a resource is named `config-maps` and declares a specification under `configMaps`
- **THEN** the value validates

#### Scenario: Any other specification key is refused

- **WHEN** a resource is named `config-maps` and declares a specification under `configmaps`, or a second field beside `configMaps`
- **THEN** validation fails with a field-not-allowed error

### Requirement: A blueprint is classified as a primitive

A blueprint SHALL be classified as a primitive and not as a construct. A module attaches it and writes values under its specification, and a change to it breaks the module as a change to a resource does. A blueprint SHALL therefore declare an API version and carry a contract key.

#### Scenario: A blueprint carries a contract key

- **WHEN** a blueprint declares the API version `v1beta1` and a key ending `@v1beta1`
- **THEN** the key validates against the contract key type

#### Scenario: A blueprint refuses a build-shaped key

- **WHEN** a blueprint declares a key ending `@1.0.0`
- **THEN** validation fails against the contract key type

### Requirement: Map keys take the type of their role

A map whose keys name contracts SHALL take contract keys: the required and optional resource and trait demands of a transformer. A map whose keys name implementations SHALL take implementation keys: the transformer map and a catalog's transformer map. A key of the wrong form SHALL be refused. An unmatched key would show as a transformer that renders nothing, not as an error that names the key.

#### Scenario: A build-shaped key is refused in a demand map

- **WHEN** a transformer demands a resource under the key `opmodel.dev/catalogs/opm/resources/backup@1.2.0`
- **THEN** validation fails with a field-not-allowed error

#### Scenario: A contract-shaped key is refused in a transformer map

- **WHEN** a transformer map is keyed `opmodel.dev/catalogs/opm/transformers/backup-transformer@v1`
- **THEN** validation fails with a field-not-allowed error

#### Scenario: A contract-shaped key is refused in a catalog's transformer map

- **WHEN** a catalog lists a transformer under the key `opmodel.dev/catalogs/opm/transformers/z@v1`
- **THEN** validation fails with a field-not-allowed error

### Requirement: Demand and transformer keys are form-checked

In the demand maps of a transformer, the transformer map and a catalog's transformer map, `core` SHALL check only the form of a key. It SHALL NOT compare a key to the key of its value. That a demand key equals its value's key is an invariant of whichever runtime writes the map. Neither `core` nor the publish gate compares a transformer map key to the transformer's own key.

#### Scenario: A demand key that differs from its value's key is not refused

- **WHEN** a transformer demands a resource under one contract key and the resource declares another contract key
- **THEN** the value validates against `core`

#### Scenario: A transformer map key that differs from its transformer's key is not refused

- **WHEN** a transformer map holds a transformer under an implementation key that differs from the transformer's own key
- **THEN** the value validates against `core`

### Requirement: An attachment map key equals its member's key

The three attachment maps of a component SHALL bind every entry's key to the map key it sits under. An entry whose own key differs from its map key SHALL be refused with a conflict that names both. A short map key SHALL be refused. An entry that leaves its key unset SHALL take the map key. The binding derives nothing from the member's name, path or API version.

#### Scenario: A resource under its own key is accepted

- **WHEN** a component attaches a resource under the map key `opmodel.dev/catalogs/opm/resources/container@v1beta1`, equal to the resource's own key
- **THEN** the value validates and the resource is readable under that key

#### Scenario: A short key is refused

- **WHEN** a component attaches the same resource under the map key `container`
- **THEN** validation fails with a conflict on the resource's key that names `container` and the full key

#### Scenario: A trait under another trait's key is refused

- **WHEN** a component attaches a trait whose key ends `traits/expose@v1beta1` under the map key ending `traits/scaling@v1beta1`
- **THEN** validation fails with a conflict that names both keys

#### Scenario: A blueprint under another blueprint's key is refused

- **WHEN** a component attaches a blueprint whose key ends `blueprints/stateful-workload@v1beta1` under the map key ending `blueprints/stateless-workload@v1beta1`
- **THEN** validation fails with a conflict that names both keys

#### Scenario: An unset key takes its map key

- **WHEN** a component attaches a resource that leaves its key unset under a contract key
- **THEN** the value validates and the resource's key reads that map key
