# Open Questions — OPM Module Publishing Workflow

## Open Questions

Collapsed at supersession (2026-07-29). Each question's full framing, candidate list, and measured evidence is in git history; what a reader needs from a dead entry is which question was asked, whether this entry answered it, and which successor inherited it if not. Questions still marked `open` were never answered here.

- **OQ1: Does `opm publish` *enforce* or *generate* the canonical coordinates?** Status: open. Carried to 0011 OQ5.

- **OQ2: How is the import qualified when the package name is needed?** Status: resolved-by-D5.

- **OQ3: Does the library *derive* the reference from metadata or *record* the fetched reference at load?** Status: open. Not carried — no successor filed it.

- **OQ4: How do existing non-conforming in-repo modules migrate?** Status: open. Subsumed in scope by OQ9; carried to 0011 OQ6.

- **OQ5: How does the convention degrade for third-party modules not published via `opm publish`?** Status: resolved-by-D6.

- **OQ6: What does a version override flag on `opm module publish` mean under D4?** Status: resolved-by-D12.

- **OQ7: Does `#Catalog` get the same treatment, and who owns it?** Status: resolved-by-D7.

- **OQ8: Does a `cue.mod/local-module.cue` replacement chain survive more than one hop?** Status: informed-by-exp-04. Not carried. Bullets 1-2 answered in `experiments/04-local-module-chain-hops/` — the inner hop IS dropped, a hand-written chain-complete `local-module.cue` does resolve every hop, and `cue mod tidy` preserves it. Bullet 3 (whether catalog materialization honours `replaceWith` at all) was never run.

- **OQ9: How does the existing published fleet migrate to the owner-scoped namespace (D9)?** Status: open. Carried to 0011 OQ6.

- **OQ10: Should a primitive's `modulePath` be required to equal the `modulePath` of the catalog that ships it?** Status: open. Carried to 0010 OQ3.

- **OQ11: Does publishing to the central registry need an authentication story in this enhancement?** Status: open. Carried to 0011 OQ2.

- **OQ12: What are the republish and tag-immutability semantics of the central registry?** Status: open. Carried to 0011 OQ3. Prior art in `research/prior-art-version-agreement.md`.

- **OQ13: Where does a catalog's version come from under D4?** Status: resolved-by-D19. Evidence in `experiments/01-catalog-local-vs-published-parity/`, `experiments/02-catalog-version-declaration-variants/`, `experiments/03-identity-subpackage-necessity/`.

- **OQ14: What detects "this module changed" once the version lives in source?** Status: open. Carried to 0011 OQ4.

- **OQ15: What shape do `#Module.metadata.fqn` and the identity UUIDs take once the version is gone?** Status: resolved-by-D16.

- **OQ16: Do `#Resource`, `#Trait`, and `#Blueprint` follow D17 to major-keyed FQNs?** Status: resolved-by-D18.

- **OQ17: How does a `vMAJOR.0.0-dev` catalog interact with the D19 compatibility floor?** Status: resolved-by-D24. D24 supersedes D20.

- **OQ18: Is `#Module.metadata.modulePath` authored, or derived from `cue.mod/module.cue`?** Status: resolved-by-D23.

- **OQ19: Does generated identity target a subpackage or the artifact's own package, and can `core` supply the binding?** Status: resolved-by-D25.

- **OQ20: Does `#Catalog` gain a `name` field?** Status: open. Carried to 0010 OQ1.

- **OQ21: How does D24's dev version survive a committed `identity.cue`?** Status: open. Carried to 0010 OQ8.
