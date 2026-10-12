## MODIFIED Requirements

### Requirement: A divergence closes by removing kernel behaviour

A failure of a case that expects no divergence SHALL call the kernel the defective side and SHALL say that the divergence closes by removing kernel behaviour, not by loosening the comparison. The comparison SHALL NOT tolerate a divergence it can classify. The two divergences that the core specification documents as accepted, a config default meeting a blueprint default and a config default vetoed by a downstream constraint, SHALL NOT be called kernel defects.

#### Scenario: The failure states the direction of the fix

- **WHEN** a case with no expected divergence disagrees
- **THEN** the failure calls the kernel the defective side and says to close the divergence by removing kernel behaviour, not by loosening the comparison

#### Scenario: Classifying a divergence does not tolerate it

- **WHEN** the two values differ only in order and the failure message classifies the difference as ordering only
- **THEN** the case still fails

#### Scenario: An accepted divergence is not a kernel defect

- **WHEN** a difference between the kernel and plain CUE is one of the two divergences that the core specification documents as accepted
- **THEN** no failure calls the kernel the defective side for it
