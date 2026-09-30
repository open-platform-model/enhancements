@if(owner)

package core

// The ownership assertion added to #Catalog. Evaluated only with -t owner.

// L5: opm@v6 tries to list opm@v5's key (ownership assertion).
lineageL5: #Catalog & {
	metadata: {modulePath: "opmodel.dev/catalogs/opm@v6", version: "6.0.0"}
	#resources: (_opm5.container.metadata.fqn): _opm5.container
}
