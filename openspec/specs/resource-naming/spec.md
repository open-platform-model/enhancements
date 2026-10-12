# resource-naming Specification

## Purpose
State how a component computes the name of the resource it renders and its DNS variants, and how a primitive declares the name rule of the Kubernetes kind it renders. A name that breaks the rule of a kind is refused when the module is authored, not when the API server applies it.

## Requirements

### Requirement: A resource name defaults to the instance-qualified name

A component SHALL take `<instance name>-<component name>` as its resource name unless its author sets one. An authored resource name SHALL win over the default.

#### Scenario: A default-named component

- **WHEN** component `web` of instance `shop` sets no resource name
- **THEN** its resource name is `shop-web`

#### Scenario: An authored name wins

- **WHEN** component `web` of instance `shop` sets the resource name `storefront`
- **THEN** its resource name is `storefront`, and the instance name appears nowhere in it

#### Scenario: An authored name equal to the default

- **WHEN** component `web` of instance `shop` sets the resource name `shop-web`
- **THEN** the component is valid and its resource name is `shop-web`

### Requirement: An authored resource name is a DNS subdomain

An authored resource name SHALL be a DNS subdomain: dot-separated labels of lowercase alphanumerics and hyphens, 1 to 253 runes. A refusal SHALL name the offending value and the rule in one message, and SHALL NOT show the default as a conflicting value.

#### Scenario: A dotted name is admitted

- **WHEN** a component sets the resource name `zfs.csi.openebs.io` and attaches no primitive that declares a name constraint
- **THEN** the component is valid, and the dots reach the DNS variants unchanged

#### Scenario: An invalid name is refused in one message

- **WHEN** a component sets the resource name `Bad_Name`
- **THEN** validation fails at the resource name with one message naming `Bad_Name` and the DNS-subdomain rule
- **AND** the message does not mention the instance-qualified default

#### Scenario: A name over 253 runes is refused

- **WHEN** a component sets a resource name of 254 runes
- **THEN** validation fails at the resource name with one message naming the value and the DNS-subdomain rule

### Requirement: DNS variants follow the resource name

A component SHALL expose three DNS variants computed from its resource name: the short form is the resource name, the local form adds the instance namespace, and the full form adds `svc` and the cluster domain. No variant SHALL carry a second copy of the instance name.

#### Scenario: A default-named service

- **WHEN** component `web` of instance `shop` in namespace `prod` sets no resource name, on the default cluster domain
- **THEN** the full form is `shop-web.prod.svc.cluster.local` and the local form is `shop-web.prod`

#### Scenario: An overridden name

- **WHEN** the same component sets the resource name `storefront`
- **THEN** the full form is `storefront.prod.svc.cluster.local`

### Requirement: A module context carries each component's names

A module context SHALL carry, for each component, the resource name and DNS variants that component computes. The context SHALL admit every resource name the component admits, dots and 253 runes included.

#### Scenario: A dotted name survives the context

- **WHEN** a component sets the resource name `metrics.internal.example` in namespace `media`
- **THEN** the module context holds that resource name and the full form `metrics.internal.example.media.svc.cluster.local`

### Requirement: The default cannot overflow the ceiling

The instance name and the component name are each at most 63 runes, so the default resource name is at most 127 runes. Core SHALL NOT carry a length guard on the default. A default of 64 runes or more SHALL be valid unless an attached primitive's name constraint narrows it.

#### Scenario: A 65-rune default is admitted

- **WHEN** an instance name of 4 runes and a component name of 60 runes meet, with no resource name set and no name constraint attached
- **THEN** the component is valid with the 65-rune default

#### Scenario: A 127-rune default is admitted

- **WHEN** an instance name and a component name of 63 runes each meet, with no resource name set and no name constraint attached
- **THEN** the component is valid with the 127-rune default

### Requirement: Three name types mirror the server's validators

Core SHALL provide `#NameType` (a DNS label, 1 to 63 runes), `#ObjectNameType` (a DNS subdomain, 1 to 253 runes) and `#ServiceNameType` (a DNS-1035 label, which is a `#NameType` whose first rune is a letter). Core SHALL NOT provide a length-only name type.

#### Scenario: The subdomain admits dots and 253 runes

- **WHEN** `zfs.csi.openebs.io`, or a 253-rune dotted string, meets `#ObjectNameType`
- **THEN** it is valid

#### Scenario: The subdomain refuses 254 runes

- **WHEN** a 254-rune value meets `#ObjectNameType`
- **THEN** validation fails, naming the value and the 253-rune bound

#### Scenario: The service name refuses a leading digit

- **WHEN** `1prod-web` meets `#ServiceNameType`
- **THEN** validation fails, naming the value and the DNS-1035 pattern
- **AND** the same value is valid as a `#NameType`

### Requirement: A primitive declares its name constraint

A resource, trait or blueprint SHALL carry a name constraint slot, `#nameConstraint`, whose default is top. A primitive MAY set it to a type, or compute it from its own fields. A primitive that declares nothing SHALL impose no constraint, and a consumer SHALL NOT test whether the slot is present.

#### Scenario: A constant constraint

- **WHEN** a trait declares `#ServiceNameType` as its name constraint
- **THEN** every component that attaches it is held to that type for its resource name

#### Scenario: A computed constraint

- **WHEN** a resource declares `#NameType` when its own workload-type matching key reads `stateful`, and top otherwise
- **THEN** a component answering `stateful` is held to `#NameType`, and one answering `stateless` to nothing

#### Scenario: An indifferent primitive costs nothing

- **WHEN** a component attaches only primitives that declare no constraint
- **THEN** every resource name `#ObjectNameType` admits is valid

### Requirement: A component's resolved name meets every attached constraint

A component SHALL collect the name constraint of every attached resource, trait and blueprint, and SHALL check its resolved resource name, default or authored, against all of them. Constraints SHALL combine by unification with no precedence rule. The check SHALL NOT change how the resource name itself defaults or is refused.

#### Scenario: A default admitted by a constraint

- **WHEN** component `web` of instance `shop` attaches a trait declaring `#ServiceNameType` and sets no resource name
- **THEN** the component is valid and its resource name is `shop-web`

#### Scenario: An authored name refused by a constraint

- **WHEN** the same component sets the resource name `web.internal`
- **THEN** validation fails naming `web.internal` and the DNS-1035 pattern

#### Scenario: A default refused by a constraint

- **WHEN** component `web` of instance `1prod` attaches a trait declaring `#ServiceNameType`
- **THEN** validation fails naming `1prod-web` and the DNS-1035 pattern, not an incomplete-value message

#### Scenario: Two constraints combine

- **WHEN** component `web` of instance `shop` attaches a trait declaring `#ServiceNameType` and a blueprint declaring `#NameType`
- **THEN** the resource name `shop-web` is valid, and the resource name `1shop-web`, which `#NameType` alone admits, fails naming the DNS-1035 pattern

#### Scenario: An authored name that meets the constraint

- **WHEN** a component with a `#ServiceNameType` constraint sets the resource name `istiod`
- **THEN** the component is valid and its resource name is `istiod`

### Requirement: A computed constraint binds on every path

A computed name constraint SHALL refuse the same names whichever primitive answers the key it reads. A primitive SHALL compute it from a value that is concrete on every path it can be attached through, because an unresolved constraint silently disables the length bound for the whole component.

#### Scenario: The length bound still refuses

- **WHEN** a component attaches a resource whose computed constraint reads `#NameType` and its default resource name is 65 runes
- **THEN** validation fails naming the 65-rune string and the 63-rune bound

#### Scenario: A blueprint answers the key

- **WHEN** a component's workload-type key is answered by the stateful blueprint, not by the container entry, and its resource name is 64 runes
- **THEN** validation fails on the 63-rune bound

### Requirement: The primitive that owns the reason declares it

A catalog SHALL declare a name constraint on the primitive whose rendered object puts the name in a DNS label position, and nowhere else. A Kubernetes Service name SHALL be a `#ServiceNameType`; a StatefulSet name and a Namespace name SHALL be a `#NameType`. A primitive that renders each object under its own name SHALL declare none.

#### Scenario: A Service name

- **WHEN** a component attaches the expose trait and sets the resource name `web.internal`
- **THEN** validation fails, because the Service name is a DNS-1035 label

#### Scenario: A stateful workload

- **WHEN** a component runs the container as `stateful` and sets a resource name with a dot
- **THEN** validation fails, because the StatefulSet name is a DNS label

#### Scenario: A namespace name

- **WHEN** a component declares a namespace named `team.a`
- **THEN** validation fails, because a Namespace name is a DNS label

#### Scenario: A raw object resource

- **WHEN** a component attaches only the objects resource
- **THEN** no name constraint applies, and each object keeps the name it declares

### Requirement: The Service name defaults to the short name

An exposed component SHALL carry one Service name, required and typed `#ServiceNameType`. The expose wrapper SHALL default it to the component's short DNS form. An authored Service name SHALL rename the Service only, not the workload or the DNS variants.

#### Scenario: The default

- **WHEN** component `web` of instance `shop` is exposed with no Service name
- **THEN** the Service is named `shop-web`, as are the workload and the short DNS form

#### Scenario: An authored Service name

- **WHEN** an exposed component sets the Service name `istiod`
- **THEN** the Service is named `istiod`, and the workload and the DNS variants keep the resource name

#### Scenario: The trait without the wrapper

- **WHEN** the expose trait is attached without the wrapper and no Service name is set
- **THEN** validation fails because the Service name is required, so a Service is never rendered unnamed

### Requirement: A primary object carries the resource name

A transformer SHALL name a component's primary object, the workload or resource the component exists to render, with the resource name, and SHALL NOT recompute it. Objects whose name is a contract outside the module, objects rendered several to a component, and references to another object keep their own rule.

#### Scenario: A workload

- **WHEN** component `web` of instance `shop` is rendered as a Deployment with no resource name set
- **THEN** the Deployment is named `shop-web`

#### Scenario: An authored resource name reaches the object

- **WHEN** the same component sets the resource name `storefront`
- **THEN** the Deployment is named `storefront`

#### Scenario: An exact-name kind

- **WHEN** a component renders a Namespace, a CustomResourceDefinition or a ServiceAccount
- **THEN** the object keeps the exact name its author wrote, not the resource name

### Requirement: A Service reference follows the Service name

A StatefulSet's governing service name and a route's backend reference SHALL be the Service name of an exposed component, never the workload's resource name. A route transformer SHALL require the expose trait, so a route never renders a dangling reference.

#### Scenario: A route to a renamed Service

- **WHEN** an exposed component sets the Service name `istiod` and the resource name `istiod-core`, and also attaches an HTTP route
- **THEN** the route's backend reference is `istiod`

#### Scenario: A route without a Service

- **WHEN** a component attaches an HTTP route and no expose trait
- **THEN** the route transformer does not match it, and no route with a dangling backend reference is rendered

#### Scenario: A governing service

- **WHEN** an exposed StatefulSet component sets the Service name `db-headless`
- **THEN** the StatefulSet's governing service name is `db-headless`
