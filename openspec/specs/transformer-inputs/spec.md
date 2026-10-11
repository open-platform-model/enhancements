# transformer-inputs Specification

## Purpose
What the runtime owes each declared input of a transformer's transform: the instance and the component arrive whole, the context's metadata blocks are projections of those two inputs, and the runtime fills the runtime name alone. The value a transformer reads is the value plain CUE unification gives it.

## Requirements

### Requirement: The instance context block is projected

At the transform site, the context's instance metadata block SHALL be computed from the instance input: name, namespace, FQN and UUID from the instance's metadata, and version from the instance's module metadata. A runtime SHALL NOT be required to supply the block.

#### Scenario: The block computes from the filled inputs

- **WHEN** a transform has its instance and component inputs filled concretely and the runtime name supplied
- **THEN** every field of the instance metadata block evaluates concretely, with nothing else supplied

#### Scenario: The version comes from the module

- **WHEN** the instance's module metadata carries a version
- **THEN** the block's version is that version

### Requirement: The component context block is projected

At the transform site, the context's component metadata block SHALL be computed from the component input. Its name SHALL be the component's own declared name, never the key the component sits under in the instance's components. A runtime SHALL NOT be required to supply the block.

#### Scenario: The name is the declared name

- **WHEN** a component sits under a key that differs from its declared name
- **THEN** the block's name is the declared name

#### Scenario: The block computes from the component alone

- **WHEN** the component input is filled concretely
- **THEN** the component metadata block evaluates concretely with nothing else supplied

### Requirement: Absent optional sources project as absent

An optional labels or annotations field that is absent on the instance or on the component SHALL be absent on its context block. It SHALL NOT become an error and SHALL NOT become an empty struct.

#### Scenario: An instance without annotations projects none

- **WHEN** the instance's metadata carries no annotations field
- **THEN** the instance block has no annotations, the annotation fold contributes nothing for it, and evaluation reports no error

#### Scenario: A component without labels projects none

- **WHEN** the component's metadata carries no labels field
- **THEN** the component block has no labels, and evaluation reports no error

### Requirement: The runtime owes the runtime name alone

The runtime name SHALL stay a required context field that the runtime supplies. It SHALL be the only context field a runtime must fill: every other field comes from the projection. The kernel SHALL build no context of its own.

#### Scenario: A missing runtime name fails

- **WHEN** a transform has both inputs filled and no runtime name supplied
- **THEN** concrete evaluation of the context fails on the missing runtime name

#### Scenario: Nothing else is filled by the runtime

- **WHEN** a runtime supplies the runtime name and no other context field
- **THEN** a transformer reading the instance block's namespace sees the instance's namespace

### Requirement: Agreeing fills pass and divergent fills conflict

A runtime that fills a projected context field with the value the projection computes SHALL get the same result as a runtime that fills nothing. A runtime that fills any other value SHALL get a unification conflict at that field, not a silent override.

#### Scenario: An identical fill agrees

- **WHEN** a runtime fills the instance block's name with the value the projection computes
- **THEN** evaluation succeeds with that value, as if nothing were filled

#### Scenario: A divergent fill conflicts

- **WHEN** a runtime fills the instance block's name with a value different from the instance's name
- **THEN** evaluation fails with a conflict at that field

### Requirement: A standalone context stays constructible

The context definition SHALL stay instantiable on its own from the two metadata blocks and the runtime name. The projection SHALL bind at the transform site only, and standalone uses SHALL keep validating.

#### Scenario: A directly built context validates

- **WHEN** a caller builds the context definition with explicit metadata blocks and a runtime name, outside any transform
- **THEN** the value validates and its folds compute from those blocks

### Requirement: The component input keeps every field class

The component input of a matched pair SHALL be the instance's component as evaluated in the same build as matching, with regular fields, definition fields, hidden fields and constraints intact. The render SHALL NOT export, finalize, rebuild or fill the component across a build boundary. Matching and execution SHALL read one components value.

#### Scenario: A transformer reads a computed name

- **WHEN** a transformer reads a name that core computes for the component as a definition field
- **THEN** the pair renders concretely, and the output carries the name core computed

### Requirement: The instance input is the whole instance

The instance input of a matched pair SHALL be the imported instance as evaluated: its metadata, values, module reference and every component, siblings of the bound component included. The render SHALL NOT narrow it to metadata or mask sibling components.

#### Scenario: A transformer reads instance metadata

- **WHEN** a transformer reads the instance's name and namespace from its instance input
- **THEN** the pair renders concretely and the output carries them

#### Scenario: A transformer reads its own component through the instance

- **WHEN** a transformer reads the component bound to its component input through the instance input
- **THEN** the pair renders with no cycle or structural error, and the value read equals the component input
