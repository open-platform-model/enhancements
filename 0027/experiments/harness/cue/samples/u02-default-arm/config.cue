package s_u02_default_arm



#config: {
	backup: *{kind: "none"} | {kind: "s3", bucket!: string}
}
