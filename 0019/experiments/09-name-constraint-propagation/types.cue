// The three name types D20 proposes, plus the copied current #NameType they
// split from.
//
// Copied (not referenced) per experiment rule 3:
//   #NameType — core/src/types.cue line 10, byte-identical.
// The other two are NEW — this file IS the proposal under review.
//
// The empirical matrix these encode was measured against a live k8s v1.33.0
// API server (server-side dry-run, 2026-08-24):
//
//   kind          dots  rule            validator observed
//   ------------  ----  --------------  ---------------------------------
//   Deployment    yes   DNS-1123 subd.  accepted "a.b.c"
//   DaemonSet     yes   DNS-1123 subd.  accepted "a.b.c"
//   ConfigMap     yes   DNS-1123 subd.  accepted "a.b.c"
//   StorageClass  yes   DNS-1123 subd.  accepted "a.b.c"
//   CSIDriver     yes   DNS-1123 subd.  accepted "zfs.csi.openebs.io"
//   Service       NO    DNS-1035 label  "a DNS-1035 label must ... start
//                                        with an alphabetic character"
//   StatefulSet   NO    bespoke         "must not contain dots"
//   Namespace     NO    bespoke         "must not contain dots"
//
// The rule is exactly: a name is dot-restricted iff it becomes a DNS label.
package e0019x09

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
