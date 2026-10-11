// Package citerewrite rewrites the citations of enhancement decisions in the
// files of a repo (design T2.3 section 9) and lists the sites that an agent
// must rewrite by hand.
package citerewrite

import (
	_ "embed"
	"fmt"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

//go:generate go run ./titlegen -ref 18705155 -out titles.tsv

//go:embed titles.tsv
var titlesTSV string

// short-titles.tsv is written by hand (id, decision number, short form). It
// holds a short form for every title over 110 characters and for every title
// that holds an id; titles.tsv itself stays exactly what titlegen writes.
//
//go:embed short-titles.tsv
var shortTSV string

// Titles is the table of decision titles: one row per decision heading of
// the 27 entries, read once at their last commit before the migration.
type Titles struct {
	title  map[string]map[int]string
	short  map[string]map[int]string
	layout map[string]string
	count  int
}

// DefaultTitles returns the embedded table.
func DefaultTitles() *Titles {
	t, err := ParseTitles(titlesTSV)
	if err != nil {
		panic("citerewrite: embedded titles.tsv: " + err.Error())
	}
	if err := t.AddShort(shortTSV); err != nil {
		panic("citerewrite: embedded short-titles.tsv: " + err.Error())
	}
	return t
}

// AddShort reads the hand-written short forms (id, decision, short form).
func (t *Titles) AddShort(tsv string) error {
	t.short = map[string]map[int]string{}
	for i, line := range strings.Split(tsv, "\n") {
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.SplitN(line, "\t", 3)
		if len(f) != 3 {
			return fmt.Errorf("line %d: want 3 tab-separated fields", i+1)
		}
		n, err := strconv.Atoi(f[1])
		if err != nil {
			return fmt.Errorf("line %d: %v", i+1, err)
		}
		if _, ok := t.title[f[0]][n]; !ok {
			return fmt.Errorf("line %d: %s D%d is not a decision of the table", i+1, f[0], n)
		}
		if t.short[f[0]] == nil {
			t.short[f[0]] = map[int]string{}
		}
		t.short[f[0]][n] = f[2]
	}
	return nil
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

// Title returns the heading of decision n of entry id, as the table holds it.
func (t *Titles) Title(id string, n int) (string, bool) {
	s, ok := t.title[id][n]
	return s, ok
}

var (
	mergedRe = regexp.MustCompile(`^\(merged into D([0-9]+), `)
	movedRe  = regexp.MustCompile(`^\(moved to ([0-9]{4}):D([0-9]+), `)
)

// Resolve follows a tombstone heading to the decision that took its place:
// "(merged into D10, ...)" stays in the entry, "(moved to 0027:D3, ...)"
// goes to the other entry. A heading that is no tombstone resolves to itself.
func (t *Titles) Resolve(id string, n int) (string, int, bool) {
	for range 8 {
		title, ok := t.title[id][n]
		if !ok {
			return "", 0, false
		}
		if m := mergedRe.FindStringSubmatch(title); m != nil {
			n, _ = strconv.Atoi(m[1])
			continue
		}
		if m := movedRe.FindStringSubmatch(title); m != nil {
			id = m[1]
			n, _ = strconv.Atoi(m[2])
			continue
		}
		return id, n, true
	}
	return "", 0, false
}

// Effective returns the entry and the words that the tool writes for a
// citation of decision n of entry id: the short form when there is one, else
// the heading, after a tombstone is followed.
func (t *Titles) Effective(id string, n int) (string, string, bool) {
	rid, rn, ok := t.Resolve(id, n)
	if !ok {
		return "", "", false
	}
	if s, ok := t.short[rid][rn]; ok {
		return rid, s, true
	}
	return rid, t.title[rid][rn], true
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
