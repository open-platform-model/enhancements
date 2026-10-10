// Package reconcile compares what repo changes declare with what entries
// record (T2.3 section 4.7). A repo change says "Delivers NNNN, task X.Y."
// in its proposal.md; the entry's tasks.md ticks the line and names the
// change. It flags three cases:
//
//   - unticked: an archived change declares a task whose line is not ticked;
//   - missing-change: a tick names a change that its repo does not have;
//   - unknown-task: a Delivers line names an entry or a task that does not
//     exist.
//
// It needs sibling checkouts, so it is a local check, not a PR gate.
package reconcile

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// EntryRepos is the closed list of repo names an entry may use. It is a copy
// of #EntryRepo in schema.cue; a test keeps the two equal.
var EntryRepos = []string{
	"core", "library", "catalog_opm", "cli", "opm-operator",
	"opm-portal", "opm", "opmodel.dev", "docs-kit", "enhancements",
	"modules", "opm-suite-installer", ".github",
}

// Kinds of flag.
const (
	KindUnticked      = "unticked"
	KindMissingChange = "missing-change"
	KindUnknownTask   = "unknown-task"
)

// Repo is a checkout of a repo that may hold repo changes. Name is a member
// of EntryRepos (the real repo name, "catalog_opm" and not "catalog").
type Repo struct {
	Name string
	Root string
}

// Flag is one finding.
type Flag struct {
	Kind    string
	Path    string
	Line    int
	Message string
}

func (f Flag) String() string {
	return fmt.Sprintf("%s:%d: %s: %s", f.Path, f.Line, f.Kind, f.Message)
}

// Report is the outcome of Run.
type Report struct {
	Flags []Flag
	// InFlight lists the declarations of changes that are not archived. A
	// tick is not owed yet, so they are not flagged.
	InFlight []Declaration
	// Declarations counts every Delivers line found.
	Declarations int
	// Scanned names the repos that had an OpenSpec workspace.
	Scanned []string
	// Skipped names the repos without openspec/changes, with the reason.
	Skipped []string
}

type entry struct {
	id    string
	dir   string // relative to the enhancements root
	tasks []Task
	has   bool // tasks.md exists
}

var (
	liveEntryRe     = regexp.MustCompile(`^(\d{4})-`)
	archivedEntryRe = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}-(\d{4})-`)
	datePrefixRe    = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}-`)
)

func isMember(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

// SiblingRepos returns the repos of EntryRepos that have a checkout directly
// under workspace, and the names without one. The enhancements repo is left
// out: its changes are the entries themselves.
func SiblingRepos(workspace string) (repos []Repo, missing []string) {
	for _, n := range EntryRepos {
		if n == "enhancements" {
			continue
		}
		p := filepath.Join(workspace, n)
		if info, err := os.Stat(p); err == nil && info.IsDir() {
			repos = append(repos, Repo{Name: n, Root: p})
		} else {
			missing = append(missing, n)
		}
	}
	return repos, missing
}

// loadEntries reads the tasks.md of every new-layout entry, live and archived.
func loadEntries(root string) (map[string]*entry, error) {
	out := map[string]*entry{}
	scan := func(parent string, re *regexp.Regexp, skipArchive bool) error {
		ents, err := os.ReadDir(filepath.Join(root, filepath.FromSlash(parent)))
		if errors.Is(err, fs.ErrNotExist) {
			return nil
		}
		if err != nil {
			return err
		}
		for _, e := range ents {
			if !e.IsDir() || (skipArchive && e.Name() == "archive") {
				continue
			}
			m := re.FindStringSubmatch(e.Name())
			if m == nil {
				continue
			}
			rel := parent + "/" + e.Name()
			if prev, dup := out[m[1]]; dup {
				return fmt.Errorf("reconcile: entry %s exists twice: %s and %s", m[1], prev.dir, rel)
			}
			en := &entry{id: m[1], dir: rel}
			src, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(rel), "tasks.md"))
			if err == nil {
				en.has = true
				en.tasks = ParseTasks(string(src))
			} else if !errors.Is(err, fs.ErrNotExist) {
				return err
			}
			out[m[1]] = en
		}
		return nil
	}
	if err := scan("openspec/changes", liveEntryRe, true); err != nil {
		return nil, err
	}
	if err := scan("openspec/changes/archive", archivedEntryRe, false); err != nil {
		return nil, err
	}
	return out, nil
}

// changes lists the change folders of a repo: name (no date) to archived.
func changes(root string) (map[string]bool, bool, error) {
	base := filepath.Join(root, "openspec", "changes")
	live, err := os.ReadDir(base)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	out := map[string]bool{}
	for _, e := range live {
		if e.IsDir() && e.Name() != "archive" {
			out[e.Name()] = false
		}
	}
	arch, err := os.ReadDir(filepath.Join(base, "archive"))
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, false, err
	}
	for _, e := range arch {
		if e.IsDir() {
			out[datePrefixRe.ReplaceAllString(e.Name(), "")] = true
		}
	}
	return out, true, nil
}

// Run reconciles the repo changes of repos with the entries under enhRoot.
func Run(enhRoot string, repos []Repo) (Report, error) {
	var rep Report
	seen := map[string]bool{}
	for _, r := range repos {
		if !isMember(EntryRepos, r.Name) {
			return rep, fmt.Errorf("reconcile: %q is not a repo name of the closed list (use the real name, for example catalog_opm)", r.Name)
		}
		if seen[r.Name] {
			return rep, fmt.Errorf("reconcile: repo %q is listed twice", r.Name)
		}
		seen[r.Name] = true
	}
	entries, err := loadEntries(enhRoot)
	if err != nil {
		return rep, err
	}

	// Per repo: its changes, and its declarations.
	repoChanges := map[string]map[string]bool{}
	var decls []Declaration
	for _, r := range repos {
		ch, ok, err := changes(r.Root)
		if err != nil {
			return rep, err
		}
		if !ok {
			rep.Skipped = append(rep.Skipped, r.Name+": no openspec/changes")
			continue
		}
		rep.Scanned = append(rep.Scanned, r.Name)
		repoChanges[r.Name] = ch
		for name, archived := range ch {
			dir := filepath.Join(r.Root, "openspec", "changes", name)
			rel := "openspec/changes/" + name
			if archived {
				dir, rel = archiveFolder(r.Root, name)
			}
			src, err := os.ReadFile(filepath.Join(dir, "proposal.md"))
			if errors.Is(err, fs.ErrNotExist) {
				continue
			}
			if err != nil {
				return rep, err
			}
			for _, d := range ParseDeclarations(string(src)) {
				d.Repo, d.Change, d.Archived = r.Name, name, archived
				d.Path = r.Name + "/" + rel + "/proposal.md"
				decls = append(decls, d)
			}
		}
	}
	sort.SliceStable(decls, func(i, j int) bool {
		if decls[i].Path != decls[j].Path {
			return decls[i].Path < decls[j].Path
		}
		return decls[i].Line < decls[j].Line
	})
	rep.Declarations = len(decls)

	// Declarations against the entries: cases 1 and 3.
	for _, d := range decls {
		en, ok := entries[d.Entry]
		if !ok || !en.has {
			why := "no entry " + d.Entry + " exists"
			if ok {
				why = "entry " + d.Entry + " has no tasks.md"
			}
			rep.Flags = append(rep.Flags, Flag{KindUnknownTask, d.Path, d.Line,
				fmt.Sprintf("change %s declares \"Delivers %s, task %s\", but %s", d.Change, d.Entry, d.Task, why)})
			continue
		}
		var task *Task
		for i := range en.tasks {
			if en.tasks[i].ID == d.Task {
				task = &en.tasks[i]
				break
			}
		}
		if task == nil {
			rep.Flags = append(rep.Flags, Flag{KindUnknownTask, d.Path, d.Line,
				fmt.Sprintf("change %s declares \"Delivers %s, task %s\", but %s/tasks.md has no task %s", d.Change, d.Entry, d.Task, en.dir, d.Task)})
			continue
		}
		if !d.Archived {
			rep.InFlight = append(rep.InFlight, d)
			continue
		}
		if !task.Done {
			rep.Flags = append(rep.Flags, Flag{KindUnticked, en.dir + "/tasks.md", task.Line,
				fmt.Sprintf("task %s is not ticked, but the archived change %s/%s declares it: tick it and append (%s)", d.Task, d.Repo, d.Change, d.Change)})
		}
	}

	// Ticks against the repos: case 2.
	ids := make([]string, 0, len(entries))
	for id := range entries {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		en := entries[id]
		for _, t := range en.tasks {
			ch, scanned := repoChanges[t.Repo]
			if !scanned {
				continue
			}
			for _, ref := range t.Refs {
				if _, ok := ch[ref]; !ok {
					rep.Flags = append(rep.Flags, Flag{KindMissingChange, en.dir + "/tasks.md", t.Line,
						fmt.Sprintf("task %s is ticked with change %q, but %s has no such change", t.ID, ref, t.Repo)})
				}
			}
		}
	}

	sort.SliceStable(rep.Flags, func(i, j int) bool {
		if rep.Flags[i].Path != rep.Flags[j].Path {
			return rep.Flags[i].Path < rep.Flags[j].Path
		}
		return rep.Flags[i].Line < rep.Flags[j].Line
	})
	return rep, nil
}

// archiveFolder finds the dated folder of an archived change.
func archiveFolder(root, name string) (abs, rel string) {
	base := filepath.Join(root, "openspec", "changes", "archive")
	ents, _ := os.ReadDir(base)
	for _, e := range ents {
		if e.IsDir() && datePrefixRe.ReplaceAllString(e.Name(), "") == name {
			return filepath.Join(base, e.Name()), "openspec/changes/archive/" + e.Name()
		}
	}
	return filepath.Join(base, name), "openspec/changes/archive/" + name
}

// Summary renders the counts as one line.
func (r Report) Summary() string {
	n := map[string]int{}
	for _, f := range r.Flags {
		n[f.Kind]++
	}
	return fmt.Sprintf("reconcile: %d declarations in %s; %d unticked, %d missing-change, %d unknown-task, %d in flight",
		r.Declarations, strings.Join(r.Scanned, ", "), n[KindUnticked], n[KindMissingChange], n[KindUnknownTask], len(r.InFlight))
}
