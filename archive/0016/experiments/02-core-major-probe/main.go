// Experiment 02: can a candidate's core dependency major be read from the
// module-file blob alone, and how does that compare with the full zip?
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"cuelang.org/go/mod/modconfig"
	"cuelang.org/go/mod/modfile"
	"cuelang.org/go/mod/modregistry"
	"cuelang.org/go/mod/module"
)

func main() {
	full := flag.Bool("full", false, "also download the module zip (comparison arm)")
	flag.Parse()
	if flag.NArg() != 2 {
		fmt.Fprintln(os.Stderr, "usage: go run . [--full] <module-path@vN> <vX.Y.Z>")
		os.Exit(2)
	}
	path, version := flag.Arg(0), flag.Arg(1)

	resolver, err := modconfig.NewResolver(&modconfig.Config{Env: os.Environ()})
	check(err, "resolver")
	client := modregistry.NewClientWithResolver(resolver)
	ctx := context.Background()

	mv, err := module.NewVersion(path, version)
	check(err, "version")

	start := time.Now()
	m, err := client.GetModule(ctx, mv)
	check(err, "GetModule (manifest)")
	tManifest := time.Since(start)

	start = time.Now()
	modBytes, err := m.ModuleFile(ctx)
	check(err, "ModuleFile")
	tModfile := time.Since(start)

	f, err := modfile.ParseNonStrict(modBytes, "cue.mod/module.cue")
	check(err, "modfile.Parse")

	coreDep := "(none)"
	for depPath, dep := range f.Deps {
		if strings.HasPrefix(depPath, "opmodel.dev/core@") {
			coreDep = fmt.Sprintf("%s %s", depPath, dep.Version)
		}
	}
	fmt.Printf("%s %s\n", path, version)
	fmt.Printf("  manifest fetch:    %v\n", tManifest)
	fmt.Printf("  module.cue blob:   %v, %d bytes\n", tModfile, len(modBytes))
	fmt.Printf("  core dependency:   %s\n", coreDep)
	if os.Getenv("DUMP_MODFILE") != "" {
		fmt.Printf("  --- cue.mod/module.cue ---\n%s", modBytes)
	}

	if *full {
		start = time.Now()
		zr, err := m.GetZip(ctx)
		check(err, "GetZip")
		n, err := io.Copy(io.Discard, zr)
		check(err, "read zip")
		check(zr.Close(), "close zip")
		fmt.Printf("  full zip blob:     %v, %d bytes\n", time.Since(start), n)
	}
}

func check(err error, what string) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", what, err)
		os.Exit(1)
	}
}
