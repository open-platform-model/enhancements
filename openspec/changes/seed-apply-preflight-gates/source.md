# Source note: seed-apply-preflight-gates

This is a seed. It records behaviour the CLI ships today so that later entries can modify it. It is not an enhancement and has no number.

Capability: `apply-preflight-gates`. Full seed (8 requirements). Written 2026-10-11 from `cli` at commit `09b0b812`. The text is rewritten at intent level: no Go symbol, file path or flag in a requirement. It names the published `opmodel.dev` kinds ModuleInstance and Platform, the CRD `moduleinstances.opmodel.dev`, and the Kubernetes kind SelfSubjectAccessReview. The owner ruled on 2026-10-11 11:20 that shipped behaviour is seeded. The supervisor ruled on 2026-10-11 13:00 that the MAJOR.MINOR compare and the install exemption stay out, because the converted 0021 states them (see "Left out").

## Sources

All read at the commit named. The repo spec is `cli` `openspec/specs/apply-preflight-gates/spec.md` (5 requirements; last changed in `b1eea500`). "Code only" marks a statement the spec does not make.

| Requirement here | Source requirement in the cli spec | Code read |
| --- | --- | --- |
| A missing ModuleInstance CRD stops the apply | "Missing-CRD gate with install hint" | `internal/inventory/gates.go:33-42` (not found, and the other read failure, which is code only); `internal/workflow/apply/apply.go:128-134` (exit code 2 for every cluster check at `:132`, code only; the requirement states it) |
| An outdated ModuleInstance CRD stops the apply | "CRD field-presence floor" | `gates.go:48-80` (field floor), `:164-192` (storage version, first served version as fallback, no version `:167-169`, no schema `:190-192`: code only; exit code 2 at `apply.go:132`, stated in the requirement) |
| The ceiling is skipped when it cannot compare | "Operator-version ceiling", the read and skip sentences | `gates.go:85-110`; the CLI's own version is tested first (`gates.go:86-89`): a development or non-SemVer CLI warns and never reads the Platform, so the solo-cluster and read-failure scenarios carry the released-SemVer condition; the failure to read the Platform for another reason is refused (`gates.go:100-101`, code only); an absent Platform or version prints nothing from this check (debug output only, `:95`, `:108`), the others warn; the render's own fallback warning when the cluster has no Platform (`internal/platform/resolve.go:257-258`) is not this check's output |
| Status access is checked before a CLI-run apply | "Status-RBAC pre-flight" | `gates.go:131-161`; `apply.go:171-175` (exit code 4 at `:174`, code only; the requirement states it); a failed review request fails the apply (`gates.go:144-147`, code only) |
| Operator-owned instances skip the status check | "Status-RBAC pre-flight", the words "In CLI-executor mode"; "Gate ordering and dry-run exemption" | `apply.go:162-168` (the operator-owned branch returns before the check); `internal/workflow/apply/thineditor.go:12-24` (what is skipped and what the caller enforced) |
| The checks run in a fixed order | "Gate ordering and dry-run exemption", the first sentence | `apply.go:128-177`; `RunClusterGates` (`apply.go:516-528`); test `TestRunClusterGates_ProbeOrder` (short circuit, code only for the "no later check runs" half) |
| A refused apply writes nothing | "Gate ordering and dry-run exemption", scenario "Gates precede all writes" | `apply.go:240` (the namespace is created after the last check); tests `TestExecute_RefusalCreatesNoNamespace` (the CRD and status cases) and `TestExecute_CreateNamespaceComesBeforeTheFirstApply` (the namespace halves are code and test only) |
| A dry run skips the cluster checks | same requirement, the dry-run sentences | `apply.go:128` and `:171` (the checks skip their reads); test `TestExecute_DryRunSkipsClusterGates` (it calls the workflow, `gates_test.go:81-104`, so the no-read claim is made of the four checks, not of the command: an instance or module apply still resolves its platform from the cluster Platform during the render when no platform option is given, `internal/cmd/instance/apply.go:125-138`, `internal/cmd/module/apply.go:182`, `internal/platform/resolve.go:241-244`) |

The spec has 5 requirements and the seed has 8. The status-RBAC requirement holds far more than 500 characters of rule, so it is split into the check and the operator-owned exemption. The ceiling requirement is cut to its skip rules (the comparison and the install exemption are out, see "Left out"). The ordering requirement is split into the order, the no-write rule and the dry run.

## Disagreements between spec and code

The code wins.

- The spec names `opm instance apply`. The code runs the same checks for `opm module apply` and `opm operator install` (all three call one apply workflow: `internal/cmd/instance/apply.go:151`, `internal/cmd/module/apply.go:195`, `internal/operator/install.go:71`). The seed says "an instance apply or a module apply" where it states the write rule.
- The spec says only that apply fails "non-zero". The code exits with 2 for the three cluster checks (`apply.go:132`) and 4 for the status check (`apply.go:174`). The seed states the codes in the requirements, not only in scenarios.
- The spec says the status check is made "in CLI-executor mode". The code also makes it only when the instance has an identity (`apply.go:171`). The seed does not state that condition: the spec does not, and no test or document in the repo says what it covers.
- The spec says the error for a denied status review names remedies. The code message also carries the reason the API server gave and the namespace (`gates.go:152-159`). The seed says the error names the remedies and says the inventory cannot be recorded; it does not fix the wording.

## Where this capability touches the other seeds and the live entries

- `platform-resolution` and `operator-lifecycle` (branches written in parallel): the install command's own version rule for the module it installs, the install-time status check on the operator namespace (`internal/operator/plan_install.go:179`), and the ordering of install's CRD writes are the lifecycle's. This seed states nothing about install, since the install exemption is 0021's.
- `instance-ownership` (branch written in parallel): ownership resolution and the thin-editor path belong to it. This seed states one consequence for the checks: the status check is not made for an operator-owned instance.
- 0021 `operator-version-ceiling` (live entry, converted): it states the MAJOR.MINOR compare, "Install is not refused by the running operator" and "Install refuses a module with a newer operator". They are out of this seed (see "Left out").
- `cli-kernel-render`: the render is not touched by these checks. (The skip switch for unprovided demands is repo behaviour that no archived entry backs and is in no seed; DECISIONS.md 2026-10-11 14:45.)

## Left out

- The ownership guard over every rendered object, its dry-run preview, and the empty-render guard: the repo spec's capability `apply-pruning`. The supervisor ruled on 2026-10-11 13:00 that the apply ownership guard goes to `seed-instance-ownership`. The ordering requirement points to them in one sentence ("The ownership checks, stated elsewhere") and restates none of their rules.
- The MAJOR.MINOR comparison of the operator-version ceiling (refuse when the operator's MAJOR.MINOR is above the CLI's, patch, prerelease and build metadata ignored, both full versions named in the error), and the exemption of the operator install's own instance apply from the ceiling (the CRD presence and field-floor checks still run for it): repo spec "Operator-version ceiling", `Source: 0021:D9:R3, 0021:D9:R4`. The converted 0021 states them in its capability `operator-version-ceiling` ("The ceiling compares MAJOR.MINOR only", "Install is not refused by the running operator"). Supervisor ruling 2026-10-11 13:00: out of every seed where an entry states them.
- The "Refusal with create-namespace changes nothing" scenario of `apply-pruning` (a refused guard check): the guard case goes with the guard. This seed states the same no-namespace result for the CRD and status refusals, which the test covers (kept here by supervisor ruling 2026-10-11 13:00).
- The wording of every error and hint, and the exact install command text: an intent-level seed names what the message says, not the string.
- The platform-fallback warning banner that the repo spec of an earlier change mentions (archive `test-coverage-and-fixture-hygiene`): not in the spec at `HEAD`, and not a gate.
- The history of the full-version ceiling that 0021 replaced: no spec states it at `HEAD`, and it belongs with the comparison rule that is left out above.
- Enhancement tokens (`0006:D24`, `0006:D27`, `0006:D23`, `0006:D33`, `0021:D9:R3`, `0021:D9:R4`) in the repo spec: provenance, not behaviour.

sampled: 2026-10-11 18705155
