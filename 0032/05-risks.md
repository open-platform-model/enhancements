# Risks, Drawbacks, Alternatives: The Operator Becomes the Controller

## Risks and Mitigations

- **A missed site keeps the former name.** A value, an address or a help string left behind contradicts the contract and confuses the next reader. **Mitigation:** a workspace-wide search for the former names after the last repo lands, with an explicit list of the residue that is history by intent, such as changelogs and archived OpenSpec changes.
- **A cluster runs the controller under its former names.** With no migration, such a cluster cannot upgrade in place. **Mitigation:** none in OPM; the owner moves any such cluster by hand, by reinstalling under the new names.
- **"Operator" is still used loosely.** The human role and upstream operators keep the word, so a careless edit can reintroduce the product sense. **Mitigation:** 0032:D1:R7 states the vocabulary rule, and review applies it.
- **The namespace name does not reserve it for the controller.** `opm-system` does not carry the controller's name, so nothing in the name stops another component from being installed there, and an object name there must then stay distinct per component. Whether anything else installs into it is not decided. **Mitigation:** the controller's objects carry the name prefix `opm-controller-`; whether that prefix stays is 0032:OQ1.

## Drawbacks

- Every repo in the workspace changes, and the controller, the CLI and the docs site release in one fixed order.
- Between this entry and the last renamed repo, the entries, the docs and the code name the component in two ways.
- Published artifacts under the former names stay in the registry until they are deleted, and nothing redirects from them.

## Alternatives

- **Keep the name and explain it.** **Why not:** every contract value would keep contradicting the explanation.
- **Rename only the prose.** **Why not:** the owner value, the status field and the command would keep the old word, which is where users meet it.
