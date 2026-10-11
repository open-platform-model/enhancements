## Purpose

Decide which version of each catalog a render holds, and refuse a render that the platform does not admit. The module's own committed pin picks the version; the platform bounds it. A refusal names the module, the path, the pin and the bound.

## ADDED Requirements

### Requirement: A module's catalog pin is the version held

On every catalog path a module imports, a render SHALL hold the version the module's committed dependency list names, provided the platform admits it. Two modules on one platform pinning different admitted releases of one catalog SHALL each render at their own pin, and a platform catalog change SHALL NOT move either.

#### Scenario: A module renders at its own pin

- **WHEN** the platform admits a catalog major from 4.0.0 with no ceiling, and a module pins 4.1.0
- **THEN** the render holds 4.1.0

#### Scenario: Two modules keep their own pins

- **WHEN** one module pins 4.1.0 and another pins 4.6.0 of the same admitted catalog
- **THEN** each render holds its own pin, and neither moves when the platform changes

### Requirement: A render records the catalog versions it held

Every render SHALL record the catalog version it held on each path, and that record SHALL be part of the render's identity.

#### Scenario: A render records each path

- **WHEN** a module is rendered against two catalog paths
- **THEN** the record names each path with the version the render held

#### Scenario: A changed pin changes the identity

- **WHEN** a module is re-rendered after its pin on a catalog moves
- **THEN** the recorded versions differ and the render's identity differs

### Requirement: An unadmitted catalog is refused

A render SHALL refuse a module that imports a catalog path with no enabled admission entry, as not admitted.

#### Scenario: No entry for the path

- **WHEN** a module imports a catalog major the platform has no entry for
- **THEN** the render is refused as not admitted

#### Scenario: A disabled entry admits nothing

- **WHEN** the platform keeps an entry for the path with admission disabled
- **THEN** the render is refused as not admitted

### Requirement: A pin outside the platform's range is refused

A render SHALL refuse a pin below its entry's floor or above its ceiling, naming the module, the path, the pin and the bound. The render SHALL NOT promote the pin to a version inside the range.

#### Scenario: A pin below the floor

- **WHEN** the floor is 4.2.0 and a module pins 4.1.0
- **THEN** the render is refused, naming the module, the path, 4.1.0 and the floor

#### Scenario: A pin above the ceiling

- **WHEN** the ceiling is 4.6.0 and a module pins 4.7.0
- **THEN** the render is refused, naming the module, the path, 4.7.0 and the ceiling

### Requirement: An open ceiling admits later releases

An entry with no ceiling SHALL admit every release of its path's major at or above the floor.

#### Scenario: A later release is admitted

- **WHEN** the floor is 4.0.0, there is no ceiling, and a module pins 4.9.0
- **THEN** the render holds 4.9.0

### Requirement: The resolved platform is generated, never authored

The render-time registry SHALL keep the shape it has today, under the name `#ResolvedPlatform`, and SHALL be generated, never authored. `#Platform` SHALL name the authored platform. A render given a platform SHALL take that authored platform and a module, and SHALL NOT take a resolved platform as input.

#### Scenario: The registry keeps its shape under a new name

- **WHEN** a consumer reads the render-time registry
- **THEN** it has the shape it had before, named `#ResolvedPlatform`

#### Scenario: A resolved platform is not an input

- **WHEN** a caller offers a resolved platform in place of an authored one
- **THEN** the render takes no resolved platform as its platform input

### Requirement: The resolved platform holds only the build's catalogs

The resolved platform for a render SHALL carry exactly one entry per catalog the build holds, at the version the build holds. An admitted lineage that no module imported and no registration supplied SHALL be absent.

#### Scenario: An admitted but unimported catalog is absent

- **WHEN** the platform admits a catalog that the module does not import and no registration supplies
- **THEN** the resolved platform has no entry for it

### Requirement: Identical resolutions share one generated package

Platform-package generation SHALL happen once per distinct resolution, keyed by the resolved catalog set, the authored platform's generation and the accepted registrations, so renders with the same resolution share one generated package.

#### Scenario: Same pins share

- **WHEN** two modules resolve to the same catalog versions under the same platform and registrations
- **THEN** they use one generated package

#### Scenario: Different pins do not

- **WHEN** a third module pins another admitted release
- **THEN** it gets its own generated package

### Requirement: A render without a platform holds its pins

A render given no platform SHALL hold every catalog it pins at the pinned version, and never two majors of one catalog. It SHALL carry no registrations, SHALL meet none of the admission refusals, and no authored or synthesized `#Platform` SHALL take part in it.

#### Scenario: A platform-less render holds its pins

- **WHEN** a module is rendered with no platform
- **THEN** it holds each catalog at its pin and no admission refusal applies

#### Scenario: A platform-less render has no registrations

- **WHEN** a module is rendered with no platform
- **THEN** the render carries no registrations

### Requirement: A provider catalog follows the same pin rule

A consumer module importing a provider catalog's path SHALL render at its own committed pin, checked against the effective window, under the same admission rules as a static catalog. A pin outside the effective window SHALL be refused, naming the module, the path, the pin and the bound.

#### Scenario: A pin inside the window is held

- **WHEN** a provider's effective window is 1.4.0 to 1.8.0 and a consumer pins 1.7.0
- **THEN** the render holds 1.7.0

#### Scenario: A pin above the window is refused

- **WHEN** the same consumer pins 1.9.0
- **THEN** the render is refused, naming the module, the path, 1.9.0 and the ceiling

### Requirement: A provider catalog defaults to the registration's version

When no consumer pins a provider catalog's path, the render SHALL hold the registration's version.

#### Scenario: No consumer pin

- **WHEN** a module needs the provider's transformer and pins no version of the provider catalog
- **THEN** the render holds the registration's version

### Requirement: A provider's requirements are checked against pins

For every catalog a build holds, its committed requirement on each shared OPM-namespace path SHALL be at most the version the build holds there within the same major, and a different major SHALL be refused. A render violating this SHALL be refused, naming the provider catalog, the consumer module, the path and both versions. A provider accepted at registration SHALL still be refused at render when a consumer's pins do not hold the versions it requires; acceptance SHALL NOT exempt a render.

#### Scenario: A requirement above the pin is refused

- **WHEN** a provider catalog requires 4.5.0 of a shared path and the consumer's pin is 4.3.0
- **THEN** the render is refused, naming the provider catalog, the module, the path and both versions

#### Scenario: Acceptance does not exempt a render

- **WHEN** a provider was accepted at registration and a render's pins do not hold the versions it requires
- **THEN** the render is refused

### Requirement: A resolution holds one major per catalog

Each resolved platform SHALL hold at most one major of any catalog. A render of a module pinned to one major SHALL hold that major and no other major of the same catalog.

#### Scenario: A module holds only its major

- **WHEN** the platform admits two majors of a catalog and a module pins the older one
- **THEN** the resolved platform holds the older major only

### Requirement: A provider joins only resolutions of its major

A resolution SHALL include a registered provider only when the provider was built against the major of its declaring catalog that the resolution holds. A provider built only against another major SHALL be absent from that resolution.

#### Scenario: A provider on another major is absent

- **WHEN** a provider was built against the older major and a module's resolution holds the newer major
- **THEN** the resolution does not include that provider

### Requirement: A module importing two majors is refused

A module whose own dependency list imports two majors of one catalog SHALL be refused at resolution, naming the module, the catalog path and both majors.

#### Scenario: Refused on a platform that admits both

- **WHEN** a module imports two majors of one catalog and the platform admits both
- **THEN** the module is refused, naming the module, the path and both majors
