## Purpose

How a passed-through object is owned, recorded, applied and pruned. It joins the rendered objects of its instance and shares one lifecycle with them.

## ADDED Requirements

### Requirement: The kernel render holds no side object

The kernel's render of a module SHALL NOT contain a passed-through object. Side objects SHALL join the object set only in the apply path, after the render.

#### Scenario: Render beside a declared source

- **WHEN** an instance declares a side source and its module is rendered by the kernel
- **THEN** the render contains only objects the module produced

### Requirement: A side object carries the ownership labels

A passed-through object SHALL carry the same ownership labels as a rendered object of the same instance, including its identity.

#### Scenario: Labels on both kinds

- **WHEN** an instance applies one rendered object and one side object
- **THEN** both carry the same ownership labels and the same instance identity

### Requirement: A side object joins the one inventory

A passed-through object SHALL be recorded in the instance's inventory beside the rendered objects. There SHALL be no second inventory.

#### Scenario: One inventory lists both

- **WHEN** an instance with a side object is applied
- **THEN** the inventory lists the side object and the rendered objects together

### Requirement: Side objects are pruned like rendered ones

A passed-through object that leaves the declared set, or whose instance is deleted, SHALL be pruned exactly as a rendered object is.

#### Scenario: A source is removed

- **WHEN** a declared source is removed from an instance and it reconciles again
- **THEN** the objects of that source are pruned

#### Scenario: The instance is deleted

- **WHEN** an instance with a side object is deleted
- **THEN** the side object is deleted with the rendered ones

### Requirement: A side object carries a provenance marker

A passed-through object SHALL carry a marker that tells it from rendered output and names the kind of declared source that produced it.

#### Scenario: The marker names the source kind

- **WHEN** a side object comes from a Kustomize directory
- **THEN** its marker says it is a passthrough object from a Kustomize source

### Requirement: Side objects stage in the same order

Passed-through objects SHALL be staged in the same apply order as rendered objects, so a passed-through custom resource definition or namespace lands before the objects that depend on it.

#### Scenario: A side definition and its use

- **WHEN** a side source holds a custom resource definition and an object of that kind
- **THEN** the definition is applied before the object
