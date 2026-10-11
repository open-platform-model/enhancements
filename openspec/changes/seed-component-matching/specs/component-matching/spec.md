## Purpose

State what a component and the primitives attached to it declare so that a transformer can select on them. Matching labels are held apart from categorisation labels. A real disagreement between two primitives is then a unification conflict, and an unrelated difference is not.

## ADDED Requirements

### Requirement: Matching labels are a field of their own

A resource, a trait, a blueprint and a component SHALL each carry matching labels, apart from their descriptive labels. A transformer's required labels SHALL select on matching labels only. Descriptive labels SHALL NOT take part in matching, and SHALL NOT be combined upward from primitives into a component.

#### Scenario: A transformer selects on matching labels

- **WHEN** a transformer requires a label and the component's matching labels carry that pair
- **THEN** the component satisfies the transformer's label predicate

#### Scenario: A descriptive label is not matched on

- **WHEN** a transformer requires a label that only a descriptive label of the component or of an attached primitive carries
- **THEN** the component does not satisfy the label predicate

#### Scenario: Differing categories do not conflict

- **WHEN** a component attaches a resource, a trait and a blueprint whose descriptive category labels all differ
- **THEN** the component evaluates without conflict, and each primitive keeps its own category

### Requirement: A component's matching labels are its primitives' union

A component's matching labels SHALL be the unification of the matching labels of every attached resource, trait and blueprint. The union SHALL apply no filter, no key prefix rule and no key list. A primitive that declares none SHALL add none.

#### Scenario: Matching labels combine

- **WHEN** a component attaches one primitive declaring one pair and another declaring a different key
- **THEN** the component's matching labels hold both pairs

#### Scenario: A real disagreement is a conflict

- **WHEN** two attached primitives declare the same key with different values
- **THEN** evaluation fails with a conflict that names the key

#### Scenario: No declarations, no matching labels

- **WHEN** a component attaches only primitives that declare no matching labels
- **THEN** its matching labels are empty and evaluation succeeds

### Requirement: A required matching key survives the union

A primitive SHALL be able to declare a matching key as required, and that requirement SHALL survive into the component. A component whose attached primitives leave a required key unanswered SHALL be reported as missing that key, never as an incomplete value that evaluates silently.

#### Scenario: An unanswered required key is reported

- **WHEN** a resource declares a required workload-type key and the component attaches no primitive that answers it
- **THEN** evaluating the component reports the key as required but not present

#### Scenario: A blueprint answers the key

- **WHEN** a component attaches that resource and a blueprint declaring a concrete value for the key
- **THEN** the component's matching labels carry the blueprint's value

### Requirement: Core names no matching key

The core schema SHALL NOT name a matching label key and SHALL NOT export a constant for one. The catalog that defines a matching vocabulary SHALL own its keys, including the workload-type key.

#### Scenario: No matching-key constant is exported

- **WHEN** the core schema is evaluated
- **THEN** it exports no constant for the workload-type key

#### Scenario: A catalog adds a key without a core release

- **WHEN** a catalog declares, on one of its primitives, a matching key that core does not name, and a transformer requires that key with the value the primitive declares
- **THEN** a component that attaches the primitive satisfies the transformer's label predicate, with the core release already pinned

### Requirement: Matching labels are never rendered

Matching labels SHALL NOT reach the labels a transformer receives for the component, and SHALL NOT appear on any rendered object.

#### Scenario: A rendered object carries no matching key

- **WHEN** a component with non-empty matching labels is rendered
- **THEN** no rendered object carries those keys, and the component labels the transformer receives are unchanged by them

### Requirement: A component adds no matching labels

A component SHALL add no matching label beyond those of its attached primitives, and a label it adds SHALL be refused. This binds every component, the wrapper fragments a catalog ships and a module author's own alike. A required key SHALL be answered by an attached primitive or blueprint, never on the component.

#### Scenario: A fragment adds nothing

- **WHEN** a fragment attaches a set of primitives
- **THEN** the component's matching labels are exactly the union of theirs

#### Scenario: An invented key is refused

- **WHEN** a component declares a matching key that no attached primitive declares
- **THEN** evaluation fails, because matching labels are derived and not authored

#### Scenario: Answering a required key on the component is refused

- **WHEN** a component attaches a primitive that declares a required matching key, attaches no primitive that answers it, and sets that key on the component itself
- **THEN** evaluation fails
