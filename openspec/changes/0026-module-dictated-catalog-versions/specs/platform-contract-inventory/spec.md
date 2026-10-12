## MODIFIED Requirements

### Requirement: A platform derives its contract inventory

A `#ResolvedPlatform` SHALL derive a `#ContractInventory` from its enabled registry entries and the transformers their catalogs carry. The inventory is a pure derivation: no runtime step fills it. A disabled entry SHALL contribute nothing to it. A platform with no enabled entry SHALL derive an empty inventory in which the fulfilled, routable and discriminated verdicts all read true, and the definition SHALL evaluate with no registry at all.

#### Scenario: A disabled entry contributes nothing

- **WHEN** a platform declares an entry switched off whose catalog lists members and ships transformers
- **THEN** none of that catalog's contracts is defined and none of its transformers appears in any required-by list

#### Scenario: A platform with no entries is trivially sound

- **WHEN** a platform declares a name and a type and no registry entry
- **THEN** every map and list of the inventory is empty and all three verdicts read true

#### Scenario: The bare definition evaluates

- **WHEN** the platform definition is evaluated with no registry value at all
- **THEN** it evaluates and reads as the empty platform does
