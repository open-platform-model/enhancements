// VARIANT B — identity committed as a concrete value, with an OPM marker
// attribute recording that this field is tool-owned. CUE ignores the
// attribute; it exists so developers can see the field is managed and so
// `opm` can find what it owns without hardcoding field names.
package cat

ModulePath: "example.com/real-catalog@v1" @opm(identity, owner=publish)
Version:    "1.2.0"                       @opm(identity, owner=publish)

resourceFQN: ModulePath + "/resources/config-maps"
