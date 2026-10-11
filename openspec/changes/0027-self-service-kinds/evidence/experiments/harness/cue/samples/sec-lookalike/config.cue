package s_sec_lookalike



#config: {
	// Same shape as core's #Secret, no core tag.
	pw: {value!: string} | {ref!: string, key!: string}
}
