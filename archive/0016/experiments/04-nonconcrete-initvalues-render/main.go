// Experiment 04: does a non-concrete initValues survive the synth render path?
// The two render lines are copied from library/opm/helper/synth/render.go
// (renderValuesFile): Syntax(cue.Final(), cue.Concrete(false)) + format.Node.
package main

import (
	"fmt"
	"os"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/format"
)

var cases = map[string]string{
	"default": `
#config: { replicas: int & >=1 | *1, logLevel: string | *"info" }
initValues: { replicas: *1 | int, logLevel: *"info" | string }`,
	"disjunction": `
#config: { logLevel: "debug" | "info" | "warn" }
initValues: { logLevel: "info" | "debug" }`,
	"optional": `
#config: { host: string, port?: int }
initValues: { host: "example.internal", port?: int }`,
	"mixed": `
#config: { replicas: int & >=1 | *1, logLevel: "debug" | "info" | "warn", port?: int }
initValues: { replicas: *2 | int, logLevel: "info" | "debug", port?: int }`,
}

func main() {
	name := os.Args[1]
	src, ok := cases[name]
	if !ok {
		fmt.Fprintln(os.Stderr, "unknown case", name)
		os.Exit(2)
	}
	ctx := cuecontext.New()
	root := ctx.CompileString(src)
	if err := root.Err(); err != nil {
		fmt.Println("compile:", err)
		os.Exit(1)
	}
	iv := root.LookupPath(cue.ParsePath("initValues"))

	// --- copied render path ---
	node := iv.Syntax(cue.Final(), cue.Concrete(false))
	rendered, err := format.Node(node)
	if err != nil {
		fmt.Println("format:", err)
		os.Exit(1)
	}
	out := "package instance\n\nvalues: " + string(rendered) + "\n"
	_ = os.WriteFile("out/values-"+name+".cue", []byte(out), 0o644)
	fmt.Printf("== %s: rendered values.cue\n%s", name, out)

	// --- re-load and compare with the original constraint ---
	re := ctx.CompileString(out).LookupPath(cue.ParsePath("values"))
	if err := re.Err(); err != nil {
		fmt.Println("re-parse:", err)
		os.Exit(1)
	}
	cfg := root.LookupPath(cue.ParsePath("#config"))
	unified := cfg.Unify(re)
	fmt.Printf("-- re-parsed & unified with #config: validate(non-concrete)=%v\n", unified.Validate(cue.Concrete(false)))
	fmt.Printf("-- original initValues subsumes rendered? %v\n", iv.Subsume(re) == nil)
	fmt.Printf("-- rendered subsumes original? %v\n", re.Subsume(iv) == nil)
	fmt.Printf("-- rendered is concrete? %v\n", re.Validate(cue.Concrete(true)) == nil)
}
