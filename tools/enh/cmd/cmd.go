// Package cmd dispatches the commands of enh: the checker, the writing tasks,
// the read-only views and the lint tools of design part two, section 3.
package cmd

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/open-platform-model/enhancements/tools/enh/internal/sys"
	"github.com/open-platform-model/enhancements/tools/enh/internal/tasks"
)

// Exit codes. 1 means the checker found an error or a task refused; 2 means a
// wrong argument or a run that failed.
const (
	ExitOK    = 0
	ExitError = 1
	ExitUsage = 2
)

// Deps are the things a test replaces: the program runner, the clock, the
// environment and the standard input.
type Deps struct {
	Runner sys.Runner
	Now    func() time.Time
	Getenv func(string) string
	Stdin  io.Reader
	Cwd    func() (string, error)
}

// Run executes one enh command line and returns the exit code.
func Run(args []string, stdout, stderr io.Writer) int {
	return RunWith(Deps{Runner: sys.Exec, Now: time.Now, Getenv: os.Getenv, Stdin: os.Stdin, Cwd: os.Getwd}, args, stdout, stderr)
}

// RunWith is Run with its dependencies given.
func RunWith(d Deps, args []string, stdout, stderr io.Writer) int {
	if d.Runner == nil {
		d.Runner = sys.Exec
	}
	if d.Now == nil {
		d.Now = time.Now
	}
	if d.Getenv == nil {
		d.Getenv = os.Getenv
	}
	if d.Cwd == nil {
		d.Cwd = os.Getwd
	}
	if len(args) == 0 {
		fmt.Fprint(stderr, topUsage())
		return ExitUsage
	}
	switch args[0] {
	case "help", "-h", "--help":
		if len(args) > 1 {
			if c := lookup(args[1]); c != nil {
				fmt.Fprint(stdout, c.helpText())
				return ExitOK
			}
			fmt.Fprintf(stderr, "enh: unknown command %q\n\n%s", args[1], topUsage())
			return ExitUsage
		}
		fmt.Fprint(stdout, topUsage())
		return ExitOK
	}
	c := lookup(args[0])
	if c == nil {
		fmt.Fprintf(stderr, "enh: unknown command %q\n\n%s", args[0], topUsage())
		return ExitUsage
	}
	return c.dispatch(d, args[1:], stdout, stderr)
}

func topUsage() string {
	var b strings.Builder
	b.WriteString("enh checks and edits the enhancement entries of this repository.\n\nUsage:\n  enh <command> [flags] [arguments]\n  enh help <command>\n\nCommands:\n")
	names := make([]string, 0, len(commands))
	for _, c := range commands {
		names = append(names, c.name)
	}
	sort.Strings(names)
	for _, n := range names {
		c := lookup(n)
		fmt.Fprintf(&b, "  %-12s %s\n", c.name, c.summary)
	}
	b.WriteString("\nEvery command takes --help. Flags may come before or after the arguments.\n")
	b.WriteString("Environment: CONFIRM=1 is --confirm; ENH_FINAL=1 makes a remaining legacy folder an error (V30).\n")
	b.WriteString("Exit codes: 0 done, 1 the checker found an error or a task refused, 2 usage or a failed run.\n")
	return b.String()
}

// finish maps the error of a task to an exit code and prints its message.
func finish(name string, err error, stderr io.Writer) int {
	switch {
	case err == nil:
		return ExitOK
	case tasks.IsRefusal(err):
		fmt.Fprintf(stderr, "enh %s: %v\n", name, err)
		return ExitError
	case tasks.IsUsage(err):
		fmt.Fprintf(stderr, "enh %s: %v\nsee `enh %s --help`\n", name, err, name)
		return ExitUsage
	}
	fmt.Fprintf(stderr, "enh %s: %v\n", name, err)
	return ExitUsage
}

// findRoot walks up from dir to the checkout root.
func findRoot(dir string) (string, error) {
	for d := dir; ; d = filepath.Dir(d) {
		if exists(filepath.Join(d, "schema.cue")) && exists(filepath.Join(d, "openspec")) {
			return d, nil
		}
		if filepath.Dir(d) == d {
			return "", fmt.Errorf("no schema.cue and openspec/ in %s or a parent; use --root", dir)
		}
	}
}

func exists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}
