package cmd

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"strconv"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/tasks"
)

// options holds the value of every flag of every command; a command registers
// the ones it takes.
type options struct {
	root, schema, base, head, since         string
	mode, today, seed, id, author           string
	workspace, filesFrom                    string
	confirm, noCommit, noValidate, archived bool
	openspec, strict, chain                 bool
	exclude                                 stringList
}

type stringList []string

func (s *stringList) String() string     { return strings.Join(*s, ",") }
func (s *stringList) Set(v string) error { *s = append(*s, v); return nil }

// call is one parsed command line.
type call struct {
	d      Deps
	o      *options
	name   string
	args   []string
	out    io.Writer
	errOut io.Writer
}

type command struct {
	name, synopsis, summary, help string
	flags                         func(fs *flag.FlagSet, o *options)
	min, max                      int // positional arguments; max -1 is no limit
	run                           func(c *call) int
}

func lookup(name string) *command {
	for i := range commands {
		if commands[i].name == name {
			return &commands[i]
		}
	}
	return nil
}

func (c *command) flagSet(o *options) *flag.FlagSet {
	fs := flag.NewFlagSet(c.name, flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	if c.flags != nil {
		c.flags(fs, o)
	}
	return fs
}

func (c *command) helpText() string {
	var b strings.Builder
	fmt.Fprintf(&b, "Usage: enh %s\n\n%s\n", c.synopsis, c.summary)
	if c.help != "" {
		fmt.Fprintf(&b, "\n%s\n", strings.TrimSpace(c.help))
	}
	fs := c.flagSet(&options{})
	var flags strings.Builder
	fs.VisitAll(func(f *flag.Flag) {
		name, usage := flag.UnquoteUsage(f)
		head := "  --" + f.Name
		if name != "" {
			head += " " + name
		}
		fmt.Fprintf(&flags, "%s\n        %s", head, usage)
		if f.DefValue != "" && f.DefValue != "false" {
			fmt.Fprintf(&flags, " (default %q)", f.DefValue)
		}
		flags.WriteString("\n")
	})
	if flags.Len() > 0 {
		fmt.Fprintf(&b, "\nFlags:\n%s", flags.String())
	}
	return b.String()
}

func (c *command) dispatch(d Deps, args []string, stdout, stderr io.Writer) int {
	o := &options{}
	fs := c.flagSet(o)
	pos, err := parseInterspersed(fs, args)
	if err != nil {
		if errors.Is(err, flag.ErrHelp) {
			fmt.Fprint(stdout, c.helpText())
			return ExitOK
		}
		fmt.Fprintf(stderr, "enh %s: %v\nsee `enh %s --help`\n", c.name, err, c.name)
		return ExitUsage
	}
	if len(pos) < c.min || (c.max >= 0 && len(pos) > c.max) {
		fmt.Fprintf(stderr, "enh %s: wrong number of arguments (%d)\nUsage: enh %s\n", c.name, len(pos), c.synopsis)
		return ExitUsage
	}
	return c.run(&call{d: d, o: o, name: c.name, args: pos, out: stdout, errOut: stderr})
}

// parseInterspersed parses flags that come before, between or after the
// positional arguments. Everything after a lone "--" is positional.
func parseInterspersed(fs *flag.FlagSet, args []string) ([]string, error) {
	var tail []string
	for i, a := range args {
		if a == "--" {
			tail = args[i+1:]
			args = args[:i]
			break
		}
	}
	var pos []string
	for {
		if err := fs.Parse(args); err != nil {
			return nil, err
		}
		rest := fs.Args()
		if len(rest) == 0 {
			return append(pos, tail...), nil
		}
		pos = append(pos, rest[0])
		args = rest[1:]
	}
}

// env builds the task environment from the flags.
func (c *call) env() (*tasks.Env, error) {
	root := c.o.root
	if root == "" {
		wd, err := c.d.Cwd()
		if err != nil {
			return nil, err
		}
		if root, err = findRoot(wd); err != nil {
			return nil, err
		}
	}
	e := &tasks.Env{
		Root: root, Schema: c.o.schema, Base: c.o.base, Run: c.d.Runner, Out: c.out, Err: c.errOut, Now: c.d.Now,
		Confirm:  c.o.confirm || c.d.Getenv("CONFIRM") == "1",
		NoCommit: c.o.noCommit, NoValidate: c.o.noValidate, ID: c.o.id,
	}
	if c.o.seed != "" {
		n, err := strconv.ParseUint(c.o.seed, 10, 64)
		if err != nil {
			return nil, fmt.Errorf("--seed %q must be a non-negative whole number", c.o.seed)
		}
		e.Seed = &n
	}
	if c.o.author != "" {
		e.Authors = splitList(c.o.author)
	}
	return e, nil
}

// withEnv runs fn with the environment, mapping a failure to build it to the
// usage exit code.
func (c *call) withEnv(fn func(e *tasks.Env) error) int {
	e, err := c.env()
	if err != nil {
		fmt.Fprintf(c.errOut, "enh %s: %v\n", c.name, err)
		return ExitUsage
	}
	return finish(c.name, fn(e), c.errOut)
}

func splitList(s string) []string {
	var out []string
	for _, p := range strings.Split(s, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func rootFlags(fs *flag.FlagSet, o *options) {
	fs.StringVar(&o.root, "root", "", "the checkout to read (default: the nearest parent with schema.cue and openspec/)")
	fs.StringVar(&o.schema, "schema", "", "the schema file (default: <root>/schema.cue)")
}

func gitFlags(fs *flag.FlagSet, o *options) {
	rootFlags(fs, o)
	fs.StringVar(&o.base, "base", "main", "the local branch the accept PR starts from")
}

func confirmFlags(fs *flag.FlagSet, o *options) {
	gitFlags(fs, o)
	fs.BoolVar(&o.confirm, "confirm", false, "write the record (the same as CONFIRM=1); needs a plain run first, with the same HEAD and entry files")
	fs.StringVar(&o.seed, "seed", "", "repeat a draw: the random seed that an earlier plain run printed")
}

func endFlags(fs *flag.FlagSet, o *options) {
	rootFlags(fs, o)
	fs.BoolVar(&o.noCommit, "no-commit", false, "leave the change in the working tree instead of making the commit")
	fs.BoolVar(&o.noValidate, "no-validate", false, "archive with --no-validate: for a draft that never validated")
}
