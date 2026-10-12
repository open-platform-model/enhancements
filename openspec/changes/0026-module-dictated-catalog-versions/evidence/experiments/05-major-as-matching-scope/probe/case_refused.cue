@if(refused)

package core

// Evaluated only with -t refused; both fields are expected to fail.

// One component cannot carry both majors' copy of one key.
compBoth: #Component & {
	metadata: name:                           "x"
	#resources: (_v4.container.metadata.fqn): _v4.container
	#resources: (_v5.container.metadata.fqn): _v5.container
}
// A leaf that AUTHORS a wrong scope is refused by the derivation.
authoredWrong: _v4.container & {metadata: catalog: "opmodel.dev/catalogs/opm@v5"}
