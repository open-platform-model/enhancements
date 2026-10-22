// Package entry reads the entry folders of the enhancements repository: the
// live changes in openspec/changes, the archived ones under
// openspec/changes/archive, the old-layout archive/NNNN folders, and the main
// specs in openspec/specs. Reading is lenient: a missing or malformed file is
// recorded on the Entry for the checker to report, and only a failure to read
// the disk is an error.
package entry

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
)

// Kind tells an enhancement from a seed change or a correction.
type Kind int

// The kinds of change folder.
const (
	Enhancement Kind = iota
	Seed
	Correction
)

// The folder prefixes of the two unnumbered kinds. Every package that
// recognises these folders builds its pattern from them.
const (
	SeedPrefix       = "seed-"
	CorrectionPrefix = "correction-"
)

// Unnumbered reports whether the kind has no id, no config.yaml, no proposal
// and no design: a seed or a correction.
func (k Kind) Unnumbered() bool { return k == Seed || k == Correction }

// UnnumberedNamePattern matches the start of an unnumbered folder name,
// with the optional archive date in front.
const UnnumberedNamePattern = `^(?:[0-9]{4}-[0-9]{2}-[0-9]{2}-)?(?:seed|correction)-`

// Ending is the record of a rejection or a withdrawal.
type Ending struct {
	Date   string `yaml:"date"`
	Reason string `yaml:"reason"`
}

// Superseded is the record of a supersession.
type Superseded struct {
	Date   string   `yaml:"date"`
	IDs    []string `yaml:"ids"`
	Reason string   `yaml:"reason"`
}

// Config holds the fields of a new-layout config.yaml. A field that is absent
// keeps its zero value; Keys on the Entry tells present from absent.
type Config struct {
	ID           string      `yaml:"id"`
	Slug         string      `yaml:"slug"`
	Title        string      `yaml:"title"`
	Summary      string      `yaml:"summary"`
	Status       string      `yaml:"status"`
	Category     string      `yaml:"category"`
	Breaking     *bool       `yaml:"breaking"`
	Affects      []string    `yaml:"affects"`
	Authors      []string    `yaml:"authors"`
	Created      string      `yaml:"created"`
	After        []string    `yaml:"after"`
	Accepted     string      `yaml:"accepted"`
	Rejected     *Ending     `yaml:"rejected"`
	Withdrawn    *Ending     `yaml:"withdrawn"`
	SupersededBy *Superseded `yaml:"superseded_by"`
}

// File is a text file of an entry.
type File struct {
	Exists bool
	Text   string
}

// TaskLine is one "- [ ] n.m repo: outcome" line of tasks.md.
type TaskLine struct {
	Line    int
	Done    bool
	Section int
	Index   int
	Repo    string
	Outcome string
	// Ref is the text of the closing "(...)" of a ticked line, if any.
	Ref string
}

// Question is one line of the proposal's "Open questions" section.
type Question struct {
	Line int
	// Kind is "blocking", "not blocking", "answered" or "" for a line with no mark.
	Kind string
	Text string
}

// Entry is one change folder, live or archived.
type Entry struct {
	// Dir is the absolute path of the folder.
	Dir string
	// Folder is the folder name; Base is the name without the archive date.
	Folder, Base string
	Archived     bool
	// Date is the archive date prefix, empty for a live folder.
	Date string
	Kind Kind
	// FolderID and FolderSlug come from the name: "0013" and "secret-field-attributes";
	// for a seed FolderSlug is the capability and FolderID is empty; a correction
	// has an empty FolderID and its FolderSlug is the name of the fix.
	FolderID, FolderSlug string

	ConfigFile File
	Config     Config
	// Keys lists the top-level keys of config.yaml, in file order.
	Keys      []string
	ConfigErr error

	OpenSpecFile File
	// OpenSpecKeys lists the top-level keys of .openspec.yaml.
	OpenSpecKeys []string
	SkipSpecs    bool
	RetireCaps   bool
	OpenSpecErr  error

	Proposal, Design, Tasks, Readme, Source File
	Questions                               []Question
	TaskLines                               []TaskLine
	// TaskLineErrors lists the lines under a task heading that look like a
	// task but do not parse.
	TaskLineErrors []int

	// HasSpecsDir reports a specs folder; Specs holds each spec.md in it.
	HasSpecsDir bool
	Specs       []*delta.Spec
	// Evidence lists the files under evidence/, as slash paths relative to it.
	Evidence []string
	// HasEvidence reports an evidence folder.
	HasEvidence bool
	// Symlinks lists paths under the folder that are symbolic links.
	Symlinks []string
}

// ID returns the id from config.yaml, or from the folder name when the config
// has none.
func (e *Entry) ID() string {
	if e.Config.ID != "" {
		return e.Config.ID
	}
	return e.FolderID
}

// Label names the entry in messages.
func (e *Entry) Label() string { return e.Base }

// Store is the set of folders of one repository checkout.
type Store struct {
	Root string
	// Live and Archived hold new-layout entries and seeds.
	Live, Archived []*Entry
	// OldArchived lists the ids of the folders under archive/NNNN.
	OldArchived []string
	// LegacyLive lists the old-layout folders NNNN/ at the root.
	LegacyLive []string
	// Specs maps a capability name to its main spec, if openspec/specs has one.
	Specs map[string]*delta.Spec
}

// All returns live entries then archived ones.
func (s *Store) All() []*Entry {
	out := append([]*Entry{}, s.Live...)
	return append(out, s.Archived...)
}

// Find returns the live or archived entry whose id or base name is key.
func (s *Store) Find(key string) *Entry {
	for _, e := range s.All() {
		if e.Base == key || (e.Kind == Enhancement && (e.FolderID == key)) {
			return e
		}
	}
	return nil
}

var (
	liveRe     = regexp.MustCompile(`^(\d{4})-([a-z0-9][a-z0-9-]*)$`)
	looseRe    = regexp.MustCompile(`^(\d{4})-(.+)$`)
	seedRe     = regexp.MustCompile("^" + regexp.QuoteMeta(SeedPrefix) + "(.+)$")
	corrRe     = regexp.MustCompile("^" + regexp.QuoteMeta(CorrectionPrefix) + "(.+)$")
	archiveRe  = regexp.MustCompile(`^(\d{4}-\d{2}-\d{2})-(.+)$`)
	idDirRe    = regexp.MustCompile(`^\d{4}$`)
	taskRe     = regexp.MustCompile(`^- \[( |x|X)\] (\d+)\.(\d+) ([^:]+): (.+)$`)
	taskLikeRe = regexp.MustCompile(`^\s*- \[[ xX]\]`)
	refRe      = regexp.MustCompile("\\s\\(`?([^()`]+)`?\\)\\s*$")
	// A list item starts a question however deep it is indented, with a
	// bullet or a number: "  - Blocking: ..." and "1. Blocking: ..." both
	// count. A line without a marker continues the question above it.
	listItemRe = regexp.MustCompile(`^\s*(?:[-*+]|\d+[.)])\s`)
	itemMarkRe = regexp.MustCompile(`^\s*(?:[-*+]|\d+[.)])\s+`)
	questionRe = regexp.MustCompile(`^\s*(?:[-*+]|\d+[.)])\s+(Blocking|Not blocking|Answered):\s*(.*)$`)
)

// LoadStore reads the folders under root.
func LoadStore(root string) (*Store, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return nil, err
	}
	st := &Store{Root: root, Specs: map[string]*delta.Spec{}}
	changes := filepath.Join(root, "openspec", "changes")
	names, err := dirNames(changes)
	if err != nil {
		return nil, err
	}
	for _, n := range names {
		if n == "archive" {
			continue
		}
		e, err := Load(filepath.Join(changes, n), false)
		if err != nil {
			return nil, err
		}
		st.Live = append(st.Live, e)
	}
	arch, err := dirNames(filepath.Join(changes, "archive"))
	if err != nil {
		return nil, err
	}
	for _, n := range arch {
		e, err := Load(filepath.Join(changes, "archive", n), true)
		if err != nil {
			return nil, err
		}
		st.Archived = append(st.Archived, e)
	}
	old, err := dirNames(filepath.Join(root, "archive"))
	if err != nil {
		return nil, err
	}
	for _, n := range old {
		if idDirRe.MatchString(n) {
			st.OldArchived = append(st.OldArchived, n)
		}
	}
	top, err := dirNames(root)
	if err != nil {
		return nil, err
	}
	for _, n := range top {
		if idDirRe.MatchString(n) {
			st.LegacyLive = append(st.LegacyLive, n)
		}
	}
	specNames, err := dirNames(filepath.Join(root, "openspec", "specs"))
	if err != nil {
		return nil, err
	}
	for _, c := range specNames {
		p := filepath.Join(root, "openspec", "specs", c, "spec.md")
		b, err := os.ReadFile(p)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, err
		}
		st.Specs[c] = delta.Parse(p, c, b)
	}
	return st, nil
}

// dirNames lists the sub-folders of dir, sorted; a missing dir is empty.
func dirNames(dir string) ([]string, error) {
	ents, err := os.ReadDir(dir)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var out []string
	for _, d := range ents {
		if d.IsDir() {
			out = append(out, d.Name())
		}
	}
	sort.Strings(out)
	return out, nil
}

// Load reads one change folder.
func Load(dir string, archived bool) (*Entry, error) {
	dir, err := filepath.Abs(dir)
	if err != nil {
		return nil, err
	}
	e := &Entry{Dir: dir, Folder: filepath.Base(dir), Archived: archived}
	e.Base = e.Folder
	if archived {
		if m := archiveRe.FindStringSubmatch(e.Folder); m != nil {
			e.Date, e.Base = m[1], m[2]
		}
	}
	switch {
	case seedRe.MatchString(e.Base):
		e.Kind = Seed
		e.FolderSlug = seedRe.FindStringSubmatch(e.Base)[1]
	case corrRe.MatchString(e.Base):
		e.Kind = Correction
		e.FolderSlug = corrRe.FindStringSubmatch(e.Base)[1]
	case looseRe.MatchString(e.Base):
		m := looseRe.FindStringSubmatch(e.Base)
		e.FolderID, e.FolderSlug = m[1], m[2]
	}

	read := func(name string) (File, error) {
		b, err := os.ReadFile(filepath.Join(dir, name))
		if errors.Is(err, fs.ErrNotExist) {
			return File{}, nil
		}
		if err != nil {
			return File{}, err
		}
		return File{Exists: true, Text: strings.ReplaceAll(string(b), "\r\n", "\n")}, nil
	}
	for _, f := range []struct {
		name string
		dst  *File
	}{
		{"config.yaml", &e.ConfigFile}, {".openspec.yaml", &e.OpenSpecFile},
		{"proposal.md", &e.Proposal}, {"design.md", &e.Design}, {"tasks.md", &e.Tasks},
		{"README.md", &e.Readme}, {"source.md", &e.Source},
	} {
		if *f.dst, err = read(f.name); err != nil {
			return nil, err
		}
	}
	e.readConfig()
	e.readOpenSpec()
	e.readProposal()
	e.readTasks()
	if err := e.readSpecs(); err != nil {
		return nil, err
	}
	if err := e.readEvidence(); err != nil {
		return nil, err
	}
	return e, nil
}

func topKeys(src string) ([]string, error) {
	var doc yaml.Node
	if err := yaml.Unmarshal([]byte(src), &doc); err != nil {
		return nil, err
	}
	if len(doc.Content) == 0 || doc.Content[0].Kind != yaml.MappingNode {
		return nil, nil
	}
	var keys []string
	m := doc.Content[0]
	for i := 0; i+1 < len(m.Content); i += 2 {
		keys = append(keys, m.Content[i].Value)
	}
	return keys, nil
}

func (e *Entry) readConfig() {
	if !e.ConfigFile.Exists {
		return
	}
	keys, err := topKeys(e.ConfigFile.Text)
	if err != nil {
		e.ConfigErr = err
		return
	}
	e.Keys = keys
	// A type error still fills the fields that did decode.
	if err := yaml.Unmarshal([]byte(e.ConfigFile.Text), &e.Config); err != nil {
		e.ConfigErr = err
	}
}

func (e *Entry) readOpenSpec() {
	if !e.OpenSpecFile.Exists {
		return
	}
	keys, err := topKeys(e.OpenSpecFile.Text)
	if err != nil {
		e.OpenSpecErr = err
		return
	}
	e.OpenSpecKeys = keys
	var m map[string]any
	if err := yaml.Unmarshal([]byte(e.OpenSpecFile.Text), &m); err != nil {
		e.OpenSpecErr = err
		return
	}
	e.SkipSpecs, _ = m["skip_specs"].(bool)
	e.RetireCaps, _ = m["retire_capabilities"].(bool)
}

func (e *Entry) readProposal() {
	if !e.Proposal.Exists {
		return
	}
	in := false
	fence := false
	for i, l := range strings.Split(e.Proposal.Text, "\n") {
		if strings.HasPrefix(l, "```") || strings.HasPrefix(l, "~~~") {
			fence = !fence
		}
		if fence {
			continue
		}
		if strings.HasPrefix(l, "## ") {
			in = strings.EqualFold(strings.TrimSpace(l[3:]), "Open questions")
			continue
		}
		t := strings.TrimSpace(l)
		if !in || t == "" || strings.HasPrefix(t, "<!--") {
			continue
		}
		if !listItemRe.MatchString(l) {
			// An indented or plain line below a question continues it.
			if n := len(e.Questions); n > 0 {
				e.Questions[n-1].Text += " " + t
			}
			continue
		}
		q := Question{Line: i + 1, Text: strings.TrimSpace(itemMarkRe.ReplaceAllString(l, ""))}
		if m := questionRe.FindStringSubmatch(l); m != nil {
			q.Kind, q.Text = strings.ToLower(m[1]), strings.TrimSpace(m[2])
		}
		e.Questions = append(e.Questions, q)
	}
}

func (e *Entry) readTasks() {
	if !e.Tasks.Exists {
		return
	}
	text := commentStrip(e.Tasks.Text)
	for i, l := range strings.Split(text, "\n") {
		if m := taskRe.FindStringSubmatch(l); m != nil {
			t := TaskLine{Line: i + 1, Done: m[1] != " ", Repo: strings.TrimSpace(m[4]), Outcome: strings.TrimSpace(m[5])}
			fmt.Sscanf(m[2], "%d", &t.Section)
			fmt.Sscanf(m[3], "%d", &t.Index)
			if r := refRe.FindStringSubmatch(t.Outcome); r != nil {
				t.Ref = r[1]
			}
			e.TaskLines = append(e.TaskLines, t)
		} else if taskLikeRe.MatchString(l) {
			e.TaskLineErrors = append(e.TaskLineErrors, i+1)
		}
	}
}

// commentStrip blanks HTML comments but keeps the line count.
func commentStrip(s string) string {
	var b strings.Builder
	for {
		i := strings.Index(s, "<!--")
		if i < 0 {
			b.WriteString(s)
			return b.String()
		}
		j := strings.Index(s[i:], "-->")
		if j < 0 {
			b.WriteString(s[:i])
			b.WriteString(strings.Repeat("\n", strings.Count(s[i:], "\n")))
			return b.String()
		}
		b.WriteString(s[:i])
		b.WriteString(strings.Repeat("\n", strings.Count(s[i:i+j+3], "\n")))
		s = s[i+j+3:]
	}
}

func (e *Entry) readSpecs() error {
	root := filepath.Join(e.Dir, "specs")
	st, err := os.Stat(root)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	e.HasSpecsDir = st.IsDir()
	return filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type()&fs.ModeSymlink != 0 {
			e.Symlinks = append(e.Symlinks, p)
			return nil
		}
		if d.IsDir() || d.Name() != "spec.md" {
			return nil
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		e.Specs = append(e.Specs, delta.Parse(p, filepath.Base(filepath.Dir(p)), b))
		return nil
	})
}

func (e *Entry) readEvidence() error {
	root := filepath.Join(e.Dir, "evidence")
	st, err := os.Stat(root)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	e.HasEvidence = st.IsDir()
	return filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type()&fs.ModeSymlink != 0 {
			e.Symlinks = append(e.Symlinks, p)
			return nil
		}
		if d.IsDir() {
			return nil
		}
		rel, _ := filepath.Rel(root, p)
		e.Evidence = append(e.Evidence, filepath.ToSlash(rel))
		return nil
	})
}

// StrictFolderRe reports whether a folder name is <id>-<kebab-slug>.
func StrictFolderRe(name string) (id, slug string, ok bool) {
	m := liveRe.FindStringSubmatch(name)
	if m == nil {
		return "", "", false
	}
	return m[1], m[2], true
}
