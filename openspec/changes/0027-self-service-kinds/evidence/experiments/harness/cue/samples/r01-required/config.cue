package s_r01_required



#config: {
	reqMarked!: string
	regularNoDefault: string
	defaulted: int | *3
	optional?: string
	constant: "fixed"
	computed: "\(reqMarked)-svc"
	nested: {inner: string | *"x"}
	nestedReq: {inner!: string}
	listDefault: [...string] | *["a"]
	boolDefault: *false | bool
	app: string | *"app"
	fromDefault: "\(app)-x"
}
