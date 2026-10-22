package index

import (
	"errors"
	"fmt"
	"io/fs"
	"path"
	"regexp"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
)

const (
	changesDir  = "openspec/changes"
	archiveDir  = "openspec/changes/archive"
	specsDir    = "openspec/specs"
	legacyDir   = "archive"
	maxFileSize = 4 << 20
)

var (
	liveNameRe       = regexp.MustCompile(`^([0-9]{4})-([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)$`)
	archivedNameRe   = regexp.MustCompile(`^([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]{4})-([a-z0-9](?:[a-z0-9-]*[a-z0-9])?)$`)
	unnumberedNameRe = regexp.MustCompile(entry.UnnumberedNamePattern)
	legacyNameRe     = regexp.MustCompile(`^[0-9]{4}$`)
	idRe             = regexp.MustCompile(`^[0-9]{4}$`)
	dateRe           = regexp.MustCompile(`^[0-9]{4}-[0-9]{2}-[0-9]{2}$`)
)

// errMissing marks a config.yaml that does not exist.
var errMissing = errors.New("missing")

type rawEnding struct {
	Date   string `yaml:"date"`
	Reason string `yaml:"reason"`
}

type rawSuperseded struct {
	Date   string   `yaml:"date"`
	IDs    []string `yaml:"ids"`
	Reason string   `yaml:"reason"`
}

// rawConfig reads the fields the generators use. Unknown keys are ignored:
// the checker refuses them, not this package.
type rawConfig struct {
	ID             string     `yaml:"id"`
	Slug           string     `yaml:"slug"`
	Title          string     `yaml:"title"`
	Summary        string     `yaml:"summary"`
	Status         string     `yaml:"status"`
	Category       string     `yaml:"category"`
	Affects        []string   `yaml:"affects"`
	Created        string     `yaml:"created"`
	Breaking       *bool      `yaml:"breaking"`
	After          []string   `yaml:"after"`
	DependsOn      []string   `yaml:"depends_on"`
	Accepted       string     `yaml:"accepted"`
	Rejected       *rawEnding `yaml:"rejected"`
	Withdrawn      *rawEnding `yaml:"withdrawn"`
	SupersededBy   yaml.Node  `yaml:"superseded_by"`
	RejectedReason string     `yaml:"rejected_reason"`
}

type rawDelivery struct {
	Log []struct {
		Date string `yaml:"date"`
	} `yaml:"log"`
}

// Load reads the whole tree. It returns every entry error at once, joined, and
// no tree when there is one.
func Load(fsys fs.FS) (*Tree, error) {
	var errs []error
	t := &Tree{}
	for _, spec := range []struct {
		dir      string
		archived bool
	}{{changesDir, false}, {archiveDir, true}} {
		entries, err := fs.ReadDir(fsys, spec.dir)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("index: read %s: %w", spec.dir, err)
		}
		for _, d := range entries {
			if !d.IsDir() || (!spec.archived && d.Name() == "archive") || unnumberedNameRe.MatchString(d.Name()) {
				continue
			}
			e, err := loadOpenSpec(fsys, spec.dir, d.Name(), spec.archived)
			if err != nil {
				errs = append(errs, err)
				continue
			}
			t.Entries = append(t.Entries, e)
		}
	}
	legacy, err := fs.ReadDir(fsys, legacyDir)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, fmt.Errorf("index: read %s: %w", legacyDir, err)
	}
	for _, d := range legacy {
		if !d.IsDir() || !legacyNameRe.MatchString(d.Name()) {
			continue
		}
		e, err := loadLegacy(fsys, d.Name())
		if err != nil {
			errs = append(errs, err)
			continue
		}
		t.Entries = append(t.Entries, e)
	}
	live, err := fs.ReadDir(fsys, ".")
	if err != nil {
		return nil, fmt.Errorf("index: read the root: %w", err)
	}
	for _, d := range live {
		if d.IsDir() && legacyNameRe.MatchString(d.Name()) && d.Name() != "0000" {
			t.OldLiveIDs = append(t.OldLiveIDs, d.Name())
		}
	}
	for _, id := range t.OldLiveIDs {
		if t.hasEntry(id) {
			continue // the converted entry stands for the old folder
		}
		e, err := loadLegacyLive(fsys, id)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		if e != nil {
			t.Entries = append(t.Entries, e)
		}
	}
	caps, err := loadCapabilities(fsys)
	if err != nil {
		errs = append(errs, err)
	}
	t.Capabilities = caps

	sort.SliceStable(t.Entries, func(i, j int) bool { return t.Entries[i].ID < t.Entries[j].ID })
	for i := 1; i < len(t.Entries); i++ {
		if t.Entries[i].ID == t.Entries[i-1].ID {
			errs = append(errs, fmt.Errorf("id %s is in two folders: %s and %s", t.Entries[i].ID, t.Entries[i-1].Dir, t.Entries[i].Dir))
		}
	}
	if len(errs) > 0 {
		return nil, errors.Join(errs...)
	}
	return t, nil
}

func loadOpenSpec(fsys fs.FS, base, name string, archived bool) (*Entry, error) {
	dir := path.Join(base, name)
	var id, slug, date string
	if archived {
		m := archivedNameRe.FindStringSubmatch(name)
		if m == nil {
			return nil, fmt.Errorf("%s: the folder name is not <YYYY-MM-DD>-<id>-<slug>", dir)
		}
		date, id, slug = m[1], m[2], m[3]
	} else {
		m := liveNameRe.FindStringSubmatch(name)
		if m == nil {
			return nil, fmt.Errorf("%s: the folder name is not <id>-<slug>", dir)
		}
		id, slug = m[1], m[2]
	}
	raw, err := readConfig(fsys, path.Join(dir, "config.yaml"))
	if err != nil {
		return nil, err
	}
	e, err := entryFromConfig(raw, path.Join(dir, "config.yaml"))
	if err != nil {
		return nil, err
	}
	if e.ID != id {
		return nil, fmt.Errorf("%s/config.yaml: id %q does not match the folder id %q", dir, e.ID, id)
	}
	if e.Slug != slug {
		return nil, fmt.Errorf("%s/config.yaml: slug %q does not match the folder slug %q", dir, e.Slug, slug)
	}
	e.Layout = LayoutOpenSpec
	e.Dir = dir
	e.ArchiveDate = date

	if text, ok, err := readOptional(fsys, path.Join(dir, "tasks.md")); err != nil {
		return nil, err
	} else if ok {
		e.Tasks = ParseTasks(text)
	}
	if text, ok, err := readOptional(fsys, path.Join(dir, "proposal.md")); err != nil {
		return nil, err
	} else if ok {
		e.ProposalWords = len(strings.Fields(text))
	}
	if text, ok, err := readOptional(fsys, path.Join(dir, "design.md")); err != nil {
		return nil, err
	} else if ok {
		e.DesignWords = len(strings.Fields(text))
	}
	e.HasSpecs = dirHasEntries(fsys, path.Join(dir, "specs"))
	e.HasEvidence = dirHasEntries(fsys, path.Join(dir, "evidence"))
	return e, nil
}

func loadLegacy(fsys fs.FS, name string) (*Entry, error) {
	dir := path.Join(legacyDir, name)
	raw, err := readConfig(fsys, path.Join(dir, "config.yaml"))
	if err != nil {
		return nil, err
	}
	e, err := entryFromConfig(raw, path.Join(dir, "config.yaml"))
	if err != nil {
		return nil, err
	}
	if e.ID != name {
		return nil, fmt.Errorf("%s/config.yaml: id %q does not match the folder id %q", dir, e.ID, name)
	}
	e.Layout = LayoutLegacy
	e.Dir = dir
	if text, ok, err := readOptional(fsys, path.Join(dir, "delivery.yaml")); err != nil {
		return nil, err
	} else if ok {
		var d rawDelivery
		if err := yaml.Unmarshal([]byte(text), &d); err != nil {
			return nil, fmt.Errorf("%s/delivery.yaml: %w", dir, err)
		}
		e.Landings = len(d.Log)
		for _, l := range d.Log {
			if l.Date > e.LandedOn {
				e.LandedOn = l.Date
			}
		}
	}
	return e, nil
}

// loadLegacyLive reads an old-layout entry that is still live. A folder with no
// config.yaml gives no entry and no error: it stays a name in OldLiveIDs. The
// old `depends_on` list stands for `after`, the nearest relation the graph has.
func loadLegacyLive(fsys fs.FS, name string) (*Entry, error) {
	raw, err := readConfig(fsys, path.Join(name, "config.yaml"))
	if err != nil {
		if errors.Is(err, errMissing) {
			return nil, nil
		}
		return nil, err
	}
	raw.After = raw.DependsOn
	e, err := entryFromConfig(raw, path.Join(name, "config.yaml"))
	if err != nil {
		return nil, err
	}
	if e.ID != name {
		return nil, fmt.Errorf("%s/config.yaml: id %q does not match the folder id %q", name, e.ID, name)
	}
	e.Layout = LayoutLegacyLive
	e.Dir = name
	return e, nil
}

func readConfig(fsys fs.FS, p string) (*rawConfig, error) {
	text, ok, err := readOptional(fsys, p)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, fmt.Errorf("%s: %w", p, errMissing)
	}
	var raw rawConfig
	if err := yaml.Unmarshal([]byte(text), &raw); err != nil {
		return nil, fmt.Errorf("%s: %w", p, err)
	}
	return &raw, nil
}

func entryFromConfig(raw *rawConfig, p string) (*Entry, error) {
	var problems []string
	need := func(name, v string) {
		if strings.TrimSpace(v) == "" {
			problems = append(problems, name+" is missing")
		}
	}
	need("id", raw.ID)
	need("slug", raw.Slug)
	need("title", raw.Title)
	need("status", raw.Status)
	need("category", raw.Category)
	if raw.ID != "" && !idRe.MatchString(raw.ID) {
		problems = append(problems, fmt.Sprintf("id %q is not four digits", raw.ID))
	}
	if raw.Status != "" && !validStatus(raw.Status) {
		problems = append(problems, fmt.Sprintf("status %q is not one of %s", raw.Status, strings.Join(statuses, ", ")))
	}
	if raw.Category != "" && !validCategory(raw.Category) {
		problems = append(problems, fmt.Sprintf("category %q is not one of %s", raw.Category, strings.Join(Categories, ", ")))
	}
	for _, a := range raw.After {
		if !idRe.MatchString(a) {
			problems = append(problems, fmt.Sprintf("after holds %q, which is not four digits", a))
		}
	}
	sup, err := superseded(&raw.SupersededBy)
	if err != nil {
		problems = append(problems, err.Error())
	}
	if len(problems) > 0 {
		return nil, fmt.Errorf("%s: %s", p, strings.Join(problems, "; "))
	}
	e := &Entry{
		ID: raw.ID, Slug: raw.Slug, Title: raw.Title, Summary: oneLine(raw.Summary),
		Status: raw.Status, Category: raw.Category, Affects: raw.Affects, Created: raw.Created,
		Breaking: raw.Breaking, After: raw.After, Accepted: raw.Accepted,
		Superseded: sup, RejectedReason: raw.RejectedReason,
	}
	if raw.Rejected != nil {
		e.Rejected = &Ending{Date: raw.Rejected.Date, Reason: oneLine(raw.Rejected.Reason)}
	}
	if raw.Withdrawn != nil {
		e.Withdrawn = &Ending{Date: raw.Withdrawn.Date, Reason: oneLine(raw.Withdrawn.Reason)}
	}
	return e, nil
}

// superseded reads superseded_by, which is a record in the new layout and a
// bare id or null in the old one.
func superseded(n *yaml.Node) (*Superseded, error) {
	switch n.Kind {
	case 0:
		return nil, nil
	case yaml.ScalarNode:
		if n.Tag == "!!null" {
			return nil, nil
		}
		if !idRe.MatchString(n.Value) {
			return nil, fmt.Errorf("superseded_by %q is not a four-digit id", n.Value)
		}
		return &Superseded{IDs: []string{n.Value}}, nil
	case yaml.MappingNode:
		var r rawSuperseded
		if err := n.Decode(&r); err != nil {
			return nil, fmt.Errorf("superseded_by: %w", err)
		}
		for _, id := range r.IDs {
			if !idRe.MatchString(id) {
				return nil, fmt.Errorf("superseded_by.ids holds %q, which is not four digits", id)
			}
		}
		return &Superseded{Date: r.Date, IDs: r.IDs, Reason: oneLine(r.Reason)}, nil
	}
	return nil, errors.New("superseded_by is neither an id nor a record")
}

func loadCapabilities(fsys fs.FS) ([]Capability, error) {
	entries, err := fs.ReadDir(fsys, specsDir)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("index: read %s: %w", specsDir, err)
	}
	var caps []Capability
	var errs []error
	for _, d := range entries {
		if !d.IsDir() {
			continue
		}
		p := path.Join(specsDir, d.Name(), "spec.md")
		text, ok, err := readOptional(fsys, p)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		if !ok {
			errs = append(errs, fmt.Errorf("%s: missing", p))
			continue
		}
		caps = append(caps, parseSpec(d.Name(), text))
	}
	return caps, errors.Join(errs...)
}

// parseSpec reads the Purpose and counts the requirements of a spec.md.
func parseSpec(name, text string) Capability {
	c := Capability{Name: name}
	inPurpose := false
	var purpose []string
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimRight(line, "\r")
		switch {
		case strings.HasPrefix(line, "## "):
			inPurpose = strings.TrimSpace(line[3:]) == "Purpose"
		case strings.HasPrefix(line, "### Requirement:"):
			c.Requirements++
			inPurpose = false
		case inPurpose && strings.TrimSpace(line) != "":
			purpose = append(purpose, strings.TrimSpace(line))
		}
	}
	c.Purpose = firstSentence(strings.Join(purpose, " "))
	return c
}

// firstSentence cuts text after its first full stop that ends a word.
func firstSentence(s string) string {
	s = strings.TrimSpace(s)
	for i := 0; i < len(s); i++ {
		if s[i] == '.' && (i+1 == len(s) || s[i+1] == ' ') {
			return s[:i+1]
		}
	}
	return s
}

// oneLine joins a folded scalar into one line.
func oneLine(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

func readOptional(fsys fs.FS, p string) (string, bool, error) {
	f, err := fsys.Open(p)
	if errors.Is(err, fs.ErrNotExist) {
		return "", false, nil
	}
	if err != nil {
		return "", false, fmt.Errorf("index: open %s: %w", p, err)
	}
	defer func() { _ = f.Close() }() // read only
	info, err := f.Stat()
	if err != nil {
		return "", false, fmt.Errorf("index: stat %s: %w", p, err)
	}
	if info.IsDir() {
		return "", false, fmt.Errorf("index: %s is a folder, want a file", p)
	}
	if info.Size() > maxFileSize {
		return "", false, fmt.Errorf("index: %s is larger than %d bytes", p, maxFileSize)
	}
	b, err := fs.ReadFile(fsys, p)
	if err != nil {
		return "", false, fmt.Errorf("index: read %s: %w", p, err)
	}
	return string(b), true, nil
}

func dirHasEntries(fsys fs.FS, p string) bool {
	entries, err := fs.ReadDir(fsys, p)
	return err == nil && len(entries) > 0
}
