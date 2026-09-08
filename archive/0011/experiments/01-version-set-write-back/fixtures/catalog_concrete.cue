// A catalog that already carries a version, with the two identity fields
// aligned as `cue fmt` leaves them. Setting a longer value re-aligns.
package identity

ModulePath: "example.com/catalogs/demo@v1" @opm(identity, owner=publish)
Version:    "1.2.0"                        @opm(identity, owner=publish)
