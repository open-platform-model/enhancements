// Experiment 01: does ModuleVersions on a major-free path list every major?
package main

import (
	"context"
	"fmt"
	"os"

	"cuelang.org/go/mod/modconfig"
	"cuelang.org/go/mod/modregistry"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: go run . <module-path>[@vN]")
		os.Exit(2)
	}
	resolver, err := modconfig.NewResolver(&modconfig.Config{Env: os.Environ()})
	if err != nil {
		fmt.Fprintln(os.Stderr, "resolver:", err)
		os.Exit(1)
	}
	client := modregistry.NewClientWithResolver(resolver)
	for _, path := range os.Args[1:] {
		versions, err := client.ModuleVersions(context.Background(), path)
		if err != nil {
			fmt.Printf("%s\n  ERROR %v\n", path, err)
			continue
		}
		fmt.Printf("%s  (%d versions)\n", path, len(versions))
		for _, v := range versions {
			fmt.Printf("  %s\n", v)
		}
	}
}
