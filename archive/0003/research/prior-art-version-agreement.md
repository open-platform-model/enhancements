# Prior art — how other ecosystems bind a declared version to a published artifact

Gathered 2026-07-26. Scope: the specific problem this enhancement calls **version agreement** — a version declared inside a package's source and the version of the artifact carrying it being the same value — and the adjacent questions of tag immutability (OQ12), dev/placeholder versions (OQ13), and release automation (OQ14).

Method: targeted web search against primary documentation where available (Cargo Book, npm Docs, Go module reference, Harbor/AWS docs, release-please docs). This is a **snapshot**, not a maintained survey. Claims below are attributed; where something is recalled rather than verified in this pass it is marked as such.

## Summary — three families, and which one OPM is in

Every ecosystem surveyed lands in one of three families:

1. **Manifest-authoritative.** The version is declared in source; publish reads it; VCS tags are downstream bookkeeping. *Cargo, npm, Maven, Helm.*
2. **VCS-authoritative.** The tag is the version; source declares nothing, and the build *generates* a version into the artifact. *setuptools-scm and the Python packaging ecosystem, Terraform registry.*
3. **Version-is-not-identity.** The full version is never in source *or* in the module's identity — only the **major**, encoded in the module path. *Go.*

OPM is in family 1 by construction, and the reason is worth stating precisely: **a CUE module's published artifact is source, not a build output.** That single fact eliminates family 2 for OPM, and it eliminates it on the same grounds D4 already gives, arrived at independently.

## Family 1 — manifest-authoritative

### Cargo (Rust)

`Cargo.toml` carries `version = "1.2.3"`. `cargo publish` reads it; there is no version argument to override it with. Two findings bear directly on decisions here:

- **Publish refuses on an unclean working tree.** Cargo will not publish when files in the working directory contain changes not yet committed to git, including `Cargo.toml` itself; `--allow-dirty` is the explicit override, and it is documented as a safety mechanism to be used cautiously ([Cargo Book](https://doc.rust-lang.org/stable/cargo/commands/cargo-publish.html), [Arch man page](https://man.archlinux.org/man/cargo-publish.1.en)). The design intent is that VCS is the source of truth for what gets published.
- The override carries a known hazard: publishing from a dirty tree can sweep in untracked or ignored files ([rust-lang/cargo#9398](https://github.com/rust-lang/cargo/issues/9398)).

**Bearing on D12.** D12 argues the commit belongs between deciding a version and pushing an artifact, but supplies no mechanism to enforce it — the sequence is conventional. Cargo's default refusal is exactly that mechanism, and it is directly adoptable: `opm module publish` refusing on a dirty tree makes D12's commit seam structural rather than advisory, and closes the residual hole where `version set` writes a version that is published but never committed.

### npm

`npm version <major|minor|patch|semver>` bumps the version, writes it back to `package.json` (plus lockfiles), and — in a git repo — **creates both a version commit and a `vX.Y.Z` tag**. `npm publish` is a separate command that reads the resulting `package.json` ([npm-version docs](https://docs.npmjs.com/cli/v11/commands/npm-version/)).

**Bearing on D12.** This is D12's split, shipped and load-bearing in the largest package ecosystem in existence, with the same division of labour: one command authors, another publishes. `opm module version set` is convergent prior art, not a novel design. npm goes one step further than D12 by making the commit *and the tag* part of the version command rather than leaving them to the caller — worth considering, though it couples the tool to a git workflow that OPM may not want to assume.

### Maven

`pom.xml` `<version>` is authoritative. The relevant finding here is about the **dev-version** problem rather than agreement:

- A version ending `-SNAPSHOT` is a distinct, first-class class of version. Snapshots are **mutable** by contract, deployed with a timestamp, and expected to be re-deployed under the same version. Releases are immutable ([Baeldung](https://www.baeldung.com/maven-snapshot-release-repository), [devopsschool](https://www.devopsschool.com/blog/release-vs-snapshot-repositories/)).
- Snapshots go to a **separate repository**, and **Maven Central does not accept them at all**. Repository managers can be configured to reject redeployment of release versions ([Baeldung](https://www.baeldung.com/maven-snapshot-release-repository)).

**Bearing on OQ13.** This is the mature form of what `0.0.0-dev` is groping toward, and it differs from OPM's sentinel in every way that matters. `-SNAPSHOT` is a *suffix on a real version* (`1.2.0-SNAPSHOT`), so it carries the release it is heading for. It is *explicitly authored*, never a default that appears when the author says nothing. Its mutability is *declared* rather than accidental. And the release registry **refuses to serve it**, which is the enforcement OPM's placeholder currently lacks entirely. SemVer prerelease syntax already gives OPM the namespace for free; what is missing is the non-defaulted authoring and the registry-side refusal.

### Helm

`Chart.yaml` carries `version`; `helm package` reads it, and chart-releaser builds the GitHub release from it. Same family, no additional finding. *(Recalled, not verified in this pass.)*

## Family 2 — VCS-authoritative

### setuptools-scm (Python)

Makes the git history the single source of truth: it calls `git describe` and derives the version from the latest tag, the distance from it, and the working-directory state. On install it **encodes the computed version into a generated `_version.py`**, and the documentation is explicit that this file **should not be kept in version control** ([setuptools_scm README](https://github.com/wesm/setuptools_scm), [OpenAstronomy packaging guide](https://packaging-guide.openastronomy.org/en/latest/advanced/versioning.html)).

**Bearing on D4 and experiment 01.** This is precisely the mechanism OPM's catalogs use today (`identity/version_override.cue`, generated at publish, absent from source) and precisely what D4 forbids. Python tolerates it because a wheel is a *build output* — bytes in the artifact that are not in source are normal there. A CUE module's artifact **is** its source, so the same move produces the divergence experiment 01 measured: local evaluation and published evaluation disagree about a value that feeds identity. The Python answer is unavailable to OPM by artifact kind, not by preference. This is external confirmation of D4 from a system that made the opposite choice for a defensible reason.

## Family 3 — version is not identity

### Go modules

`go.mod` has no version field at all. The version comes from the VCS tag. The only version component that appears in source is the **major**, encoded as a path suffix (`example.com/foo/v2`), and a module released at v2+ **must** carry the matching suffix — which the toolchain enforces, treating different majors as genuinely distinct modules ([Go Modules Reference](https://go.dev/ref/mod), [Go blog: v2 and Beyond](https://go.dev/blog/v2-go-modules)).

**Bearing on OPM, and this is the sharpest finding in the survey.** Go did not solve version agreement — it **dissolved** it, by removing one side of the disagreement. There is nothing in source for the tag to contradict.

OPM measured this option and found it structurally dead: experiment 02 variant `d` shows that omitting the version fails at `#Catalog.metadata.fqn: reference "version" not found`, because the derived identity interpolates it. But the survey reframes *why*. Go's module identity is **path + major**; the full version is a coordinate you resolve *by*, not a component of what the module *is*. OPM's identity is `fqn` → `module.uuid` → `instance.uuid` → the label on every rendered resource, and `fqn` interpolates the full version.

So: **OPM has a version-agreement problem because it put the full version inside identity.** Go does not have one because it did not. That is not an argument to change OPM's identity model — the change would be enormous and would touch D9, OQ9, and every deployed instance — but it should be recorded as the road not taken, because it is the only approach in the survey that removes the problem rather than policing it.

### Go's checksum database — a different answer to D6

Go does not verify that an artifact's self-declared metadata matches the coordinates it was fetched by. It verifies **content against a transparency log**: `sum.golang.org` is a Merkle-tree-backed append-only log, and the toolchain checks inclusion and consistency proofs before writing `go.sum` lines ([Go blog: Module Mirror and Checksum Database](https://go.dev/blog/module-mirror-launch), [goproxy SumDB integration](https://deepwiki.com/goproxy/goproxy/2.4-sumdb-integration)).

**Bearing on D6 and OQ12.** These are complementary, not competing. D6 asks *"does this artifact's self-description match how I asked for it?"* — cheap, local, catches the drift measured in `01-problem.md`. A checksum log asks *"is this byte-for-byte what everyone else received for this coordinate?"* — stronger against tampering and against a moved tag, but silent about internal metadata consistency. Notably, a transparency log would partially answer OQ12 even if the registry permits tag overwrites, because the overwrite becomes *detectable*. D6 remains the right first move; it is a fraction of the cost and addresses the failure OPM actually has.

## Tag immutability (OQ12)

A clean split emerged, and it is bad news for OPM's substrate:

- **Package registries treat release immutability as fundamental.** Maven Central rejects redeployment of releases; repository managers can be configured to reject it generally ([Baeldung](https://www.baeldung.com/maven-snapshot-release-repository)).
- **OCI registries treat it as opt-in configuration.** ECR repositories are **mutable by default**; immutability must be explicitly enabled, after which pushing an existing tag raises `ImageTagAlreadyExistsException` ([SentinelOne KB](https://cloud-kb.sentinelone.com/ecr-repository-tag-immutability)). AWS added *exceptions* to tag immutability in 2025, letting operators exempt specific tag filters ([AWS what's-new](https://aws.amazon.com/about-aws/whats-new/2025/07/amazon-ecr-exceptions-tag-immutability/)). Harbor implements it as project-level rules, guaranteeing a matched artifact cannot be deleted, re-pushed, re-tagged, or overwritten by replication ([Harbor docs](https://goharbor.io/docs/2.12.0/working-with-projects/working-with-images/create-tag-immutability-rules/)).
- Tag mutability is treated as a security problem in its own right, not merely an operational one — a TOCTOU vector where the artifact scanned is not the artifact run ([Sysdig](https://www.sysdig.com/blog/toctou-tag-mutability)).

**Bearing on OQ12.** CUE modules are published to OCI registries, so OPM inherits the *weaker* default: tags are overwritable unless somebody configures otherwise. D3 says the tag and the declared version are the same value, which is only meaningful if a tag names one artifact forever. The remedy is well-precedented and two-sided — registry-side immutability configuration (a deployment requirement OPM must state, not merely hope for) plus client-side refusal to overwrite an existing tag in `opm module publish`. OQ12 should also decide what OPM's equivalent of "yank" is, since Maven's answer (immutable forever, no deletion) and npm/crates' answer (restricted unpublish windows) differ, and deleting an artifact breaks reproducibility for anyone who already resolved it.

## Release automation (OQ14) — and a tension with D12

release-please can update the version in **arbitrary files** via its generic updater: files listed under `extra-files` are scanned for annotations, and a line carrying `x-release-please-version` (usually in a comment) has its version replaced; block forms (`x-release-please-start-version` … `x-release-please-end`) also exist ([release-please customizing docs](https://github.com/googleapis/release-please/blob/main/docs/customizing.md)).

This is mechanically sufficient for OPM: `version: "2.0.0" // x-release-please-version` in a module's `.cue` file would be updated by release-please directly.

**But it contradicts D12's central claim.** D12 states `opm module version set` is *the only writer* of `metadata.version`. An annotation-driven updater makes release-please a **second writer**, with its own idea of where the version lives and no knowledge of the coupled `cue.mod` `@vN` edit that `version set` owns on a major bump. Two resolutions, and OQ14 should pick one deliberately rather than discovering it later:

- **Automation calls `version set`.** D12's claim survives intact; release-please contributes the *decision* (from conventional commits) but not the *write*. Costs a custom step in the release workflow.
- **Adopt the annotation and narrow D12** to "sole writer among OPM commands." Cheaper to wire up, but reintroduces a second mechanism that must independently get the major-suffix coupling right — which is the exact shape of drift this enhancement exists to remove.

The first is more consistent with everything else decided here.

## What transfers, and what does not

| Question | Prior art says | Transfers to OPM? |
| --- | --- | --- |
| Where does the version live? | Split ecosystems; both families work | Manifest (family 1) — forced, because the artifact is source |
| Author and publish in one command? | No — npm and Cargo both split them | Yes, D12 is convergent |
| Enforce the commit seam? | Cargo refuses on a dirty tree by default | **Yes — directly adoptable, currently missing** |
| Generate the version into the artifact? | Normal in Python | **No** — artifact is source; produces experiment 01's divergence |
| Placeholder dev version? | Maven `-SNAPSHOT`: authored, suffixed, separate repo, refused by Central | Shape transfers; OPM's defaulted sentinel is the weak form |
| Tag immutability? | Package registries: fundamental. OCI: opt-in | OPM inherits the OCI default — a gap, not a given |
| Verify the artifact at acquire? | Go verifies *content* via transparency log, not metadata | Complementary; D6 is the cheaper first move |
| Version inside identity? | Go deliberately keeps it out | Road not taken; explains *why* OPM has this problem |

## Caveats

- Search-derived. Claims are attributed to the pages that surfaced them; primary specs were not read end to end for every ecosystem.
- **Not verified in this pass:** crates.io and npm republish/unpublish policy specifics; Helm/chart-releaser behaviour; Terraform registry version sourcing; JSR and Deno publish-time VCS checks. All are recalled rather than cited, and any of them becoming load-bearing should be re-checked first.
- The ECR exceptions feature is dated July 2025 per the AWS announcement; registry capabilities in this area are actively changing and this table will age.

## Sources

- [cargo publish — The Cargo Book](https://doc.rust-lang.org/stable/cargo/commands/cargo-publish.html)
- [cargo-publish(1) — Arch manual pages](https://man.archlinux.org/man/cargo-publish.1.en)
- [rust-lang/cargo#9398 — sensitive information with `--allow-dirty`](https://github.com/rust-lang/cargo/issues/9398)
- [npm-version — npm Docs](https://docs.npmjs.com/cli/v11/commands/npm-version/)
- [Go Modules Reference](https://go.dev/ref/mod)
- [Go Modules: v2 and Beyond](https://go.dev/blog/v2-go-modules)
- [Module Mirror and Checksum Database Launched](https://go.dev/blog/module-mirror-launch)
- [SumDB Integration — goproxy](https://deepwiki.com/goproxy/goproxy/2.4-sumdb-integration)
- [setuptools_scm](https://github.com/wesm/setuptools_scm)
- [Specifying the Version of your Package — OpenAstronomy Packaging Guide](https://packaging-guide.openastronomy.org/en/latest/advanced/versioning.html)
- [Maven Snapshot Repository vs Release Repository — Baeldung](https://www.baeldung.com/maven-snapshot-release-repository)
- [Release vs. Snapshot Repositories — DevOpsSchool](https://www.devopsschool.com/blog/release-vs-snapshot-repositories/)
- [ECR Repository Tag Immutability](https://cloud-kb.sentinelone.com/ecr-repository-tag-immutability)
- [Amazon ECR now supports exceptions to tag immutability](https://aws.amazon.com/about-aws/whats-new/2025/07/amazon-ecr-exceptions-tag-immutability/)
- [Harbor — Tag Immutability Rules](https://goharbor.io/docs/2.12.0/working-with-projects/working-with-images/create-tag-immutability-rules/)
- [Attack of the mutant tags — Sysdig](https://www.sysdig.com/blog/toctou-tag-mutability)
- [release-please — customizing (extra-files, generic updater)](https://github.com/googleapis/release-please/blob/main/docs/customizing.md)
