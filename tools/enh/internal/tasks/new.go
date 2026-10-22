package tasks

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/alloc"
	"github.com/open-platform-model/enhancements/tools/enh/internal/cueschema"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/record"
)

var (
	slugRe = regexp.MustCompile(`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`)
	idRe   = regexp.MustCompile(`^[0-9]{4}$`)
)

// NewArgs are the arguments of New.
type NewArgs struct {
	Slug, Title, Summary, Category string
	Affects                        []string
}

// New allocates the lowest free id, makes the change with the OpenSpec CLI
// and writes its config.yaml. It returns the id.
func (e *Env) New(a NewArgs) (string, error) {
	for name, v := range map[string]string{"SLUG": a.Slug, "TITLE": a.Title, "SUMMARY": a.Summary, "CATEGORY": a.Category} {
		if strings.TrimSpace(v) == "" {
			return "", usage("%s is missing", name)
		}
	}
	if len(a.Affects) == 0 {
		return "", usage("AFFECTS is missing: name at least one repo, for example core,cli")
	}
	if !slugRe.MatchString(a.Slug) {
		return "", usage("slug %q must be kebab-case: lower-case letters, digits and single hyphens", a.Slug)
	}
	authors := e.Authors
	if len(authors) == 0 {
		if mail := e.git().UserEmail(); mail != "" {
			authors = []string{mail}
		}
	}
	if len(authors) == 0 {
		return "", usage("no author: set git user.email or pass --author")
	}
	schemaBytes, err := os.ReadFile(e.schemaPath())
	if err != nil {
		return "", err
	}
	sch, err := cueschema.Load(e.schemaPath())
	if err != nil {
		return "", err
	}

	var refs []string
	if r, err := e.git().Branches(); err == nil {
		refs = r
	}
	in := alloc.Inputs{FS: os.DirFS(e.Root), Schema: schemaBytes, Refs: refs}
	id, err := e.pickID(in)
	if err != nil {
		return "", err
	}

	cfg := newConfig(id, a, authors, e.today())
	if issues := sch.CheckConfig([]byte(cfg)); len(issues) > 0 {
		var msgs []string
		for _, is := range issues {
			msgs = append(msgs, strings.Join(is.Path, ".")+": "+is.Msg)
		}
		return "", usage("the new config.yaml does not satisfy schema.cue:\n  %s", strings.Join(msgs, "\n  "))
	}

	folder := id + "-" + a.Slug
	if out, err := e.Run(e.Root, "openspec", "new", "change", folder, "--schema", "enhancement"); err != nil {
		return "", fmt.Errorf("openspec new change %s failed: %w\n%s", folder, err, strings.TrimSpace(string(out)))
	}
	dir := filepath.Join(e.Root, "openspec", "changes", folder)
	if fi, err := os.Stat(dir); err != nil || !fi.IsDir() {
		return "", fmt.Errorf("openspec new change did not make %s", dir)
	}
	if err := record.WriteFile(filepath.Join(dir, "config.yaml"), []byte(cfg)); err != nil {
		return "", err
	}
	e.printf("created openspec/changes/%s/ (id %s)\n", folder, id)
	if err := e.indexAfter(); err != nil {
		return id, err
	}
	return id, nil
}

// pickID returns the id asked for, or the lowest free one.
func (e *Env) pickID(in alloc.Inputs) (string, error) {
	if e.ID == "" {
		res, err := alloc.Next(in)
		if err != nil {
			return "", err
		}
		for _, w := range res.Warnings {
			fmt.Fprintf(e.Err, "warning: %s\n", w)
		}
		return res.ID, nil
	}
	if !idRe.MatchString(e.ID) {
		return "", usage("id %q must be four digits", e.ID)
	}
	taken, err := alloc.Taken(in)
	if err != nil {
		return "", err
	}
	if why, used := taken[e.ID]; used {
		return "", refuse("id %s is not free: %s", e.ID, strings.Join(why, "; "))
	}
	return e.ID, nil
}

func newConfig(id string, a NewArgs, authors []string, created string) string {
	var b strings.Builder
	b.WriteString("# Facts only. History is `git log`.\n")
	fmt.Fprintf(&b, "id: %s\n", record.Quote(id))
	fmt.Fprintf(&b, "slug: %s\n", a.Slug)
	fmt.Fprintf(&b, "title: %s\n", record.Quote(oneLine(a.Title)))
	fmt.Fprintf(&b, "summary: %s\n", record.Quote(oneLine(a.Summary)))
	b.WriteString("status: draft\n")
	fmt.Fprintf(&b, "category: %s\n", a.Category)
	b.WriteString("affects:\n")
	for _, r := range a.Affects {
		fmt.Fprintf(&b, "  - %s\n", r)
	}
	b.WriteString("authors:\n")
	for _, r := range authors {
		fmt.Fprintf(&b, "  - %s\n", record.Quote(r))
	}
	fmt.Fprintf(&b, "created: %s\n", record.Quote(created))
	return b.String()
}

// oneLine keeps newlines out of a value that must stay on one line, so the
// schema check sees them as the error they are.
func oneLine(s string) string { return strings.TrimSpace(s) }

// SeedNew makes the change seed-<capability>. It refuses a capability that
// is already in specs/ or already has a live seed.
func (e *Env) SeedNew(capability string) error {
	if !slugRe.MatchString(capability) {
		return usage("capability %q must be kebab-case", capability)
	}
	if _, err := os.Stat(filepath.Join(e.Root, "openspec", "specs", capability)); err == nil {
		return refuse("capability %q is already in openspec/specs/: a seed fills a capability once; change it with an enhancement", capability)
	}
	folder := "seed-" + capability
	if _, err := os.Stat(filepath.Join(e.Root, "openspec", "changes", folder)); err == nil {
		return refuse("%s already exists in openspec/changes/", folder)
	}
	if out, err := e.Run(e.Root, "openspec", "new", "change", folder, "--schema", "seed"); err != nil {
		return fmt.Errorf("openspec new change %s failed: %w\n%s", folder, err, strings.TrimSpace(string(out)))
	}
	e.printf("created openspec/changes/%s/\n", folder)
	return nil
}

// CorrectionNew makes the change correction-<slug>. The slug names the fix,
// not a capability. Each capability given must already be in specs/: a
// correction changes delivered requirements, and a new capability is a seed.
// It refuses a slug with a live correction.
func (e *Env) CorrectionNew(slug string, capabilities []string) error {
	if !slugRe.MatchString(slug) {
		return usage("slug %q must be kebab-case", slug)
	}
	for _, c := range capabilities {
		if !slugRe.MatchString(c) {
			return usage("capability %q must be kebab-case", c)
		}
		if _, err := os.Stat(filepath.Join(e.Root, "openspec", "specs", c)); err != nil {
			return refuse("capability %q is not in openspec/specs/: a correction changes a delivered capability; make a seed for a new one", c)
		}
	}
	folder := entry.CorrectionPrefix + slug
	if _, err := os.Stat(filepath.Join(e.Root, "openspec", "changes", folder)); err == nil {
		return refuse("%s already exists in openspec/changes/", folder)
	}
	if out, err := e.Run(e.Root, "openspec", "new", "change", folder, "--schema", "correction"); err != nil {
		return fmt.Errorf("openspec new change %s failed: %w\n%s", folder, err, strings.TrimSpace(string(out)))
	}
	e.printf("created openspec/changes/%s/\n", folder)
	for _, c := range capabilities {
		e.printf("next: write specs/%s/spec.md in it\n", c)
	}
	e.printf("next: write source.md with one row in the Shipped by table for each requirement of each delta\n")
	return nil
}
