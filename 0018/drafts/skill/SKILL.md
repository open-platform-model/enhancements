---
name: docs-writing
description: Write or review a public OPM documentation page. Load before creating or editing any page destined for the OPM site, in any repository, and before reviewing a pull request that touches one.
---

# Writing OPM documentation

Draft. This skill carries the writing guide and the templates into an agent session, so agent-written pages follow the same rules as human-written ones.

## Steps

1. **Pick the type.** Ask two questions. Does the page help the reader act, or understand? Is the reader studying, or working? Act and study is a tutorial, act and work a how-to guide, understand and work reference, understand and study an explanation. A page that needs two types is two pages.
2. **Place it.** The page goes in the repository whose change would make it wrong, in the section that matches what the reader arrives holding.
3. **Start from the template** for its type. Keep the parts in order.
4. **Write to the guide.** Assume Kubernetes, never CUE or OPM. Make OPM the subject and place it against Kubernetes, saying where the comparison stops. Say what OPM does today, with no promises and no filler words.
5. **Run the checks** the repository runs in its pull requests, and fix every error.
6. **Walk the review checklist** for the type: every rule the writing guide marks as checked by review.

## When reviewing

Check the review rules for the page's type, and name the rule each comment enforces.
