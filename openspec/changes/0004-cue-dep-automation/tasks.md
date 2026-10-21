<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Shared updater and workflow

- [ ] 1.1 daggerverse: publish the updater module that walks a directory, bumps each dependency inside its pinned major, tidies the module and returns the tree with an old-to-new summary, with its own version tags
- [ ] 1.2 .github: publish the reusable workflow that calls the module and opens or refreshes one grouped pull request on a fixed branch

## 2. Local sweep

- [ ] 2.1 workspace: rewire the workspace update task, its module and template passes included, to call the same updater with an unchanged interface

## 3. Enrolment

- [ ] 3.1 catalog_opm: add the daily caller workflow and prove discovery, tidy and registry auth end to end as the pilot
- [ ] 3.2 core: add the daily caller workflow
- [ ] 3.3 library: add the daily caller workflow, fixture modules included
- [ ] 3.4 cli: add the daily caller workflow, module templates included
- [ ] 3.5 opm-controller: add the daily caller workflow
- [ ] 3.6 modules: add the daily caller workflow
