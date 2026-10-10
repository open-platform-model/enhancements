// Package tasks holds the writing tasks of enh (design part two, section 3):
// new, seed:new, accept, resample, deliver, reject, withdraw, supersede and
// tick, and the read-only list, show and questions. Each task checks, prints,
// or writes one record; none edits what a human must decide.
package tasks

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/record"
	"github.com/open-platform-model/enhancements/tools/enh/internal/sys"
	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
)

// Env is everything a task needs. The zero value of every field but Root, Run,
// Out and Err has a default.
type Env struct {
	// Root is the checkout of the enhancements repo.
	Root string
	// Schema is the path of schema.cue; default <Root>/schema.cue.
	Schema string
	// Base is the main branch the accept PR starts from; default "main".
	Base string
	// Run runs git and openspec.
	Run      sys.Runner
	Out, Err io.Writer
	// Now is the clock; default time.Now.
	Now func() time.Time
	// Confirm turns the plain run of accept and resample into the write.
	Confirm bool
	// NoCommit leaves the result of deliver, reject, withdraw and supersede
	// in the working tree instead of committing it.
	NoCommit bool
	// NoValidate passes --no-validate to the archive of reject, withdraw and
	// supersede: for a draft that never validated.
	NoValidate bool
	// Seed fixes the random seed of the sample draw; nil draws a new one.
	Seed *uint64
	// Authors are the authors written by new; default the git user.email.
	Authors []string
	// ID asks new for a given id instead of the lowest free one.
	ID string
}

// Refusal is a task that refused to act on the state it found: the design's
// "Refuses" column. The message says why. It maps to exit code 1.
type Refusal struct{ Msg string }

func (r *Refusal) Error() string { return r.Msg }

// UsageError is a wrong argument or a missing thing the caller named. It maps
// to exit code 2.
type UsageError struct{ Msg string }

func (u *UsageError) Error() string { return u.Msg }

func refuse(format string, args ...any) error { return &Refusal{fmt.Sprintf(format, args...)} }
func usage(format string, args ...any) error  { return &UsageError{fmt.Sprintf(format, args...)} }

// IsRefusal reports whether err is a Refusal.
func IsRefusal(err error) bool { var r *Refusal; return errors.As(err, &r) }

// IsUsage reports whether err is a UsageError.
func IsUsage(err error) bool { var u *UsageError; return errors.As(err, &u) }

func (e *Env) git() sys.Git { return sys.Git{Root: e.Root, Run: e.Run} }

func (e *Env) base() string {
	if e.Base == "" {
		return "main"
	}
	return e.Base
}

func (e *Env) schemaPath() string {
	if e.Schema != "" {
		return e.Schema
	}
	return filepath.Join(e.Root, "schema.cue")
}

func (e *Env) today() string {
	now := time.Now
	if e.Now != nil {
		now = e.Now
	}
	return now().UTC().Format("2006-01-02")
}

func (e *Env) printf(format string, args ...any) { fmt.Fprintf(e.Out, format, args...) }

func (e *Env) load() (*entry.Store, error) {
	st, err := entry.LoadStore(e.Root)
	if err != nil {
		return nil, err
	}
	return st, nil
}

// live finds the live entry or seed that key names: an id, a folder name, or
// seed-<capability>.
func live(st *entry.Store, key string) (*entry.Entry, error) {
	key = strings.TrimSuffix(strings.TrimSpace(key), "/")
	if key == "" {
		return nil, usage("no entry named: give an id such as 0013, a folder name, or seed-<capability>")
	}
	for _, en := range st.Live {
		if en.Base == key || en.Folder == key || (en.Kind == entry.Enhancement && en.FolderID == key) {
			return en, nil
		}
	}
	if en := st.Find(key); en != nil {
		return nil, refuse("%s is archived; an archived entry is never edited", en.Folder)
	}
	return nil, usage("no live entry or seed %q in openspec/changes/", key)
}

func (e *Env) rel(en *entry.Entry) string {
	r, err := filepath.Rel(e.Root, en.Dir)
	if err != nil {
		return en.Dir
	}
	return filepath.ToSlash(r)
}

// editConfig applies the edits to the entry's config.yaml and returns a func
// that puts the old text back.
func (e *Env) editConfig(en *entry.Entry, edits ...record.Edit) (undo func() error, err error) {
	path := filepath.Join(en.Dir, "config.yaml")
	old, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	out, err := record.SetKeys(string(old), edits...)
	if err != nil {
		return nil, fmt.Errorf("%s: %w", e.rel(en)+"/config.yaml", err)
	}
	if err := record.WriteFile(path, []byte(out)); err != nil {
		return nil, err
	}
	return func() error { return record.WriteFile(path, old) }, nil
}

// vet runs the checker for one entry.
func (e *Env) vet(mode vet.Mode, keys ...string) (*vet.Result, error) {
	return vet.Run(vet.Options{
		Root: e.Root, Mode: mode, Keys: keys, Today: e.today(),
		SchemaPath: e.schemaPath(), OpenSpec: vet.Runner(e.Run),
		Final: os.Getenv("ENH_FINAL") == "1",
	})
}

// printFindings writes the findings of a result and a summary line, and
// reports whether there was an error.
func (e *Env) printFindings(mode vet.Mode, res *vet.Result, extra ...vet.Finding) bool {
	all := append(append([]vet.Finding{}, res.Findings...), extra...)
	errs, warns := 0, 0
	for _, f := range all {
		fmt.Fprintln(e.Out, f.String())
		if f.Level == vet.Error {
			errs++
		} else {
			warns++
		}
	}
	for _, s := range res.Skipped {
		fmt.Fprintf(e.Out, "skipped %s\n", s)
	}
	fmt.Fprintf(e.Out, "vet (%s mode): %d errors, %d warnings\n", mode, errs, warns)
	return errs > 0
}

// markerPath is the file that records a plain run of accept or resample. It
// sits in the git directory, so it is never tracked and it is private to a
// worktree.
func (e *Env) markerPath(kind string, en *entry.Entry) (string, error) {
	return e.git().Dir("enh/" + kind + "-" + en.Folder)
}

func (e *Env) writeMarker(kind string, en *entry.Entry, commit string, seed *uint64) error {
	p, err := e.markerPath(kind, en)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	line := commit
	if seed != nil {
		line += fmt.Sprintf(" %d", *seed)
	}
	return record.WriteFile(p, []byte(line+"\n"))
}

// needMarker refuses CONFIRM unless a plain run happened on the same commit.
func (e *Env) needMarker(kind string, en *entry.Entry, commit string) error {
	p, err := e.markerPath(kind, en)
	if err != nil {
		return err
	}
	b, err := os.ReadFile(p)
	if err != nil {
		return refuse("CONFIRM before a plain run: run `enh %s %s` first, read the output, then confirm", kind, en.Base)
	}
	f := strings.Fields(string(b))
	if len(f) == 0 || f[0] != commit {
		return refuse("the plain run of `enh %s %s` was on commit %s, not %s: run it again before CONFIRM", kind, en.Base, strings.Join(f[:min(1, len(f))], ""), commit)
	}
	return nil
}

// existing keeps the paths that exist under the root, so git add never gets a
// pathspec that matches nothing.
func (e *Env) existing(paths ...string) []string {
	var out []string
	for _, p := range paths {
		if _, err := os.Stat(filepath.Join(e.Root, filepath.FromSlash(p))); err == nil {
			out = append(out, p)
		}
	}
	return out
}
