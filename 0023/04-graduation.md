# Graduation Criteria: Artifact Provenance, Signatures and Platform Trust Policy

This document records the entry-specific gates that must hold before this design is frozen. Treat these as design acceptance criteria, not as implementation milestones; delivery is derived from this entry's `delivery.yaml` log.

## draft → accepted

Nine criteria carry this entry to `accepted`; OQ1 through OQ5 gate most of the rest.

- OQ1 and OQ2 resolved: the optional scopes (capability manifest, advisories) are either designed here with their own decisions or split into entries this one cites in `related`. The `single-question` gate is re-walked afterwards.
- OQ3 resolved: the trust-policy shape and its home (core `#Platform` vs platform package) are decided and `schemas/target.cue` carries no `// OQ` markers.
- OQ4 resolved: the SLSA level OPM's release workflows reach is stated per artifact family, with experiment 02 as evidence.
- OQ5 resolved: online versus offline verification, with the availability consequence written into `06-operational.md`.
- Experiments 01 (registry referrers behaviour), 02 (attest a CUE manifest end to end) and 03 (sign and verify, mirror carries the signature) are concluded; 04 (rebuild and compare) is concluded or explicitly deferred.
- `research/findings.md` cites every external claim the decisions rest on.
- `schemas/examples.cue` and `schemas/spec.md` exist and vet; `contracts/` vets.
- `config.yaml.semver` is set.
- Every decision carries a valid `**Kind:**`; no document prescribes mechanism; no `{Capitalised}` placeholders remain; `task vet:one ID=0023` and `task check ID=0023` pass.
