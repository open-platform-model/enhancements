## Purpose

The API-quality bar the kernel library meets before its GA freezes the exported API.

## ADDED Requirements

### Requirement: Render output is plain data

Before the kernel library reaches GA, no value its render operation returns to a caller SHALL be a live CUE value. Rendered output SHALL reach the caller as plain data. The acquired instance, platform and module packages and the configuration schema MAY still expose CUE values, under the library's rule that their holder bounds their lifetime.

#### Scenario: A caller holds a render result

- **WHEN** a caller keeps a render result after the library call returns
- **THEN** the result is plain data and needs no CUE runtime to read

### Requirement: Fetch and resolution failures are typed

Before the kernel library reaches GA, a caller SHALL be able to tell each fetch or resolution failure the library returns by type, without matching on message text. The type SHALL say whether the failure is transient and which kind of fetch or resolution failed.

#### Scenario: A transient registry failure

- **WHEN** a fetch fails because the registry is unreachable
- **THEN** the caller learns from the error's type, without reading its message, that a fetch failed and that the failure is transient

### Requirement: Specs and documents match the code

Before the kernel library reaches GA, its main specs SHALL pass strict validation, and every exported identifier and behaviour its README, decision records and specs name SHALL exist as described.

#### Scenario: A named identifier

- **WHEN** a document names an exported identifier
- **THEN** the identifier exists and behaves as described

### Requirement: Three quiet betas are a guideline

The kernel library SHALL reach GA only after three consecutive beta releases of its line, none of which carries a breaking change. This SHALL be a guideline and not a gate: the owner judges when the library's API has settled, and three releases may be too few for some APIs.

#### Scenario: Three quiet betas, API not settled

- **WHEN** the library has had three consecutive beta releases without a break and the owner judges the API not settled
- **THEN** the owner may hold GA, because the three betas are a guideline and not a gate
