<!-- The sections run in order: section 1 is done before section 2, and so on. The order is advice: no field, no check. -->

## 1. Shared pieces

- [ ] 1.1 cli: lift the verification render into a step that export and any later command share, and let the instance record carry the applier service account name

## 2. Export

- [ ] 2.1 cli: add the export command that reads the live instance, runs the gates, completes and reports the apply-bearing fields, and writes the per-instance directory, for one instance or for a namespace or cluster

## 3. Secrets

- [ ] 3.1 cli: encrypt the secret values of an exported instance with SOPS, once enhancement 0013 can name the secret paths

## 4. Proof

- [ ] 4.1 cli: add an end-to-end case that applies with the CLI, hands the instance to the controller, exports, applies the directory, and asserts that the inventory is unchanged
