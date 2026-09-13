// Shape A: the backup is a consistent artefact a command PRODUCES, with
// any quiesce inside the command. Replaces the `backup-hooks` and
// `backup-command` contracts of this experiment's earlier cuts. Engines that run commands in
// their own pod consume stdout (k8up PreBackupPod, mounting the named
// volumes read-only beside the workload); engines that capture files run
// it in the live container and capture the landing volume only (Velero).
// One module, both engines.
package v1alpha1

import (
	id "testing.opmodel.dev/experiments/0015/exp02/contracts/identity"
	c "opmodel.dev/core@v2"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
)

#BackupProducerTrait: c.#Trait & {
	metadata: {
		modulePath:     "\(id.kindPrefix.traits)/v1alpha1"
		name:           "backup-producer"
		apiVersion:     "v1alpha1"
		catalogVersion: id.Version
		fqn:            "\(id.kindPrefix.traits)/backup-producer@v1alpha1"
		description:    "The backup is the artefact a command writes to stdout; the command owns its quiesce"
		labels: "trait.opmodel.dev/category": "storage"
	}
	fulfilment: "provider"
	optional:   false
	appliesTo: [res.#ContainerResource]
	spec: backupProducer: #BackupProducerSchema
}

#BackupProducer: c.#Component & {
	#traits: (#BackupProducerTrait.metadata.fqn): #BackupProducerTrait
}

#BackupProducerSchema: {
	// Image and env for the producer come from this component container.
	container!: string

	// A shell command line writing the artefact to STDOUT; every engine
	// runs it as `sh -c <command>`. No single quotes (k8up wraps in them).
	// Quiesce, capture and release all live here, e.g.
	//   save-off && save-all flush && sync && tar -C /data -c . ; save-on
	command!: string & !="" & !~"'"

	// Component volume keys the command reads. Engines that run it in
	// their own pod mount them read-only beside the workload (same node);
	// engines that run it in the live container already have them.
	volumes?: [...string]

	// Where engines that capture FILES (not streams) put the output: the
	// adapter appends `> <mount>/<path>` and captures that volume only.
	// Stream engines ignore it. Required for portability to Velero.
	landing?: {volume!: string, path!: string & =~"^[^/].*"}

	// Retention-group identity suffix; the adapter prefixes instance and
	// component.
	fileExtension: string & =~"^\\.[a-z0-9]+(\\.[a-z0-9]+)*$" | *".sql"

	// Idempotent release for a quiesce that does not self-heal (Minecraft
	// save-off). Engines with post hooks run it after every capture with
	// errors ignored; the module's own startup is the last resort.
	compensate?: command!: [string, ...string]
}
