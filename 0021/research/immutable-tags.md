# Research: platform facts behind D10 (release tags are immutable)

Gathered 2026-10-01. A snapshot, not canon: what GitHub, release-please and goreleaser documented or shipped on that day. Each item is marked **verified** (read in the cited source, or measured against this organization) or **inferred**. Recommendations are kept out; the decision they back is D10.

## GitHub rulesets

- **Organization rulesets work on the Team plan (verified).** GitHub's "Creating rulesets for repositories in your organization" says Team and Enterprise customers can create organization rulesets that control who can delete or rename a tag, and that only organization owners can edit them. A repository ruleset can only add to an organization rule, never relax it. The "About rulesets" page still calls organization rulesets Enterprise-only; it is stale, and the organization's live `mention-guard` ruleset proves Team works.
- **Bypass is per ruleset, not per rule (verified).** "About rulesets": bypass lets chosen actors "bypass the rules in the ruleset". The REST actor types are `Integration`, `OrganizationAdmin`, `RepositoryRole`, `Team`, `DeployKey` and `User`; the modes are `always`, `pull_request` (branch rulesets only) and `exempt`, which runs no rules for that actor and writes no bypass audit entry (changelog 2025-09-10). A drift check must therefore require an empty bypass list, not merely the absence of `always`.
- **Admins get no implicit bypass (verified).** A ruleset with an empty bypass list reports `current_user_can_bypass: "never"` for a repository-admin token in this organization; `mention-guard` reports `always` only because it lists `OrganizationAdmin`.
- **`GITHUB_TOKEN` is not a bypass actor type (inferred).** It does not appear in the actor list, so it cannot be granted bypass.
- **Tag patterns use path semantics (verified).** "Creating rulesets for a repository": patterns match with `File::FNM_PATHNAME`, so `*` does not match `/`; the recursive form is `qa/**/*`. The REST API accepts `~ALL` for every ref.
- **`non_fast_forward` alone does not stop a forward move (verified by reasoning over the rule definitions).** Re-pointing a tag to a descendant commit is a fast-forward; the `update` rule is what refuses it, and `deletion` covers removal.
- **Git ref events are not auditable on Team (verified).** The audit log records ruleset create, update and destroy, and immutable-release setting changes; git events need Enterprise Cloud and keep seven days. A tag move leaves no trace on this plan, so detection needs its own ledger.

## GitHub immutable releases

- **A published immutable release pins its tag (verified).** GitHub's "Immutable releases" concept page: the tag "cannot be changed, and cannot be deleted while the release exists"; after the release is deleted the tag may be deleted but the tag name cannot be reused, including after the repository is deleted and recreated. Title, notes and the prerelease and latest flags stay editable.
- **Assets are frozen at publication (verified).** "Managing releases in a repository": "you cannot add, replace, or delete assets after a release is published". The documented flow is draft, attach assets, publish.
- **Not retroactive, and not reversible (verified).** "Prevent release changes": immutability applies to future releases. GA changelog 2025-10-28: existing releases stay mutable unless republished, and disabling the setting leaves releases created while it was on immutable.
- **Organization policy exists (verified).** `PUT /orgs/{org}/settings/immutable-releases` takes `enforced_repositories` of `all`, `none` or `selected`.

## Release tooling

- **release-please can create the tag before a draft release (verified).** `force-tag-creation` shipped in release-please 17.2.0 (2026-01-20, PR 2627) and is documented in `docs/manifest-releaser.md`. At 17.3.0 it creates `refs/tags/<tag>` before creating the release. release-please-action 4.4.1 bundles 17.3.0 and 5.0.0 bundles 17.6.0.
- **The tag creation ignores an existing tag (verified in source).** The ref creation swallows the "already exists" error, and the release then attaches to that existing tag whatever commit it points at. A stale tag at the wrong commit is adopted silently, which is what D10 R8 guards against.
- **goreleaser publishes a draft it finds (verified).** goreleaser.com, release customization: `use_existing_draft` exists since 2.5, releases start as drafts while artifacts upload, and since 2.18 preflight aborts when the tag is already published as an immutable release.

## Registries

- **GHCR has no tag-immutability control (verified in documentation, not by a push).** "Working with the Container registry" names none, and OCI tags are mutable pointers. Enhancement 0011 D10 recorded the same gap on 2026-08-02.
- **Packages need a classic token (verified).** "About permissions for GitHub Packages" supports only a personal access token (classic), so a fine-grained token without administration rights cannot reach GHCR.

## Sources

- docs.github.com: "About rulesets", "Creating rulesets for a repository", "Creating rulesets for repositories in your organization", "Immutable releases", "Managing releases in a repository", "Prevent release changes", "Working with the Container registry", "About permissions for GitHub Packages", and the REST reference for rulesets and immutable-release settings.
- GitHub changelog: <https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/> and <https://github.blog/changelog/2025-09-10-github-ruleset-exemptions-and-repository-insights-updates/>.
- release-please: <https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md>, its CHANGELOG (17.2.0), and the release-please-action CHANGELOG.
- goreleaser: <https://goreleaser.com/customization/release/>.
