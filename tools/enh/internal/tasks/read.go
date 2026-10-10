package tasks

import (
	"fmt"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
)

// List prints one line per live entry and seed, or per archived one.
func (e *Env) List(archived bool) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	set := st.Live
	if archived {
		set = st.Archived
	}
	for _, en := range set {
		if en.Kind == entry.Seed {
			e.printf("%-12s %-10s %-12s %-7s %s\n", en.Base, "seed", "-", "-", en.Folder)
			continue
		}
		done, total := ticks(en)
		e.printf("%-6s %-10s %-12s %-7s %s\n", en.ID(), en.Config.Status, en.Config.Category,
			fmt.Sprintf("%d/%d", done, total), en.Config.Title)
	}
	return nil
}

func ticks(en *entry.Entry) (done, total int) {
	for _, t := range en.TaskLines {
		total++
		if t.Done {
			done++
		}
	}
	return
}

// Show prints the facts of one entry.
func (e *Env) Show(key string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en := st.Find(key)
	if en == nil {
		return usage("no entry %q", key)
	}
	c := en.Config
	e.printf("folder:   %s\n", e.rel(en))
	if en.Kind == entry.Seed {
		e.printf("kind:     seed (capability %s)\n", en.FolderSlug)
		return nil
	}
	e.printf("id:       %s\nslug:     %s\ntitle:    %s\nsummary:  %s\nstatus:   %s\ncategory: %s\n", c.ID, c.Slug, c.Title, c.Summary, c.Status, c.Category)
	if c.Breaking != nil {
		e.printf("breaking: %t\n", *c.Breaking)
	}
	e.printf("affects:  %s\nauthors:  %s\ncreated:  %s\n", strings.Join(c.Affects, ", "), strings.Join(c.Authors, ", "), c.Created)
	if len(c.After) > 0 {
		e.printf("after:    %s\n", strings.Join(c.After, ", "))
	}
	if c.Accepted != "" {
		e.printf("accepted: %s\n", c.Accepted)
	}
	done, total := ticks(en)
	e.printf("tasks:    %d of %d ticked\n", done, total)
	n := 0
	for _, sp := range en.Specs {
		n += len(sp.Requirements)
	}
	e.printf("specs:    %d capabilities, %d requirement blocks\n", len(en.Specs), n)
	return nil
}

// Questions prints the open questions of an entry's proposal.
func (e *Env) Questions(key string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en := st.Find(key)
	if en == nil {
		return usage("no entry %q", key)
	}
	if len(en.Questions) == 0 {
		e.printf("%s: no open question\n", en.Base)
		return nil
	}
	for _, q := range en.Questions {
		kind := q.Kind
		if kind == "" {
			kind = "unmarked"
		}
		e.printf("%s:%d: %s: %s\n", e.rel(en)+"/proposal.md", q.Line, kind, q.Text)
	}
	return nil
}
