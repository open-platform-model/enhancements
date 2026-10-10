// Package cmd dispatches the commands of enh. Only `vet` exists in this
// track; the writing tasks join in T3.3.
package cmd

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
)

// Exit codes. 1 means the checker found an error; 2 means the run itself failed.
const (
	ExitOK    = 0
	ExitError = 1
	ExitUsage = 2
)

const usage = `enh checks and edits the enhancement entries of this repository.

Usage:
  enh vet [flags] [ID|FOLDER ...]   check every entry, or the named ones

Flags of vet:
  --root DIR      the checkout to read (default: the nearest parent with schema.cue and openspec/)
  --mode MODE     draft (default), accept or deliver; a stricter mode adds errors
  --openspec      also run the openspec CLI: validate at accept and deliver (V32)
  --strict        with --openspec, run validate --strict (V35)
  --today DATE    the date that bounds "created" (default: today, UTC)
  --schema FILE   the schema file (default: <root>/schema.cue)

Environment: ENH_FINAL=1 makes a remaining legacy folder an error (V30).
Exit codes: 0 no error, 1 the checker found an error, 2 usage or load failure.
`

// Run executes one enh command line and returns the exit code.
func Run(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, usage)
		return ExitUsage
	}
	switch args[0] {
	case "vet":
		return runVet(args[1:], stdout, stderr)
	case "help", "-h", "--help":
		fmt.Fprint(stdout, usage)
		return ExitOK
	}
	fmt.Fprintf(stderr, "enh: unknown command %q\n\n%s", args[0], usage)
	return ExitUsage
}

func runVet(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("vet", flag.ContinueOnError)
	fs.SetOutput(stderr)
	root := fs.String("root", "", "")
	mode := fs.String("mode", "draft", "")
	useOpenSpec := fs.Bool("openspec", false, "")
	strict := fs.Bool("strict", false, "")
	today := fs.String("today", "", "")
	schema := fs.String("schema", "", "")
	fs.Usage = func() { fmt.Fprint(stderr, usage) }
	if err := fs.Parse(args); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return ExitOK
		}
		return ExitUsage
	}
	m, err := vet.ParseMode(*mode)
	if err != nil {
		fmt.Fprintf(stderr, "enh vet: %v\n", err)
		return ExitUsage
	}
	if *strict && !*useOpenSpec {
		fmt.Fprintln(stderr, "enh vet: --strict needs --openspec")
		return ExitUsage
	}
	dir := *root
	if dir == "" {
		if dir, err = findRoot(); err != nil {
			fmt.Fprintf(stderr, "enh vet: %v\n", err)
			return ExitUsage
		}
	}
	opts := vet.Options{
		Root: dir, Mode: m, Keys: fs.Args(), Today: *today, SchemaPath: *schema,
		Strict: *strict, Final: os.Getenv("ENH_FINAL") == "1",
	}
	if *useOpenSpec {
		opts.OpenSpec = vet.ExecRunner
	}
	res, err := vet.Run(opts)
	if err != nil {
		fmt.Fprintf(stderr, "enh vet: %v\n", err)
		return ExitUsage
	}
	res.Format(stdout)
	if res.HasErrors() {
		return ExitError
	}
	return ExitOK
}

// findRoot walks up from the working directory to the checkout root.
func findRoot() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for d := wd; ; d = filepath.Dir(d) {
		if exists(filepath.Join(d, "schema.cue")) && exists(filepath.Join(d, "openspec")) {
			return d, nil
		}
		if filepath.Dir(d) == d {
			return "", fmt.Errorf("no schema.cue and openspec/ in %s or a parent; use --root", wd)
		}
	}
}

func exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
