// The three name types D20 proposes, plus the copied current #NameType they
// split from.
//
// Copied (not referenced) per experiment rule 3:
//   #NameType — core/src/types.cue line 10, byte-identical.
// The other two are NEW — this file IS the proposal under review.
//
// The empirical matrix these encode was measured against a live k8s v1.33.0
// API server (server-side dry-run, 2026-08-24; lengths bisected same day):
//
//   kind          dots  max  rule            validator observed
//   ------------  ----  ---  --------------  ------------------------------
//   Deployment    yes   253  DNS-1123 subd.  accepted "a.b.c"; 253 ok
//   DaemonSet     yes   253  DNS-1123 subd.  accepted "a.b.c"
//   ConfigMap     yes   253  DNS-1123 subd.  253 ok, 254 "must be no more
//                                             than 253 characters"
//   StorageClass  yes   253  DNS-1123 subd.  accepted "a.b.c"
//   CSIDriver     yes   253  DNS-1123 subd.  accepted "zfs.csi.openebs.io"
//   Service       NO     63  DNS-1035 label  63 ok, 64 refused; "must ...
//                                             start with an alphabetic
//                                             character"
//   StatefulSet   NO     63  label rule      "must not contain dots" AND
//                                             64 → "must be no more than 63
//                                             characters" — BOTH axes
//   Namespace     NO     63  label rule      "must not contain dots"
//
// The rule is exactly: a name is dot-restricted iff it becomes a DNS label,
// and the dot-restricted kinds carry the 63-rune label budget too — so
// #NameType (the label rule) is the complete constraint for all three, both
// axes at once.
//
// ⚠ The adjacent trap that reads like a name limit but is not: LABEL VALUES
// cap at 63. `kubectl create deployment <253 chars>` fails on
// metadata.labels (it derives `app: <name>`), not on metadata.name — the
// same manifest with independent labels passes at 253. Checked against the
// shipped catalogs: `app.kubernetes.io/name` and the selector labels carry
// the COMPONENT name (#NameType, ≤63 by construction), never resourceName —
// so a dotted 200-rune resourceName cannot leak into a label today. D19's
// sweep contract makes that a rule rather than an accident: no transformer
// may copy resourceName into a label value.
package e0019x11v5

import "strings"

// ---------------------------------------------------------------------------
// COPY — core/src/types.cue (unchanged by D20; stays the safety floor)
// ---------------------------------------------------------------------------

// NameType: RFC 1123 DNS label — lowercase alphanumeric with hyphens, max 63 chars
#NameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)

// ---------------------------------------------------------------------------
// NEW (D20)
// ---------------------------------------------------------------------------

// ObjectNameType: RFC 1123 DNS subdomain — what k8s metadata.name actually
// admits for most kinds. Dot-separated #NameType-shaped segments, 253-char
// budget. This is resourceName's new ceiling: permissive by default,
// tightened per attachment by #nameConstraint (D21).
#ObjectNameType: string & =~"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$" & strings.MinRunes(1) & strings.MaxRunes(253)

// ServiceNameType: RFC 1035 DNS label — Service's validator. Differs from
// #NameType in exactly one place: the first character must be alphabetic.
// #NameType admits "1foo"; the API server rejects Service "1foo" at apply.
// This type is what closes that gap at vet time.
#ServiceNameType: string & =~"^[a-z]([a-z0-9-]*[a-z0-9])?$" & strings.MinRunes(1) & strings.MaxRunes(63)
