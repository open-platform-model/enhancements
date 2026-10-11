# Notes for the owner at accept

This note comes from the comparison of 0008 with the delivered seeds. The old entry did not hold it as an open question, so it is not in the proposal.

- **The singleton rule is stated twice (old 0008:D6:R3).** The requirement "The Platform CRD carries its singleton rule" of 0008 says the generated Platform CRD carries, unchanged, the rule that the only permitted name is `cluster`. The seed `platform-module-generation` has "The Platform is a cluster singleton", which states the same admission result: the only name is `cluster`, and any other name is rejected at admission. The 0008 requirement adds that the generated CRD carries the rule from core. The conversion keeps it as an ADDED requirement. The owner chooses at accept between a MODIFIED of the seed requirement and a cut of the 0008 requirement.
