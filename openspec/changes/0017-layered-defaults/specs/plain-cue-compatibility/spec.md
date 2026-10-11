## Purpose

The promise that OPM modules and catalogs stay plain CUE. Stock tooling keeps its meaning, and the kernel never forks the language in silence.

## ADDED Requirements

### Requirement: Plain vet passes every valid package

Plain `cue vet` SHALL pass on every valid module and catalog package, and no layering mechanism SHALL change that.

#### Scenario: A fresh template

- **WHEN** plain `cue vet` runs on a module built from the minimal template
- **THEN** it passes

### Requirement: The kernel never silently differs from plain CUE

Wherever the kernel's rendered value would differ from plain CUE's export, at least one side SHALL report an error. The kernel SHALL NOT silently produce a different value.

#### Scenario: A divergent module

- **WHEN** a module renders differently in the kernel than under plain CUE export
- **THEN** one of the two reports an error

### Requirement: Exactly two divergences exist

Exactly two divergences between the kernel and plain CUE SHALL exist, and the core specification SHALL document both. A config default meeting a blueprint default is reported as incomplete by plain CUE and resolved by the kernel. A config default vetoed by a downstream constraint is shipped silently by plain CUE and refused by the kernel.

#### Scenario: The collision

- **WHEN** a config default meets a blueprint default for one field
- **THEN** plain export reports an incomplete value and the kernel renders the config default

#### Scenario: The vetoed default

- **WHEN** a config default is vetoed by a downstream constraint
- **THEN** plain export ships the surviving value and the kernel fails the render
