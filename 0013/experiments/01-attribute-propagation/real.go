package main

import (
	"fmt"
	"os"
	"path/filepath"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/load"
)

// realCore runs the same questions against a frozen snapshot of the REAL
// opmodel.dev/core@v1 schema (cue-deps/core, copied from core/src at 7500c5d),
// with a module and instance written the way a module author would write them.
//
// This is the half that matters: the synthetic cases above prove CUE behaviour,
// this proves the behaviour holds for the artifact shape OPM actually ships.
func realCore() {
	hdr("REAL  frozen opmodel.dev/core@v1 snapshot")

	dir, err := filepath.Abs("module")
	if err != nil {
		fmt.Println("  abs:", err)
		return
	}
	insts := load.Instances([]string{"."}, &load.Config{Dir: dir})
	if len(insts) == 0 || insts[0].Err != nil {
		fmt.Println("  load error:", insts[0].Err)
		os.Exit(1)
	}
	v := ctx.BuildInstance(insts[0])
	if v.Err() != nil {
		fmt.Println("  build error:", v.Err())
		os.Exit(1)
	}

	inst := v.LookupPath(cue.ParsePath("inst"))
	ns, _ := inst.LookupPath(cue.ParsePath("metadata.namespace")).String()
	nm, _ := inst.LookupPath(cue.ParsePath("metadata.name")).String()
	fmt.Printf("  instance %s/%s built against the real #Module / #ModuleInstance\n\n", ns, nm)

	// Phase 1 — discovery from the schema side. This is the exact path the
	// library kernel already uses in kernel.Validate: schema.Config, which is
	// cue.MakePath(cue.Def("config")).
	schema := inst.LookupPath(cue.ParsePath("#module.#config"))
	decls := discover(schema)
	fmt.Println("  A. discovered on #module.#config (no values consulted):")
	for _, d := range decls {
		fmt.Printf("     %-46s %v\n", d.path, d.args)
	}

	// Phase 2 — join to data by config path.
	fmt.Println("\n  B. joined against inst.values by config path:")
	values := inst.LookupPath(cue.ParsePath("values"))
	for _, d := range decls {
		val := values.LookupPath(cue.ParsePath(d.path))
		s, err := val.String()
		if err != nil {
			fmt.Printf("     %-46s <unfulfilled>\n", d.path)
			continue
		}
		fmt.Printf("     %-46s %q\n", d.path, s)
	}

	// Marks declared in a DIFFERENT CUE module (cue-deps/frag) arrive intact —
	// so a catalog can ship pre-marked schema fragments.
	fmt.Println("\n  C. a mark declared in an imported CUE module:")
	for _, d := range decls {
		if len(d.path) >= 4 && d.path[:4] == "auth" {
			fmt.Printf("     %-46s %v  <- declared in example.com/frag@v1\n", d.path, d.args)
		}
	}

	// Discovery works with no instance at all.
	bare := v.LookupPath(cue.ParsePath("theModule.#config"))
	fmt.Printf("\n  D. same walk on the bare module (no instance): %d declarations\n", len(discover(bare)))
}
