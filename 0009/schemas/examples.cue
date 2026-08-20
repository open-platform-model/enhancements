// Concrete example instances for the target.cue delta — the test.
//
// Every NEW definition in the delta manifest is exercised by at least one
// realistic instance unified against it, so `cue vet ./...` from this
// directory validates the shapes rather than just parsing them. Derivable
// values (the #Action FQN interpolation, the fixed `kind` discriminators,
// the #WaitOp interval default) are pinned with hidden _assert* fields so a
// behaviour change breaks the build. The scenario is the one from
// ../01-problem.md: a schema migration bound to pre-upgrade, plus an
// on-demand seed-demo workflow.
package schema

// ─────────────────────────────────────────────────────────────────────────────
// #Op — one instance per well-known kind (exercises #Op, #OpKind, #ExecOp,
// #HttpOp, #WaitOp, #CueOp).
// ─────────────────────────────────────────────────────────────────────────────

ops: {
	waitForDB: #WaitOp & {
		condition: "db.ready"
		timeout:   "120s"
	}

	migrate: #ExecOp & {
		image: "flyway/flyway:10"
		command: ["flyway", "migrate"]
		env: FLYWAY_URL: "jdbc:postgresql://db:5432/app"
		workdir: "/flyway"
	}

	notify: #HttpOp & {
		method: "POST"
		url:    "https://hooks.example.internal/deploys"
		headers: "content-type": "application/json"
		body: '{"status": "migrated"}'
	}

	checkExit: #CueOp & {
		expression: "out.exitCode == 0"
		scope: out: exitCode: 0
	}
}

// Discriminators are fixed by each well-known Op, not authored — pin them.
_assertWaitKind: ops.waitForDB.opKind & "wait"
_assertExecKind: ops.migrate.opKind & "exec"
_assertHttpKind: ops.notify.opKind & "http"
_assertCueKind:  ops.checkExit.opKind & "cue.eval"

// #WaitOp defaults interval to "5s" when the author does not set it.
_assertWaitIntervalDefault: true & (ops.waitForDB.interval == "5s")

// Every opKind must satisfy the #OpKind grammar (dotted lowercase).
_assertOpKindGrammar: #OpKind & ops.checkExit.opKind

// ─────────────────────────────────────────────────────────────────────────────
// #Action — FQN-identified composition with explicit dependsOn ordering
// (exercises #Action, #Step, #StepMap, #ActionMap; OQ2: ordering edges only).
// ─────────────────────────────────────────────────────────────────────────────

dbMigration: #Action & {
	metadata: {
		modulePath:  "opmodel.dev/catalogs/opm/actions"
		version:     "1.0.0"
		name:        "db-migration"
		description: "Wait for the database, then apply the schema migration."
	}
	steps: {
		"wait-for-db": #WaitOp & {
			condition: "db.ready"
			timeout:   "120s"
		}
		migrate: #ExecOp & {
			image: "flyway/flyway:10"
			command: ["flyway", "migrate"]
			dependsOn: ["wait-for-db"]
		}
	}
}

// The FQN is derived from modulePath/name@version — pin the interpolation.
_assertActionFQN: dbMigration.metadata.fqn & "opmodel.dev/catalogs/opm/actions/db-migration@1.0.0"

// An FQN-keyed catalog-style map of Actions (as the #Catalog sibling map
// sketch would carry them).
actionCatalog: #ActionMap
actionCatalog: (dbMigration.metadata.fqn): dbMigration

// ─────────────────────────────────────────────────────────────────────────────
// #Lifecycle — steps bound to the fixed nine-phase vocabulary (exercises
// #Lifecycle, #Phase; the D7 phase set is closed).
// ─────────────────────────────────────────────────────────────────────────────

appLifecycle: #Lifecycle & {
	phases: {
		"pre-upgrade": [
			ops.waitForDB,
			ops.migrate,
		]
		"post-install": [
			ops.notify,
		]
	}
}

_assertLifecycleKind: appLifecycle.kind & "Lifecycle"

// Absent phases are simply not present — only the two authored phases exist.
_assertPreUpgradeSteps: true & (len(appLifecycle.phases["pre-upgrade"]) == 2)

// ─────────────────────────────────────────────────────────────────────────────
// #Workflow — on-demand invocation (exercises #Workflow, #WorkflowMap;
// run-state model is OQ3 and deliberately not modelled here).
// ─────────────────────────────────────────────────────────────────────────────

seedDemo: #Workflow & {
	metadata: {
		name:        "seed-demo"
		description: "One-shot demo-data seed, invoked explicitly by an operator."
	}
	steps: run: #ExecOp & {
		image: "myorg/seeder:1"
		command: ["seed", "--dataset=demo"]
	}
}

_assertWorkflowKind: seedDemo.kind & "Workflow"

workflows: #WorkflowMap
workflows: "seed-demo": seedDemo

// ─────────────────────────────────────────────────────────────────────────────
// Must-fail cases (commented out; re-run by hand to confirm). Error text is
// what `cue vet ./...` printed when the block was enabled.
// ─────────────────────────────────────────────────────────────────────────────

// A phase outside the fixed D7 vocabulary is rejected:
//
//	badLifecycle: #Lifecycle & {
//		phases: "pre-rollback": [ops.notify]
//	}
//
// error: badLifecycle.phases."pre-rollback": field not allowed

// An Op kind outside the #OpKind grammar is rejected:
//
//	badOp: #Op & {opKind: "Not_Valid"}
//
// error: badOp.opKind: invalid value "Not_Valid" (out of bound =~"^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$")

// A step name outside the #Name grammar is rejected by #StepMap:
//
//	badAction: dbMigration
//	badAction: steps: "Bad_Name": ops.waitForDB
//
// error: badAction.steps.Bad_Name: field not allowed
