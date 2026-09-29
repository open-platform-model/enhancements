// Stand-in for PLATFORM configuration (design doc OQ2): repository names
// to backends. One table, imported by the declaring catalog's projection
// transformer and by both providers, each reading the columns it needs.
// 0015 has no surface for platform-level values; a catalog package
// carrying them is the experiment's shortcut, not a proposal.
package config

repositories: [string]: {
	// restic-shaped object storage (k8up backend, module-owned tools).
	s3!: {endpoint!: string, bucket!: string}
	// Secret in the INSTANCE namespace: RESTIC_PASSWORD, AWS_ACCESS_KEY_ID,
	// AWS_SECRET_ACCESS_KEY. Its name is the convention a module-owned
	// tool relies on (backup-owned).
	secretName!: string
	// Velero: the admin-owned BackupStorageLocation.
	storageLocation!: string
}

repositories: "mc-backup": {
	s3: {endpoint: "http://10.10.0.2:30304", bucket: "mc-backup"}
	secretName:      "mc-backup-restic"
	storageLocation: "mc-backup"
}
