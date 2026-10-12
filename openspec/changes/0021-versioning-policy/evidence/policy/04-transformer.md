# Class 4: transformer

**Carrier:** none of its own; a transformer is keyed by the catalog build (`#ImplFQNType`, 0010 D44 above), so every transformer key moves on every catalog release. **Surface:** the resources and traits it declares as required and optional, and the shape of what it renders for them. **Bump:** the catalog build's; a transformer that stops rendering something it did, or newly requires a contract, is a breaking change *to the build*. **Pre-stable:** the build's. **Enforcement:** none today; no gate compares a transformer between builds. This entry states the surface so a build-level comparison has something to compare; whether one is built is implementation.

## Serving more than one level of a contract (D6)

A transformer binds to exact contract keys, and a key embeds the level (`…/resources/container@v1beta1`). A transformer that serves two levels of one resource or trait is therefore **two registrations, one body**: one transformer per level, each naming that level's key in its required or optional maps, all sharing the same transform definition. Matching is untouched; each registration matches exactly the components demanding its key. Under promotion by aliasing (0020 D4) the two levels are one definition and the shared body needs nothing else.

**Backup rule, when the levels differ in shape.** The shared body reads a canonical shape; each per-level registration carries the projection from its level into that shape, as a struct authored beside the registration. A level with no projection is a level the transformer does not serve, and the catalog states which levels each transformer serves.

Not done, and why: no any-of form in the required maps (a core schema and kernel change against 0010 D34's exact-key rule), and no matcher-side fallback (rejected by 0020 D4).

