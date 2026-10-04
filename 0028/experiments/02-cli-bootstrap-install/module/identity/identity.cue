// Package identity is the single source of this module's path and version
// (core #IdentityPackage). Bottom of the import graph: no intra-module
// imports, no core import.
package identity

// ModulePath is byte-identical to cue.mod's `module:` field. Experimental
// coordinate under testing.opmodel.dev (workspace Registry Policy).
ModulePath: "testing.opmodel.dev/modules/experiments/opm-operator-bootstrap/opm_operator@v0"

// Version is the module's bare SemVer; its major must agree with ModulePath's.
Version: "0.1.0"
