// The policy projection for executor: module, defined ONCE by the
// declaring catalog as a plain CUE function and emitted by every provider
// adapter. Not a transformer: a transformer here would have to require
// `backup` and make this catalog a second provider of it.
package projection

import "strings"

#ResticFlags: {
	keepLast:    "--keep-last"
	keepHourly:  "--keep-hourly"
	keepDaily:   "--keep-daily"
	keepWeekly:  "--keep-weekly"
	keepMonthly: "--keep-monthly"
	keepYearly:  "--keep-yearly"
	keepWithin:  "--keep-within"
}

// ConfigMap `<component>-backup-config` in the instance namespace.
#ConfigMap: {
	#backup:    _ // the component's spec.backup
	#repo:      _ // the resolved repository entry, or {}
	#name:      string
	#instance:  string
	#namespace: string
	#labels: [string]: string

	_keys: [if #backup.projection != _|_ {#backup.projection.envKeys}, {
		schedule:  "BACKUP_SCHEDULE"
		retention: "BACKUP_RETENTION"
		excludes:  "BACKUP_EXCLUDES"
	}][0]
	_flags: [if #backup.retention != _|_ for k, v in #backup.retention {"\(#ResticFlags[k]) \(v)"}]
	_excludes: [if #backup.excludes != _|_ {#backup.excludes}, []][0]

	out: {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:      "\(#name)-backup-config"
			namespace: #namespace
			labels:    #labels
		}
		data: {
			if #repo.s3 != _|_ {
				RESTIC_REPOSITORY: "s3:\(#repo.s3.endpoint)/\(#repo.s3.bucket)/\(#instance)"
			}
			// Pinned to the namespace so an engine's `forget --host` sees
			// the module's snapshots.
			RESTIC_HOSTNAME: #namespace
			if #backup.schedule != _|_ {
				(_keys.schedule): #backup.schedule
			}
			if len(_flags) > 0 {
				(_keys.retention): strings.Join(_flags, " ")
			}
			if len(_excludes) > 0 {
				(_keys.excludes): strings.Join(_excludes, ",")
			}
		}
	}
}
