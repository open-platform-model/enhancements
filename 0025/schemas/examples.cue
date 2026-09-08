// Concrete example instances for the target.cue delta: the test.
//
// One worked cast: a platform team offers example.com/modules/postgres on
// its v1 line as PostgresDatabase.platform.example.com, binding the storage
// class; team-orders creates one. Hidden assertion fields pin every derived
// value so a behaviour change breaks `cue vet ./...`.
package schema

// ─── The offered module (the module does not know it is offered, D5) ────────

postgresModule: #Module & {
	metadata: {
		name:         "postgres"
		modulePath:   "example.com/modules/postgres@v1"
		version:      "1.4.2"
		registryPath: "example.com/modules/postgres"
	}
	#config: {
		storage!:      string
		replicas:      int & >=1 | *1
		storageClass!: string
	}
}

// ─── The definition (binding + kind layers) ─────────────────────────────────

postgresOffering: #Offering & {
	metadata: name: "postgres-database"
	spec: {
		module: {
			registryPath: "example.com/modules/postgres"
			major:        1
			version:      "1.4.2"
		}
		values: storageClass: "fast-ssd"
		api: {
			group: "platform.example.com"
			kind:  "PostgresDatabase"
		}
	}
}

// OQ3: the default is the placeholder default until decided.
_assertDefaultPolicy: postgresOffering.spec.updatePolicy & "manual"

// A binding-only definition (no api) is legal (D4).
cacheBinding: #Offering & {
	metadata: name: "redis-cache"
	spec: module: {
		registryPath: "example.com/modules/redis"
		major:        2
		version:      "2.0.1"
	}
}

// ─── The served CRD version derives from the major (D7) ─────────────────────

_assertKindVersion1: (#KindVersion & {#major: 1}).out & "v1"
_assertKindVersion2: (#KindVersion & {#major: 2}).out & "v2"

// ─── A consumer's instance of the served kind ───────────────────────────────

ordersDB: #OfferingInstance & {
	#offering: postgresOffering
	metadata: {
		name:      "orders-db"
		namespace: "team-orders"
	}
	spec: {
		storage:  "20Gi"
		replicas: 2
	}
}

_assertAPIVersion: ordersDB.apiVersion & "platform.example.com/v1"
_assertKind:       ordersDB.kind & "PostgresDatabase"

// ─── The projection (D6): definition + instance + module -> #ModuleInstance ──

ordersProjected: #Project & {
	#offering: postgresOffering
	#instance: ordersDB
	#module:   postgresModule
}

_assertProjectedName:      ordersProjected.out.metadata.name & "orders-db"
_assertProjectedNamespace: ordersProjected.out.metadata.namespace & "team-orders"
_assertProjectedKind:      ordersProjected.out.kind & "ModuleInstance"

// Bound value from the definition, consumer value from the instance, default
// from #config: all three reach the rendered values.
_assertBoundValue:    ordersProjected.out.values.storageClass & "fast-ssd"
_assertConsumerValue: ordersProjected.out.values.storage & "20Gi"
_assertConsumerInt:   ordersProjected.out.values.replicas & 2
_assertModuleVersion: ordersProjected.out.#module.metadata.version & "1.4.2"

// A second instance leaves replicas to the #config default.
billingDB: #OfferingInstance & {
	#offering: postgresOffering
	metadata: {
		name:      "billing-db"
		namespace: "team-billing"
	}
	spec: storage: "50Gi"
}

billingProjected: #Project & {
	#offering: postgresOffering
	#instance: billingDB
	#module:   postgresModule
}

_assertDefaultReplicas: billingProjected.out._configCheck.replicas & 1

// ─── Must-fail cases (recorded, commented out; re-run by hand) ──────────────
//
// 1. A consumer overriding a bound value is a refusal, not an override (D6).
//
//    badOverride: #Project & {
//        #offering: postgresOffering
//        #instance: #OfferingInstance & {
//            #offering: postgresOffering
//            metadata: {name: "x", namespace: "team-x"}
//            spec: {storage: "1Gi", storageClass: "gp2"}
//        }
//        #module: postgresModule
//    }
//    // conflicting values "fast-ssd" and "gp2"
//
// 2. A bound release outside the bound major is refused (D7).
//
//    badMajor: #Offering & {
//        metadata: name: "postgres-database"
//        spec: module: {registryPath: "example.com/modules/postgres", major: 1, version: "2.0.0"}
//    }
//    // spec.module._agrees: conflicting values true and false
//
// 3. A served-kind instance for a binding-only definition is refused (D4):
//    #OfferingInstance requires spec.api on its definition.
//
//    badInstance: #OfferingInstance & {
//        #offering: cacheBinding
//        metadata: {name: "x", namespace: "team-x"}
//        spec: {}
//    }
//    // #offering.spec.api: field is required but not present
//
// 4. A module whose #config is not structural (a comprehension, an open `_`)
//    is refused at definition acceptance (D2). Not expressible as a CUE
//    constraint in this delta; the encoder is the check.
