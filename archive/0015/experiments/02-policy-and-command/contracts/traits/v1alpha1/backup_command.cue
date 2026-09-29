// The one thing a module can hand the platform: a command that writes a
// consistent artefact to stdout, with any quiesce inside it. Engines that
// run commands in their own pod consume stdout (k8up PreBackupPod,
// mounting the named volumes read-only beside the workload); engines that
// capture files run it in the live container and capture the landing
// volume only (Velero). One module, both engines. Meaningful under
// executor: platform only.
package v1alpha1

import (
	id "testing.opmodel.dev/experiments/0015/exp02/contracts/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#BackupCommandTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1alpha1"
		name:           "backup-command"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/backup-command@v1alpha1"
		description:    "The backup is the artefact a command writes to stdout; the command owns its quiesce"
		labels: "trait.opmodel.dev/category": "storage"
	}
	fulfilment: "provider"
	optional:   false
	appliesTo: [res.#ContainerResource]
	spec: backupCommand: #BackupCommandSchema
}

#BackupCommand: c.#Component & {
	#traits: (#BackupCommandTrait.metadata.fqn): #BackupCommandTrait
}

#BackupCommandSchema: {
	// Image and env come from this component container.
	container!: string

	// A shell command line writing the artefact to STDOUT; every engine
	// runs it as `sh -c <command>`. No single quotes (k8up wraps in them).
	//   save-off && save-all flush && sync && tar -C /data -c . ; save-on
	command!: string & !="" & !~"'"

	// Component volume keys the command reads. Engines that run it in
	// their own pod mount them read-only beside the workload.
	volumes?: [...string]

	// Where FILE-capturing engines put the output: the adapter appends
	// `> <mount>/<path>` and captures that volume only. Stream engines
	// ignore it. Required for portability to Velero.
	landing?: {volume!: string, path!: string & =~"^[^/].*"}

	// Retention-group identity suffix; the adapter prefixes instance and
	// component.
	fileExtension: string & =~"^\\.[a-z0-9]+(\\.[a-z0-9]+)*$" | *".sql"

	// Idempotent release for a quiesce that does not self-heal (Minecraft
	// save-off). Engines with post hooks run it after every capture.
	compensate?: command!: [string, ...string]
}
