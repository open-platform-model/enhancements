# Graduation Criteria — OPM Module Publishing Workflow

> **Stub.** This entry is superseded; its narrative documents were collapsed on 2026-07-29. It never graduated, so neither gate below was ever met. The full prior text is in git history.

## draft → accepted

Never reached. The gate turned on resolving the four questions this entry could not answer from inside itself — enforce-vs-generate for publish (OQ1), derive-vs-record for the library (OQ3), where a catalog's version is authored (OQ13, later resolved by D19), and what replaces content-checksum change detection once the version lives in source (OQ14). It also required an inventory of already-published modules whose declared version disagrees with their tag, since the acquire-time check would start refusing them.

Successor gates: [0010](../0010/04-graduation.md), [0011](../0011/04-graduation.md).

## accepted → implemented

Never reached. One requirement is worth restating because it outlived the entry: **the acquire-side refusal had to be proven against a real registry, not a hermetic fake.** A fake cannot establish the behaviour under test, for the same reason enhancement 0006's fake dynamic client could not catch its server-side-apply defect — publish a module whose `metadata.version` disagrees with its tag, and assert the fetch is refused.

A second one carried forward too: the CLI and the operator had to inherit that refusal *without their own implementations of it*, demonstrated by exercising each against the same bad artifact.
