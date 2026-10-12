// Command enh is the tool of the enhancements repository. See the cmd package.
package main

import (
	"os"

	"github.com/open-platform-model/enhancements/tools/enh/cmd"
)

func main() {
	os.Exit(cmd.Run(os.Args[1:], os.Stdout, os.Stderr))
}
