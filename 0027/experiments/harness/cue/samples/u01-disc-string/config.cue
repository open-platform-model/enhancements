package s_u01_disc_string



#config: {
	backup: {kind: "s3", bucket!: string, region: string | *"eu-north-1"} | {kind: "nfs", server!: string, path: string | *"/"}
}
