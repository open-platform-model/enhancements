// Package citerewrite rewrites the citations of enhancement decisions in the
// files of a repo (design T2.3 section 9) and lists the sites that an agent
// must rewrite by hand.
package citerewrite

import (
	_ "embed"
	"fmt"
	"sort"
	"strconv"
	"strings"
)

//go:generate go run ./titlegen -ref 18705155 -out titles.tsv

//go:embed titles.tsv
var titlesTSV string

// Titles is the table of decision titles: one row per decision heading of
// the 27 entries, read once at their last commit before the migration.
type Titles struct {
	title  map[string]map[int]string
	layout map[string]string
	count  int
}

// DefaultTitles returns the embedded table.
func DefaultTitles() *Titles {
	t, err := ParseTitles(titlesTSV)
	if err != nil {
		panic("citerewrite: embedded titles.tsv: " + err.Error())
	}
	return t
}

// ParseTitles reads the TSV that titlegen writes.
func ParseTitles(tsv string) (*Titles, error) {
	t := &Titles{title: map[string]map[int]string{}, layout: map[string]string{}}
	for i, line := range strings.Split(tsv, "\n") {
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.SplitN(line, "\t", 4)
		if len(f) != 4 {
			return nil, fmt.Errorf("line %d: want 4 tab-separated fields", i+1)
		}
		n, err := strconv.Atoi(f[1])
		if err != nil {
			return nil, fmt.Errorf("line %d: %v", i+1, err)
		}
		if t.title[f[0]] == nil {
			t.title[f[0]] = map[int]string{}
		}
		t.title[f[0]][n] = f[3]
		t.layout[f[0]] = f[2]
		t.count++
	}
	return t, nil
}

// Count returns the number of decisions.
func (t *Titles) Count() int { return t.count }

// Entries returns the number of entries.
func (t *Titles) Entries() int { return len(t.layout) }

// Title returns the title of decision n of entry id.
func (t *Titles) Title(id string, n int) (string, bool) {
	s, ok := t.title[id][n]
	return s, ok
}

// Known reports whether id is one of the 27 entries.
func (t *Titles) Known(id string) bool { _, ok := t.layout[id]; return ok }

// Archived reports whether the entry is one of the ten old-layout entries,
// whose site pages keep their old slugs.
func (t *Titles) Archived(id string) bool { return t.layout[id] == "archived" }

// IDs returns the entry ids in order.
func (t *Titles) IDs() []string {
	out := make([]string, 0, len(t.layout))
	for id := range t.layout {
		out = append(out, id)
	}
	sort.Strings(out)
	return out
}

// Quoted returns the title ready to sit in text between double quotes: a
// double quote inside becomes a single quote.
func Quoted(title string) string {
	return `"` + strings.ReplaceAll(title, `"`, "'") + `"`
}
