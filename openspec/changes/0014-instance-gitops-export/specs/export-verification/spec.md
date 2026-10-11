## Purpose

When an export is allowed to write: only when the published module still reproduces what runs, and with every refusal and override stated.

## ADDED Requirements

### Requirement: Export writes only a reproduced render

An export SHALL write nothing unless the published module at the live instance's coordinate, rendered against the live values, reproduces the recorded render digest. A mismatch SHALL abort and report that the cluster runs something the registry no longer describes.

#### Scenario: A moved tag

- **WHEN** the registry no longer returns the module that produced the deployed render
- **THEN** the export aborts, writes no file, and reports that the cluster runs something the registry no longer describes

### Requirement: A failed precondition aborts with nothing written

The cluster gates, the existence of the instance, a render that did not come from local bytes, a concrete module path and version, and a recorded render digest SHALL apply to export. Any failure SHALL abort with nothing written and SHALL name the reason.

#### Scenario: A local render

- **WHEN** the instance was last applied from local bytes
- **THEN** the export aborts with nothing written and names the local render as the reason

### Requirement: A forced export skips only the digest check

A forced export SHALL bypass the digest comparison only. The refusals for a local render and for an unresolvable module SHALL NOT be overridable.

#### Scenario: Force on a mismatch

- **WHEN** a user forces an export whose digests differ
- **THEN** the export writes the directory

#### Scenario: Force on a local render

- **WHEN** a user forces an export of an instance applied from local bytes
- **THEN** the export still refuses

### Requirement: The report states both digests and the outcome

The export report SHALL state the deployed digest, the rendered digest, and whether they matched or the comparison was forced.

#### Scenario: A matched export

- **WHEN** an export passes the digest check
- **THEN** the report shows both digests and states that they matched
