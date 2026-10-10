// Package vet is the checker behind `enh vet`. It runs the V rules of the
// design (T2.3 section 2) on the entries of one checkout. A rule is a method
// on a run context; a finding names its rule, its level, the file and the line.
//
// Rules that need git history are not here: V7 ancestry of the accepted
// commit, V26 stale base, V27 edit after accept, and V31 closed folders. They
// belong to the tasks that read history (T3.3).
package vet

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/open-platform-model/enhancements/tools/enh/internal/cueschema"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
)

// Level is the severity of a finding.
type Level string

// The two levels. An error fails the run; a warning only prints.
const (
	Error   Level = "error"
	Warning Level = "warning"
)

// Mode is how strict a run is. The modes are ordered: a later mode adds
// errors and never removes one.
type Mode int

// The modes of T2.3 section 2.
const (
	Draft Mode = iota
	Accept
	Deliver
)

// ParseMode reads a mode name.
func ParseMode(s string) (Mode, error) {
	switch s {
	case "draft", "":
		return Draft, nil
	case "accept":
		return Accept, nil
	case "deliver":
		return Deliver, nil
	}
	return Draft, fmt.Errorf("unknown mode %q (want draft, accept or deliver)", s)
}

func (m Mode) String() string { return [...]string{"draft", "accept", "deliver"}[m] }

// Finding is one result of one rule.
type Finding struct {
	// Rule is "V1" to "V35".
	Rule  string
	Level Level
	// Entry is the folder name of the entry, empty for a finding about the repo.
	Entry string
	// Path is the file, relative to the root with slashes; Line is 1-based or 0.
	Path string
	Line int
	Msg  string
	// Field is the config.yaml field the finding is about, if any. It lets a
	// schema error be dropped when a rule already reported the field.
	Field string
}

func (f Finding) String() string {
	loc := f.Path
	if loc != "" && f.Line > 0 {
		loc = fmt.Sprintf("%s:%d", loc, f.Line)
	}
	if loc == "" {
		loc = f.Entry
	}
	return fmt.Sprintf("%-7s %-3s %s: %s", f.Level, f.Rule, loc, f.Msg)
}

// Runner runs an external command in dir and returns its combined output.
type Runner func(dir, name string, args ...string) ([]byte, error)

// Options configures one run. The zero value of every field but Root is usable.
type Options struct {
	// Root is the checkout to read.
	Root string
	// Mode is the strictness; an accepted entry is always checked at least at
	// Accept.
	Mode Mode
	// Keys limits the run to entries whose id or folder name is listed. Empty
	// means every live and archived entry.
	Keys []string
	// Today is "YYYY-MM-DD" and bounds the created date; empty means today in UTC.
	Today string
	// SchemaPath defaults to <Root>/schema.cue.
	SchemaPath string
	// OpenSpec, when non-nil, enables V32 and V35: it runs the openspec CLI.
	// A nil value skips both rules and the result says so.
	OpenSpec Runner
	// Strict adds `openspec validate --strict` runs (V35).
	Strict bool
	// Final makes V30 an error: the migration is over (ENH_FINAL=1).
	Final bool
	// GitShow reads a file at a commit for V25. The default runs `git show`.
	GitShow func(root, commit, path string) ([]byte, error)
}

// Result is the outcome of a run.
type Result struct {
	Findings []Finding
	// Checked lists the folder names of the entries that were read.
	Checked []string
	// Skipped lists rules that did not run, with the reason.
	Skipped []string
}

// Errors counts the findings of level error.
func (r *Result) Errors() int { return r.count(Error) }

// Warnings counts the findings of level warning.
func (r *Result) Warnings() int { return r.count(Warning) }

// HasErrors reports whether any finding is an error.
func (r *Result) HasErrors() bool { return r.Errors() > 0 }

func (r *Result) count(l Level) int {
	n := 0
	for _, f := range r.Findings {
		if f.Level == l {
			n++
		}
	}
	return n
}

// Format writes the findings and a summary line.
func (r *Result) Format(w io.Writer) {
	for _, f := range r.Findings {
		fmt.Fprintln(w, f.String())
	}
	for _, s := range r.Skipped {
		fmt.Fprintf(w, "skipped %s\n", s)
	}
	fmt.Fprintf(w, "enh vet: %d errors, %d warnings in %d entries\n", r.Errors(), r.Warnings(), len(r.Checked))
}

// run is the state of one Run.
type run struct {
	opts   Options
	store  *entry.Store
	schema *cueschema.Schema
	today  string
	res    *Result
}

// ent is an entry plus the per-entry state of a run.
type ent struct {
	*entry.Entry
	mode Mode
	rel  string // folder path relative to the root, slash form
	// reported holds the config fields that a rule already reported.
	reported map[string]bool
}

// Run checks the entries of opts.Root.
func Run(opts Options) (*Result, error) {
	if opts.Root == "" {
		return nil, fmt.Errorf("vet: no root")
	}
	if fi, err := os.Stat(filepath.Join(opts.Root, "openspec")); err != nil || !fi.IsDir() {
		return nil, fmt.Errorf("vet: %s has no openspec/ folder", opts.Root)
	}
	st, err := entry.LoadStore(opts.Root)
	if err != nil {
		return nil, err
	}
	if opts.SchemaPath == "" {
		opts.SchemaPath = filepath.Join(st.Root, "schema.cue")
	}
	sch, err := cueschema.Load(opts.SchemaPath)
	if err != nil {
		return nil, err
	}
	if opts.Today == "" {
		opts.Today = time.Now().UTC().Format("2006-01-02")
	}
	if opts.GitShow == nil {
		opts.GitShow = gitShow
	}
	r := &run{opts: opts, store: st, schema: sch, today: opts.Today, res: &Result{}}
	if opts.OpenSpec == nil {
		r.res.Skipped = append(r.res.Skipped, "V32 V35: no openspec runner (pass --openspec)")
	}
	r.repoRules()
	for _, e := range st.All() {
		if !r.selected(e) {
			continue
		}
		r.res.Checked = append(r.res.Checked, e.Folder)
		r.entry(e)
	}
	if opts.OpenSpec != nil && opts.Strict && len(r.opts.Keys) == 0 {
		r.validateSpecsStrict()
	}
	sort.SliceStable(r.res.Findings, func(i, j int) bool {
		a, b := r.res.Findings[i], r.res.Findings[j]
		if a.Entry != b.Entry {
			return a.Entry < b.Entry
		}
		if a.Path != b.Path {
			return a.Path < b.Path
		}
		return a.Line < b.Line
	})
	return r.res, nil
}

func (r *run) selected(e *entry.Entry) bool {
	if len(r.opts.Keys) == 0 {
		return true
	}
	for _, k := range r.opts.Keys {
		if k == e.Base || k == e.Folder || (e.FolderID != "" && k == e.FolderID) {
			return true
		}
	}
	return false
}

func gitShow(root, commit, path string) ([]byte, error) {
	out, err := exec.Command("git", "-C", root, "show", commit+":"+path).Output()
	if err != nil {
		return nil, fmt.Errorf("git show %s:%s: %w", commit, path, err)
	}
	return out, nil
}

// ExecRunner runs a command with the telemetry of the OpenSpec CLI off.
func ExecRunner(dir, name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "OPENSPEC_TELEMETRY=0", "NO_COLOR=1")
	return cmd.CombinedOutput()
}

// add records a finding. A level of "" means the rule is silent in this mode.
func (r *run) add(e *ent, rule string, lv Level, path string, line int, format string, args ...any) {
	if lv == "" {
		return
	}
	f := Finding{Rule: rule, Level: lv, Path: path, Line: line, Msg: fmt.Sprintf(format, args...)}
	if e != nil {
		f.Entry = e.Folder
		if path == "" {
			f.Path = e.rel
		}
	}
	r.res.Findings = append(r.res.Findings, f)
}

// addField is add for a config.yaml field.
func (r *run) addField(e *ent, rule string, lv Level, field, format string, args ...any) {
	if lv == "" {
		return
	}
	if e.reported == nil {
		e.reported = map[string]bool{}
	}
	e.reported[field] = true
	r.add(e, rule, lv, e.rel+"/config.yaml", 0, format, args...)
	r.res.Findings[len(r.res.Findings)-1].Field = field
}

// by returns lv when the entry's mode is at least m, else "".
func (e *ent) from(m Mode, lv Level) Level {
	if e.mode >= m {
		return lv
	}
	return ""
}

// modeLevel returns the level for a rule that is a warning below m and an
// error from m on.
func (e *ent) warnThenError(m Mode) Level {
	if e.mode >= m {
		return Error
	}
	return Warning
}

func (r *run) entry(raw *entry.Entry) {
	e := &ent{Entry: raw, mode: r.opts.Mode}
	e.rel = relSlash(r.store.Root, e.Dir)
	if e.Config.Status == "accepted" && e.mode < Accept {
		e.mode = Accept
	}
	r.configRules(e)
	r.idRules(e)
	r.openspecYamlRules(e)
	if e.Archived {
		// Archived entries get the facts rules only; the prose and delta rules
		// ran while the entry was live (T2.2 section 4, reduced validation).
		return
	}
	r.deltaRules(e)
	r.proposalRules(e)
	r.taskRules(e)
	r.linkRules(e)
	r.evidenceRules(e)
	r.seedRules(e)
	r.mapRules(e)
	r.openspecValidate(e)
}

func relSlash(root, p string) string {
	rel, err := filepath.Rel(root, p)
	if err != nil {
		return filepath.ToSlash(p)
	}
	return filepath.ToSlash(rel)
}

func (e *ent) isSeed() bool { return e.Kind == entry.Seed }

func containsStr(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func trimQ(s string) string { return strings.Trim(strings.TrimSpace(s), `"'`) }
