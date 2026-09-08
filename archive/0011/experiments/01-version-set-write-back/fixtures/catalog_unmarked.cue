// A version field with no marker. OPM does not own it, so `version set` must
// refuse rather than write — the marker is the authority, not the name.
package identity

ModulePath: "example.com/catalogs/demo@v1" @opm(identity, owner=publish)
Version:    "1.2.0"
