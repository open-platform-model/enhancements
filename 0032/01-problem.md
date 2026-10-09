# Problem Statement: The Operator Becomes the Controller

OPM's Kubernetes controller carries a name that promises something it is not. In the Kubernetes community an "operator" is a controller that encodes one application's day-two knowledge: how to back up, upgrade or fail over Postgres, Prometheus or cert-manager. OPM's controller encodes no application's knowledge. It is a generic delivery engine that renders any OPM module and reconciles the result, in the same family as Flux's controllers or Argo CD.

## Current State

The name reaches every contract a user meets. Entry 0006 fixed most of them, and entry 0021 restates the install artifact and the version ceiling:

- **The owner marker.** A ModuleInstance's owner field takes `cli` or a value naming the in-cluster actor, and handoff sets that value (0006:D3, 0006:D7, 0006:D18).
- **The version field.** The controller reports its running version on the cluster Platform's status, and the CLI's version ceiling reads it there (0006:D24).
- **The command group.** The CLI installs and uninstalls the controller under a command noun named after it (0006:D32, 0006:D34).
- **The install artifact.** The repository, the container image, the namespace, the workload names and the OPM module that deploys the controller all carry the name (0006:D35).

## Gap / Pain

The name sets the wrong expectation for every reader who already knows Kubernetes. A platform team reading "OPM operator" expects an application operator and looks for the application it operates. A reader of the docs meets the word "operator" in three unrelated senses: the product, the human platform operator, and the upstream application operators that OPM modules deploy, such as k8up or cert-manager.

The word also blurs the internal vocabulary. The controller runs one reconcile loop per resource kind, and "the operator reconciles" and "the operator's reconciler" read as the same thing. Nothing names the loops apart from the product.

## Concrete Example

A user installs OPM into a cluster that already runs the k8up backup operator and the CDI operator. The workloads list shows three "operators". Two of them operate one application each; OPM's runs every module the cluster holds. The ModuleInstance status names the in-cluster owner with the same word, and the docs page on conditions explains them as what "the operator" sets, where the reader cannot tell which of the three is meant.

## User Stories

- As a platform operator, I want OPM's in-cluster component to have a name that says what it does so that I can place it beside Flux and Argo CD without reading its docs. Today: the name puts it beside application operators.
- As a module author, I want the docs to say "controller" for OPM and "operator" only for the application operators my modules deploy. Today: the word means both.

## Why Existing Workarounds Fail

A glossary line explaining that OPM's operator is really a controller leaves every contract value, command and URL saying the opposite. Every new reader pays the explanation again. OPM has no external users before its first `v1.0.0` release, and the names become permanent at that release, so the rename costs least before it.
