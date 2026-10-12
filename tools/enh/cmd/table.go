package cmd

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github.com/open-platform-model/enhancements/tools/enh/internal/citelint"
	"github.com/open-platform-model/enhancements/tools/enh/internal/citerewrite"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/links"
	"github.com/open-platform-model/enhancements/tools/enh/internal/reconcile"
	"github.com/open-platform-model/enhancements/tools/enh/internal/specsrule"
	"github.com/open-platform-model/enhancements/tools/enh/internal/tasks"
	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
)

var commands = []command{
	{
		name: "vet", synopsis: "vet [flags] [ID|FOLDER ...]", summary: "check every entry, or the named ones",
		help: "Modes: draft (default), accept and deliver. A later mode adds errors. At deliver mode the stale-base\ncheck (V26) also runs on each accepted entry.\nENH_FINAL=1 makes a remaining legacy folder an error (V30).\nV7, V27 and V31 compare with a base ref and run only when one exists; a CI run passes the base of the pull\nrequest with --base. Without a ref they print a skipped line.\n--cue runs `cue vet ./...` in each evidence module (a folder with cue.mod/module.cue under evidence/); a\nfailure is a V29 warning, never an error. Without --cue the rule prints a skipped line.\n--v35 is the migration closing check (design part two, section 2, V35): it runs only that rule and needs the\nopenspec CLI (1.14.1). It is not part of the daily check.",
		flags: func(fs *flag.FlagSet, o *options) {
			rootFlags(fs, o)
			fs.StringVar(&o.mode, "mode", "draft", "draft, accept or deliver")
			fs.BoolVar(&o.openspec, "openspec", false, "also run the openspec CLI: validate at accept and deliver (V32)")
			fs.BoolVar(&o.strict, "strict", false, "with --openspec, run validate --strict (V35)")
			fs.BoolVar(&o.v35, "v35", false, "run only V35: openspec validate NAME --strict for each live entry and seed, and openspec validate --specs --strict; not part of task check")
			fs.BoolVar(&o.cue, "cue", false, "also run cue vet in each evidence/**/cue.mod module (V29, a warning)")
			fs.StringVar(&o.today, "today", "", "the date that bounds \"created\" (default: today, UTC)")
			fs.StringVar(&o.base, "base", "", "the base ref of the pull request, for V7, V27 and V31 (default: origin/main when it exists, else main)")
		},
		min: 0, max: -1, run: runVet,
	},
	{
		name: "new", synopsis: "new [flags] SLUG TITLE SUMMARY CATEGORY AFFECTS", summary: "allocate an id and make a draft entry",
		help: "Takes the lowest free id, runs `openspec new change <id>-<slug> --schema enhancement`, writes config.yaml\nand runs index. AFFECTS is a comma-separated list of repos, for example core,cli.\nCATEGORY is schema, runtime, distribution, tooling or misc.",
		flags: func(fs *flag.FlagSet, o *options) {
			rootFlags(fs, o)
			fs.StringVar(&o.id, "id", "", "ask for this id; refused when it is used, reserved or blocked")
			fs.StringVar(&o.author, "author", "", "comma-separated authors (default: git user.email)")
		},
		min: 5, max: 5, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error {
				_, err := e.New(tasks.NewArgs{Slug: c.args[0], Title: c.args[1], Summary: c.args[2], Category: c.args[3], Affects: splitList(c.args[4])})
				return err
			})
		},
	},
	{
		name: "seed:new", synopsis: "seed:new [flags] CAP", summary: "make the seed change seed-CAP",
		help:  "Refuses a capability that already exists in openspec/specs/.",
		flags: rootFlags, min: 1, max: 1, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.SeedNew(c.args[0]) })
		},
	},
	{
		name: "accept", synopsis: "accept [flags] ID", summary: "check a draft in accept mode and print the sample and the collision list",
		help:  "A plain run prints the sample (every MODIFIED and REMOVED requirement, and max(3, 10 percent) of the ADDED\nones drawn at random with the seed printed), the collision list, and the blocking questions. A refused run\nstill prints the sample and the list under \"refused: fix the errors first\".\nCONFIRM=1 (or --confirm) then writes status: accepted and accepted:, and runs index. It refuses before a\nplain run, and after one when HEAD or the files of the entry folder changed since.\nID=seed-CAP: the sample of all ADDED requirements; CONFIRM writes only the sampled: line of source.md.",
		flags: confirmFlags, min: 1, max: 1, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Accept(c.args[0]) })
		},
	},
	{
		name: "resample", synopsis: "resample [flags] ID", summary: "print stale flags and edited requirements of an accepted entry",
		help: "A plain run prints each stale-base flag with both texts, then every requirement that differs from the entry\ntext on the main commit that last wrote accepted:, each with its 3 nearest requirements. It never refuses on\na flag. CONFIRM=1 (or --confirm) rewrites accepted:, which is the reconciliation.",
		flags: func(fs *flag.FlagSet, o *options) {
			gitFlags(fs, o)
			fs.BoolVar(&o.confirm, "confirm", false, "rewrite accepted: (the same as CONFIRM=1); needs a plain run on the same commit first")
		}, min: 1, max: 1, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Resample(c.args[0]) })
		},
	},
	{
		name: "deliver", synopsis: "deliver [flags] ID", summary: "check, set status: delivered, archive, index and commit",
		help: "Refuses an unticked task line, a stale flag, and any error of the checker at deliver mode (V20, V21 and the\nrest). Runs `openspec archive <n> --yes`, then index, then makes one commit. ID=seed-CAP skips the entry\nfields and needs the sampled: line. Needs a clean working tree unless --no-commit.",
		flags: func(fs *flag.FlagSet, o *options) {
			gitFlags(fs, o)
			fs.BoolVar(&o.noCommit, "no-commit", false, "leave the change in the working tree instead of making the commit")
		},
		min: 1, max: 1, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Deliver(c.args[0]) })
		},
	},
	{
		name: "reject", synopsis: "reject [flags] ID REASON", summary: "reject a draft: write the record and archive with --skip-specs",
		flags: endFlags, min: 2, max: 2, run: endRun(tasks.Reject),
	},
	{
		name: "withdraw", synopsis: "withdraw [flags] ID REASON", summary: "withdraw a draft or accepted entry: write the record and archive with --skip-specs",
		flags: endFlags, min: 2, max: 2, run: endRun(tasks.Withdraw),
	},
	{
		name: "supersede", synopsis: "supersede [flags] ID BY REASON", summary: "supersede an entry by one or more others (BY is a comma-separated list of ids)",
		flags: endFlags, min: 3, max: 3, run: endRun(tasks.Supersede),
	},
	{
		name: "tick", synopsis: "tick [flags] ID LINE REF", summary: "tick the task line n.m of tasks.md and append (REF)",
		help:  "REF is the change name without date, \"PR <n>\" for a repo with no OpenSpec change, or \"commit <sha>\"\nfor the commit that delivers the line (a hexadecimal sha of 7 to 40 characters).",
		flags: rootFlags, min: 3, max: 3, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Tick(c.args[0], c.args[1], c.args[2]) })
		},
	},
	{
		name: "index", synopsis: "index [flags]", summary: "write README.md of every new-layout entry, INDEX.md and GRAPH.md",
		flags: rootFlags, min: 0, max: 0, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.RunIndex() })
		},
	},
	{
		name: "fresh", synopsis: "fresh [flags]", summary: "fail when a generated file is missing or stale",
		flags: rootFlags, min: 0, max: 0, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Fresh() })
		},
	},
	{
		name: "history", synopsis: "history [flags] REQ [CAP]", summary: "print the history of a requirement from the archived deltas",
		help:  "Follows RENAMED pairs and a REMOVED whose Migration reads `Replaced by \"<name>\"`, both ways. Skips\nrejected, withdrawn and superseded entries. Seeds appear as origin rows.",
		flags: rootFlags, min: 1, max: 2, run: func(c *call) int {
			capability := ""
			if len(c.args) == 2 {
				capability = c.args[1]
			}
			return c.withEnv(func(e *tasks.Env) error { return e.History(c.args[0], capability) })
		},
	},
	{
		name: "stale", synopsis: "stale [flags] ID", summary: "print the stale-base flags of an accepted entry",
		flags: rootFlags, min: 1, max: 1, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Stale(c.args[0]) })
		},
	},
	{
		name: "links", synopsis: "links [flags]", summary: "check the links between entries and the generated files",
		flags: rootFlags, min: 0, max: 0, run: runLinks,
	},
	{
		name: "reconcile", synopsis: "reconcile [flags]", summary: "compare Delivers lines of the repos with the ticks of tasks.md",
		help: "Needs sibling checkouts. The workspace is the folder that holds them (default: the parent of the root).",
		flags: func(fs *flag.FlagSet, o *options) {
			rootFlags(fs, o)
			fs.StringVar(&o.workspace, "workspace", "", "the folder that holds the repo checkouts")
		},
		min: 0, max: 0, run: runReconcile,
	},
	{
		name: "cite-lint", synopsis: "cite-lint [flags] [PATH ...]", summary: "fail on a decision number, a lone id or an old entry path in Go and CUE comments",
		help: "Lints Go and CUE files under the paths (default: the root). Run it from any repo.\nA walk skips CHANGELOG.md, vendor/, agent-swarm/, .claude/ and the CUE caches; a path named on the\ncommand line (a file, or a folder such as .claude/skills) is linted. A path to an entry file of the old\nlayout (enhancements/archive/0010/03-decisions.md, 0010/README.md) fails the rule old-path.",
		flags: func(fs *flag.FlagSet, o *options) {
			fs.StringVar(&o.root, "root", "", "the repo to lint (default: the current directory)")
			fs.StringVar(&o.filesFrom, "files-from", "", "read the paths from this file, newline or NUL separated; - is standard input")
			fs.Var(&o.exclude, "exclude", "skip a path pattern; repeat the flag for more")
		},
		min: 0, max: -1, run: runCiteLint,
	},
	{
		name: "cite-rewrite", synopsis: "cite-rewrite [flags] [PATH ...]", summary: "rewrite the decision citations of a repo; list what an agent must rewrite",
		help: citeRewriteHelp,
		flags: func(fs *flag.FlagSet, o *options) {
			fs.StringVar(&o.root, "root", "", "the repo to rewrite (default: the current directory)")
			fs.StringVar(&o.filesFrom, "files-from", "", "read the paths from this file, newline or NUL separated; - is standard input")
			fs.Var(&o.exclude, "exclude", "skip a path pattern; repeat the flag for more")
			fs.BoolVar(&o.write, "write", false, "apply the rewrites (default: a dry run that changes nothing)")
			fs.BoolVar(&o.dryRun, "dry-run", false, "change nothing and print the summary (the default; the flag only says so)")
			fs.StringVar(&o.generated, "generated", "", "comma-separated files or folders that are generated: their citations are only listed, as kind generated")
			fs.StringVar(&o.worklist, "worklist", "", "write the sites an agent must rewrite to this file, one row per site")
		},
		min: 0, max: -1, run: runCiteRewrite,
	},
	{
		name: "specs-rule", synopsis: "specs-rule [flags]", summary: "check that a change to openspec/specs/ is one delivery, one seed or a Purpose correction",
		help: "Steps (design part two, section 4.3): list the changes under openspec/specs/ between the merge base of BASE and\nHEAD; pass when there are none, or when they change ## Purpose text only; else require exactly one folder added\nunder openspec/changes/archive/ whose undated folder was in changes/ at the base and is gone at head, with\nstatus delivered or schema seed; replay `openspec archive <name> --yes` (the pinned version, 1.14.1) on the base\ntree in a scratch copy; fail on any byte of difference in openspec/specs/. Needs the full history.",
		flags: func(fs *flag.FlagSet, o *options) {
			rootFlags(fs, o)
			fs.StringVar(&o.base, "base", "", "the base ref of the pull request (an all-zero id means the parent of HEAD)")
			fs.StringVar(&o.head, "head", "HEAD", "the commit to check")
		},
		min: 0, max: 0, run: runSpecsRule,
	},
	{
		name: "list", synopsis: "list [flags]", summary: "list the live entries and seeds, or the archived ones",
		flags: func(fs *flag.FlagSet, o *options) {
			rootFlags(fs, o)
			fs.BoolVar(&o.archived, "archived", false, "list the archived entries")
		},
		min: 0, max: 0, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.List(c.o.archived) })
		},
	},
	{
		name: "show", synopsis: "show [flags] ID", summary: "print the facts of one entry",
		flags: rootFlags, min: 1, max: 1, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Show(c.args[0]) })
		},
	},
	{
		name: "questions", synopsis: "questions [flags] ID", summary: "print the open questions of an entry",
		flags: rootFlags, min: 1, max: 1, run: func(c *call) int {
			return c.withEnv(func(e *tasks.Env) error { return e.Questions(c.args[0]) })
		},
	},
}

func endRun(kind string) func(c *call) int {
	return func(c *call) int {
		return c.withEnv(func(e *tasks.Env) error {
			if kind == tasks.Supersede {
				return e.End(kind, c.args[0], c.args[2], splitList(c.args[1]))
			}
			return e.End(kind, c.args[0], c.args[1], nil)
		})
	}
}

func runVet(c *call) int {
	m, err := vet.ParseMode(c.o.mode)
	if err != nil {
		fmt.Fprintf(c.errOut, "enh vet: %v\n", err)
		return ExitUsage
	}
	if c.o.v35 && (c.o.strict || c.o.openspec || c.o.cue || m != vet.Draft) {
		fmt.Fprintln(c.errOut, "enh vet: --v35 runs V35 alone; it takes no --openspec, --strict, --cue or --mode")
		return ExitUsage
	}
	if c.o.strict && !c.o.openspec {
		fmt.Fprintln(c.errOut, "enh vet: --strict needs --openspec")
		return ExitUsage
	}
	env, err := c.env()
	if err != nil {
		fmt.Fprintf(c.errOut, "enh vet: %v\n", err)
		return ExitUsage
	}
	opts := vet.Options{
		Root: env.Root, Mode: m, Keys: c.args, Today: c.o.today, SchemaPath: c.o.schema,
		Strict: c.o.strict, Final: c.d.Getenv("ENH_FINAL") == "1",
		Base: c.vetBase(env.Root),
	}
	if c.o.openspec || c.o.v35 {
		opts.OpenSpec = vet.Runner(c.d.Runner)
	}
	opts.V35Only = c.o.v35
	if c.o.cue {
		opts.Cue = vet.Runner(c.d.Runner)
	}
	res, err := vet.Run(opts)
	if err != nil {
		fmt.Fprintf(c.errOut, "enh vet: %v\n", err)
		return ExitUsage
	}
	if m == vet.Deliver {
		// V26 reads git history, which the vet package does not.
		st, err := entry.LoadStore(env.Root)
		if err == nil {
			var extra []vet.Finding
			if extra, err = env.StaleFindings(st, c.args); err == nil {
				res.Findings = append(res.Findings, extra...)
				sortFindings(res)
			}
		}
		if err != nil {
			fmt.Fprintf(c.errOut, "enh vet: V26: %v\n", err)
			return ExitUsage
		}
	}
	res.Format(c.out)
	if res.HasErrors() {
		return ExitError
	}
	return ExitOK
}

func sortFindings(r *vet.Result) {
	sort.SliceStable(r.Findings, func(i, j int) bool {
		a, b := r.Findings[i], r.Findings[j]
		if a.Entry != b.Entry {
			return a.Entry < b.Entry
		}
		if a.Path != b.Path {
			return a.Path < b.Path
		}
		return a.Line < b.Line
	})
}

func runLinks(c *call) int {
	env, err := c.env()
	if err != nil {
		fmt.Fprintf(c.errOut, "enh links: %v\n", err)
		return ExitUsage
	}
	res, err := links.Check(env.Root)
	if err != nil {
		fmt.Fprintf(c.errOut, "enh links: %v\n", err)
		return ExitUsage
	}
	for _, f := range res.Findings {
		fmt.Fprintln(c.out, f.String())
	}
	fmt.Fprintf(c.out, "enh links: %d files, %d findings\n", res.Files, len(res.Findings))
	if len(res.Findings) > 0 {
		return ExitError
	}
	return ExitOK
}

func runReconcile(c *call) int {
	env, err := c.env()
	if err != nil {
		fmt.Fprintf(c.errOut, "enh reconcile: %v\n", err)
		return ExitUsage
	}
	ws := c.o.workspace
	if ws == "" {
		ws = filepath.Dir(env.Root)
	}
	repos, missing := reconcile.SiblingRepos(ws)
	rep, err := reconcile.Run(env.Root, repos)
	if err != nil {
		fmt.Fprintf(c.errOut, "enh reconcile: %v\n", err)
		return ExitUsage
	}
	for _, f := range rep.Flags {
		fmt.Fprintln(c.out, f.String())
	}
	for _, s := range rep.Skipped {
		fmt.Fprintf(c.out, "skipped %s\n", s)
	}
	if len(missing) > 0 {
		fmt.Fprintf(c.out, "no checkout under %s for: %v\n", ws, missing)
	}
	fmt.Fprintln(c.out, rep.Summary())
	if len(rep.Flags) > 0 {
		return ExitError
	}
	return ExitOK
}

func runCiteLint(c *call) int {
	root := c.o.root
	if root == "" {
		wd, err := c.d.Cwd()
		if err != nil {
			fmt.Fprintf(c.errOut, "enh cite-lint: %v\n", err)
			return ExitUsage
		}
		root = wd
	}
	paths, err := c.pathArgs("cite-lint")
	if err != nil {
		return ExitUsage
	}
	if len(paths) == 0 {
		paths = []string{"."}
	}
	res, err := citelint.LintFiles(root, paths, citelint.Options{Exclude: c.o.exclude})
	if err != nil {
		fmt.Fprintf(c.errOut, "enh cite-lint: %v\n", err)
		return ExitUsage
	}
	for _, f := range res.Findings {
		fmt.Fprintln(c.out, f.String())
	}
	fmt.Fprintf(c.out, "enh cite-lint: %d files checked, %d skipped, %d findings\n", res.Checked, res.Skipped, len(res.Findings))
	if len(res.Findings) > 0 {
		return ExitError
	}
	return ExitOK
}

func runSpecsRule(c *call) int {
	env, err := c.env()
	if err != nil {
		fmt.Fprintf(c.errOut, "enh specs-rule: %v\n", err)
		return ExitUsage
	}
	opts := specsrule.Options{Root: env.Root, Base: c.o.base, Head: c.o.head, OpenSpec: c.d.Runner}
	res, err := specsrule.Check(opts)
	if err != nil {
		fmt.Fprintf(c.errOut, "enh specs-rule: %v\n", err)
		return ExitUsage
	}
	for _, l := range res.Lines {
		fmt.Fprintln(c.out, l)
	}
	for _, f := range res.Failures {
		fmt.Fprintf(c.out, "FAIL %s\n", f)
	}
	if !res.OK() {
		fmt.Fprintf(c.out, "enh specs-rule: %d failure(s)\n", len(res.Failures))
		return ExitError
	}
	fmt.Fprintln(c.out, "enh specs-rule: pass")
	return ExitOK
}

const citeRewriteHelp = `Rewrites the citations of enhancement decisions in a repo, on the lexer of cite-lint, and
lists the sites that it does not rewrite. Run it from a repo other than this one, in a worktree.

A dry run is the default and changes nothing. --write applies these forms:
  1  Go and CUE comments (also *.cue.tmpl), # comments of YAML and shell files, and a Markdown or
     YAML sentence with a rule keyword (SHALL, MUST, SHOULD, REQUIRED in capitals): (0010:D11)
     becomes (enhancement 0010); several ids become (enhancements 0010 and 0026); a trailing
     ", per 0010:D4." becomes " (enhancement 0010)." A title never goes into a comment or a rule.
  2  Markdown and YAML text: 0010:D11 becomes enhancement 0010 ("<decision title>"). A range or a
     contrast of requirements (R3 to R5, R3, not R4) gives the title once.
  4  enhancements/NNNN paths become enhancement NNNN; the old site slugs of the 17 converted entries
     map to the new pages (decisions to requirements, and so on)
  5  enhancement.yaml files are deleted
The spoken forms (enhancement 0010 D4, (0010 D49), 0011 D3/D15) count as decision numbers.

Everything else is only listed: a lone id or WHY label, an id inside a sentence, NNNN:OQn, string
literals, generated files, code fences, a Markdown heading that holds a citation, a path to a file
inside an entry, a path to a file of the old entry layout (kind path), a title that names a CUE
definition (cue-definition), an id that repeats in its sentence (repeat-id), a rule sentence that
form 1 does not fit (rule-sentence), a citation of 0030 or 0031 (retired-inline: both ids are free for new
entries, so the tool never removes one; a bare 0030 or 0031 is retired-id), a requirement range or contrast
that a line break cuts in two (wrapped). A line edge of a wrapped paragraph counts as a sentence edge only
when the paragraph says so. Titles come from titles.tsv (generated) and short-titles.tsv (by hand); a citation of a
merged or moved decision is written as the decision that took its place. --worklist FILE writes one
tab-separated row per site: path, line, kind, line text, decision title. After --write and an empty
worklist, enh cite-lint passes.

A file is generated, and only listed (kind generated), in these cases: it has Go's exact "Code generated ...
DO NOT EDIT." line near the top (after "//", or after "#" as in the kubebuilder PROJECT file); its name is
zz_generated*, *.pb.go or *_gen.go; it is a YAML or JSON file with a controller-gen annotation; or a path
is named by --generated PATHS (a comma list of files or folders, for example config/crd/bases/,dist/).
Words such as "generated by" or "do not edit" in the text mark nothing.

Skipped always: CHANGELOG.md, vendor/**, agent-swarm/, .claude/worktrees/ and the CUE caches.
A walk also skips folders named .claude; name one on the command line to process it. Pass
--exclude for published fixtures (cli tests/fixtures/**, opm-operator test/fixtures/modules/**) and
for active OpenSpec changes (openspec/changes/*, except archive).
Exit codes: 0 done, 2 usage or a failed run. A worklist does not make the exit code 1.`

func runCiteRewrite(c *call) int {
	root := c.o.root
	if root == "" {
		wd, err := c.d.Cwd()
		if err != nil {
			fmt.Fprintf(c.errOut, "enh cite-rewrite: %v\n", err)
			return ExitUsage
		}
		root = wd
	}
	if c.o.write && c.o.dryRun {
		fmt.Fprintln(c.errOut, "enh cite-rewrite: --write and --dry-run exclude each other")
		return ExitUsage
	}
	paths, err := c.pathArgs("cite-rewrite")
	if err != nil {
		return ExitUsage
	}
	rep, err := citerewrite.Run(citerewrite.Options{Root: root, Paths: paths, Exclude: c.o.exclude, Write: c.o.write, Generated: splitList(c.o.generated)})
	if rep != nil {
		rep.WriteSummary(c.out, c.o.write)
		if c.o.worklist != "" {
			if werr := writeWorklist(c.o.worklist, rep); werr != nil {
				fmt.Fprintf(c.errOut, "enh cite-rewrite: %v\n", werr)
				return ExitUsage
			}
			fmt.Fprintf(c.out, "worklist written to %s\n", c.o.worklist)
		}
	}
	if err != nil {
		fmt.Fprintf(c.errOut, "enh cite-rewrite: %v\n", err)
		return ExitUsage
	}
	return ExitOK
}

func writeWorklist(name string, rep *citerewrite.Report) (err error) {
	f, err := os.Create(name)
	if err != nil {
		return err
	}
	defer func() {
		if cerr := f.Close(); err == nil {
			err = cerr
		}
	}()
	return rep.WriteWorklist(f)
}

// pathArgs returns the positional paths plus the paths of --files-from. On an
// error it has printed the message.
func (c *call) pathArgs(name string) ([]string, error) {
	paths := c.args
	if c.o.filesFrom == "" {
		return paths, nil
	}
	r := c.d.Stdin
	if c.o.filesFrom != "-" {
		f, err := os.Open(c.o.filesFrom)
		if err != nil {
			fmt.Fprintf(c.errOut, "enh %s: %v\n", name, err)
			return nil, err
		}
		defer f.Close() // read-only
		r = f
	}
	list, err := citelint.ReadFileList(r)
	if err != nil {
		fmt.Fprintf(c.errOut, "enh %s: %v\n", name, err)
		return nil, err
	}
	return append(paths, list...), nil
}
