# render-parity Specification

## Purpose
The differential contract between the kernel's render and pure-CUE unification of the same inputs: what a parity case names, when the two rendered values agree, how a known divergence is recorded and retired, and the rule that a divergence closes by removing kernel behaviour, never by weakening the comparison.

## Requirements

### Requirement: Pure-CUE unification is the render oracle

The harness SHALL render each parity case twice: once through the kernel's render, and once by plain CUE unification of the transformer's `#transform` with its declared inputs in a single build. The CUE result is the reference. In a case with no expected divergence, when both sides render and disagree, the harness SHALL report the kernel as the defective side, naming the case, the component and transformer pair, and the first differing path, or both object counts when the counts differ.

#### Scenario: Agreement on a shipped transformer

- **WHEN** a case pairs a fixture component with a published catalog transformer
- **THEN** the kernel's object for that pair and the oracle's output for the same pair compare equal, and the case passes

#### Scenario: Disagreement names the pair and the path

- **WHEN** a case with no expected divergence is rendered, both sides render the same number of objects for a pair, and the kernel's value differs from the oracle's at some path
- **THEN** the case fails, naming the case, the pair and the first differing path

### Requirement: A kernel refusal is a disagreement

A kernel render that fails SHALL count as a disagreement with the oracle. In a case with no expected divergence its report SHALL carry the kernel's refusal in place of a differing path.

#### Scenario: A kernel refusal is a disagreement

- **WHEN** the oracle renders a pair that the kernel's render refuses, in a case with no expected divergence
- **THEN** the case fails, and the failure carries the kernel's refusal and names no differing path

### Requirement: The oracle must render

Every case SHALL have an oracle that renders. An oracle that fails SHALL be reported as a broken fixture and never as a kernel divergence. This holds for a case that expects a divergence too.

#### Scenario: A failing oracle is a fixture failure

- **WHEN** the oracle fails to render a pair
- **THEN** the case fails, and the failure says the oracle must render and that a failing oracle is a broken fixture, not a kernel divergence

#### Scenario: An expected divergence does not hide a broken oracle

- **WHEN** a case that expects a divergence has an oracle that fails to render
- **THEN** the case fails as a broken fixture, and the failing kernel side is not taken as the expected divergence

### Requirement: Both renderers resolve identical inputs

Every row of the shipped case table SHALL name its instance, component and transformer by fixture. The instance SHALL enter the kernel side as a source-carrying artifact acquired from the on-disk package the oracle build imports, never rebuilt by extracting and re-filling values from a separately compiled parent. The two renderers SHALL share nothing but the fixture bytes. The harness carries no per-case input-construction override.

#### Scenario: The instance enters both sides by import

- **WHEN** a case is rendered
- **THEN** the kernel acquires the instance from the same package the oracle imports, and each renderer builds in its own CUE context

#### Scenario: The platform is a module of its own

- **WHEN** a case is rendered
- **THEN** the kernel side acquires the platform as a module of its own that imports the same published catalog build the oracle imports, and the oracle never imports that platform

#### Scenario: A case names fixtures only

- **WHEN** the shipped case table is read
- **THEN** every row names its instance, component and transformer by fixture, and no row carries a value that builds an input for one side only

### Requirement: Both sides resolve one catalog build

The shipped case table SHALL name each transformer by its catalog-relative name only, and the harness SHALL build every transformer id from the catalog version the oracle's own module pins. No case row, helper or assertion SHALL spell a catalog version as a literal. Ahead of the case comparisons, the harness SHALL check that the build the oracle reports and the build the kernel's render resolved both equal that pin. A mismatch SHALL NOT be reported as a kernel divergence.

#### Scenario: A catalog bump edits only module files

- **WHEN** the catalog pin moves to a newer published build in the oracle's module, in the platform module and in the other test modules that pin the catalog, and no other file changes
- **THEN** the shipped group resolves the new build on both sides, and every row is compared against the new build's transformer ids

#### Scenario: The oracle reports another build than the pin

- **WHEN** the catalog build the oracle reports differs from the oracle module's pin
- **THEN** the harness fails before it compares any case, naming the build the oracle reports and the pinned version

#### Scenario: The kernel resolves another build than the oracle

- **WHEN** the catalog build the kernel's render resolved differs from the build the oracle resolved
- **THEN** the harness fails ahead of the case comparisons, and the failure is a pin mismatch rather than a kernel divergence

### Requirement: The case table covers every matched pair

For each group, the harness SHALL compare the pairs of component and transformer the kernel's render reports with the pairs the oracle's predicate matching produces, and SHALL fail naming any pair only one side matched. The shipped case table SHALL hold a row for each pair the oracle matches and no row for any other pair, so a new pair cannot go untested.

#### Scenario: Pair sets agree on the fixtures

- **WHEN** the shipped fixtures are matched on both sides
- **THEN** the two pair sets are equal, and the table has one row for each pair

#### Scenario: A matched pair without a row fails

- **WHEN** the oracle matches a pair that has no row in the case table
- **THEN** the check fails, naming the pair

#### Scenario: A row that is not a matched pair fails

- **WHEN** the pinned catalog no longer ships a transformer that a row names
- **THEN** the check fails, naming the row that is not a pair the oracle matches

### Requirement: Equality is structural and order-sensitive

Each case SHALL compare the whole rendered value, and structural SHALL be the only admitted equality mode: a table entry that declares another mode, such as the retired output-fields-only mode, SHALL be refused. The comparison SHALL be order-sensitive, because CUE's natural evaluation order is the output contract. Objects SHALL be compared by position, and a different object count SHALL be a divergence. The harness MUST NOT sort, canonicalise or finalize either value.

#### Scenario: Reordered fields fail

- **WHEN** the kernel emits the same fields as the oracle for a pair but in another order
- **THEN** the case fails, naming the first path whose order differs and saying that the difference is ordering only

#### Scenario: Reordered list elements fail

- **WHEN** the kernel emits the same list elements as the oracle but in another order
- **THEN** the case fails, and the failure says the list element order differs

#### Scenario: A different object count fails

- **WHEN** the kernel renders a different number of objects for a pair than the oracle does
- **THEN** the case fails, stating both counts

#### Scenario: A retired mode is refused

- **WHEN** a table entry declares the retired output-fields-only mode
- **THEN** the harness refuses the entry, because structural is the only admitted mode

### Requirement: Known divergences are recorded and asserted to reproduce

A case MAY carry an expected divergence that names the kernel behaviour causing it. Such a case SHALL pass when the kernel side fails or differs from the oracle in any way, and the suite SHALL fail when it unexpectedly agrees, so that a change closing the divergence must also retire the entry. A case without an expected divergence SHALL be asserted to agree.

#### Scenario: An expected divergence reproduces

- **WHEN** a case that expects a divergence is rendered and the kernel side fails or differs from the oracle at any path
- **THEN** the case passes whatever the difference is, and the recorded divergence is logged

#### Scenario: An expected divergence stops reproducing

- **WHEN** a kernel change makes a case with an expected divergence agree with the oracle
- **THEN** the case fails, naming the entry to remove

#### Scenario: A case without an entry must agree

- **WHEN** a case with no expected divergence disagrees
- **THEN** the case fails as an unexpected divergence

### Requirement: A divergence closes by removing kernel behaviour

A failure of a case that expects no divergence SHALL call the kernel the defective side and SHALL say that the divergence closes by removing kernel behaviour, not by loosening the comparison. The comparison SHALL NOT tolerate a divergence it can classify.

#### Scenario: The failure states the direction of the fix

- **WHEN** a case with no expected divergence disagrees
- **THEN** the failure calls the kernel the defective side and says to close the divergence by removing kernel behaviour, not by loosening the comparison

#### Scenario: Classifying a divergence does not tolerate it

- **WHEN** the two values differ only in order and the failure message classifies the difference as ordering only
- **THEN** the case still fails

### Requirement: Probe transformers expose definition and instance inputs

The parity fixtures SHALL include one probe transformer that reads a component's `#names` and one that reads `#moduleInstance`, so whether the kernel supplies those inputs is visible in rendered output. Each probe case SHALL pin the value the oracle renders for the probed input and SHALL carry no expected divergence.

#### Scenario: The names probe under the oracle

- **WHEN** the names probe is unified with a component whose DNS name is computed
- **THEN** the oracle renders an object that carries that name concretely

#### Scenario: The instance probe agrees

- **WHEN** the instance probe is rendered through the kernel and through the oracle
- **THEN** both render an object that carries the instance's name concretely, and the case is reported as agreeing

### Requirement: The shipped catalog stays discriminated

The harness SHALL read the contract inventory of the platform fixture that imports the published catalog both renderers resolve, and SHALL assert that it reports no comparable transformer pair and reads discriminated. This check SHALL be a test of its own beside the render cases, so that a discrimination break and a render divergence never mask each other. Its failure SHALL name both transformers and the shared contracts.

#### Scenario: The published catalog is discriminated

- **WHEN** the check runs against the catalog build the platform fixture pins
- **THEN** the inventory lists no comparable pair and reads discriminated, and the render cases are unaffected by the read

#### Scenario: A comparable pair in a catalog release fails the check

- **WHEN** the pinned catalog build ships two transformers whose predicates are comparable over a contract the catalog itself fulfils
- **THEN** the check fails, naming both transformers and the shared contracts of the inventory row
