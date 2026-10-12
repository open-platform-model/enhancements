// Package history derives the history of a requirement from the archived
// delta specs (design part two, section 4.1). Nothing is stored: the history
// is the archive read in date order.
package history

import (
	"fmt"
	"io"
	"regexp"
	"sort"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
)

// Source is one archived change folder.
type Source struct {
	// Folder is the archive folder name, with its date prefix.
	Folder string
	// Date is the archive date, YYYY-MM-DD.
	Date string
	// Label names the change in a row: the id of an entry, or seed-<capability>.
	Label string
	// Status is the status of the entry's config.yaml; a seed has none.
	Status string
	Specs  []*delta.Spec
}

// Operations of a row.
const (
	OpAdded    = "ADDED"
	OpModified = "MODIFIED"
	OpRemoved  = "REMOVED"
	OpRenamed  = "RENAMED"
)

// Row is one change of a requirement.
type Row struct {
	Date  string
	Label string
	Op    string
	// Seed marks an ADDED row of a seed: the origin of a requirement.
	Seed bool
	// Capability and Name are those of the requirement; for RENAMED, Name is the old name.
	Capability, Name string
	// To is the new name of a RENAMED row.
	To string
	// Text is the requirement text of an ADDED or MODIFIED row.
	Text string
	// Reason and Migration are those of a REMOVED row.
	Reason, Migration string
}

// Chain is the history of one requirement, rows in archive order.
type Chain struct {
	// Capability and Name are those of the newest row.
	Capability, Name string
	Rows             []Row
}

// Skipped statuses: a rejected, withdrawn or superseded change never reached specs/.
func skipped(status string) bool {
	switch status {
	case "rejected", "withdrawn", "superseded":
		return true
	}
	return false
}

var replacedRe = regexp.MustCompile(`^(?i:replaced by)\s+"([^"]+)"`)

// ReplacedBy returns the name in a Migration line of the fixed form
// `Replaced by "<name>"`.
func ReplacedBy(migration string) (string, bool) {
	m := replacedRe.FindStringSubmatch(strings.TrimSpace(migration))
	if m == nil {
		return "", false
	}
	return delta.NormalizeName(m[1]), true
}

type key struct{ cap, name string }

// Query returns the chains of the requirement called req. A capability narrows
// the match. order breaks a tie between folders of one date (lower first);
// a folder missing from it sorts after the others of its date, by name.
func Query(sources []Source, req, capability string, order map[string]int) ([]Chain, error) {
	srcs := make([]Source, 0, len(sources))
	for _, s := range sources {
		if !skipped(s.Status) {
			srcs = append(srcs, s)
		}
	}
	sort.SliceStable(srcs, func(i, j int) bool {
		a, b := srcs[i], srcs[j]
		if a.Date != b.Date {
			return a.Date < b.Date
		}
		oa, aok := order[a.Folder]
		ob, bok := order[b.Folder]
		if aok && bok && oa != ob {
			return oa < ob
		}
		if aok != bok {
			return aok
		}
		return a.Folder < b.Folder
	})

	parent := map[key]key{}
	var find func(k key) key
	find = func(k key) key {
		p, ok := parent[k]
		if !ok {
			parent[k] = k
			return k
		}
		if p == k {
			return k
		}
		r := find(p)
		parent[k] = r
		return r
	}
	union := func(a, b key) {
		ra, rb := find(a), find(b)
		if ra != rb {
			parent[rb] = ra
		}
	}

	type event struct {
		row Row
		key key
	}
	var events []event
	added := map[string][]key{} // name -> capabilities that ADDED it, with the source folder
	addedIn := map[[2]string]bool{}
	for _, s := range srcs {
		for _, sp := range s.Specs {
			for _, r := range sp.Requirements {
				if r.Op == delta.Added {
					added[delta.NormalizeName(r.Name)] = append(added[delta.NormalizeName(r.Name)], key{sp.Capability, s.Folder})
					addedIn[[2]string{s.Folder, sp.Capability + "\x00" + delta.NormalizeName(r.Name)}] = true
				}
			}
		}
	}
	for _, s := range srcs {
		seed := strings.HasPrefix(s.Label, "seed-")
		for _, sp := range s.Specs {
			for _, r := range sp.Requirements {
				name := delta.NormalizeName(r.Name)
				k := key{sp.Capability, name}
				find(k)
				row := Row{Date: s.Date, Label: s.Label, Capability: sp.Capability, Name: name}
				switch r.Op {
				case delta.Added:
					row.Op, row.Text, row.Seed = OpAdded, r.Text, seed
				case delta.Modified:
					row.Op, row.Text = OpModified, r.Text
				case delta.Removed:
					row.Op, row.Reason, row.Migration = OpRemoved, r.Reason, r.Migration
					if to, ok := ReplacedBy(r.Migration); ok {
						if tk, ok := replacement(s, sp.Capability, to, addedIn, added); ok {
							union(k, tk)
						}
					}
				default:
					continue
				}
				events = append(events, event{row, k})
			}
			for _, rn := range sp.Renames {
				from, to := delta.NormalizeName(rn.From), delta.NormalizeName(rn.To)
				union(key{sp.Capability, from}, key{sp.Capability, to})
				events = append(events, event{Row{Date: s.Date, Label: s.Label, Op: OpRenamed,
					Capability: sp.Capability, Name: from, To: to}, key{sp.Capability, from}})
			}
		}
	}

	groups := map[key]*Chain{}
	var roots []key
	for _, ev := range events {
		root := find(ev.key)
		c := groups[root]
		if c == nil {
			c = &Chain{}
			groups[root] = c
			roots = append(roots, root)
		}
		c.Rows = append(c.Rows, ev.row)
	}
	var out []Chain
	for _, root := range roots {
		c := groups[root]
		if !matches(c, req, capability) {
			continue
		}
		last := c.Rows[len(c.Rows)-1]
		c.Capability, c.Name = last.Capability, last.Name
		if last.Op == OpRenamed {
			c.Name = last.To
		}
		out = append(out, *c)
	}
	if len(out) == 0 {
		where := ""
		if capability != "" {
			where = " in capability " + capability
		}
		return nil, fmt.Errorf("no requirement named %q%s in the archived deltas", req, where)
	}
	return out, nil
}

// replacement finds the ADDED requirement a REMOVED one points to: the same
// change first, in the same capability, then in another capability; then the
// same capability in any change.
func replacement(s Source, cap, name string, addedIn map[[2]string]bool, added map[string][]key) (key, bool) {
	if addedIn[[2]string{s.Folder, cap + "\x00" + name}] {
		return key{cap, name}, true
	}
	for _, sp := range s.Specs {
		if addedIn[[2]string{s.Folder, sp.Capability + "\x00" + name}] {
			return key{sp.Capability, name}, true
		}
	}
	for _, k := range added[name] {
		if k.cap == cap {
			return key{cap, name}, true
		}
	}
	return key{}, false
}

func matches(c *Chain, req, capability string) bool {
	for _, r := range c.Rows {
		if capability != "" && r.Capability != capability {
			continue
		}
		if strings.EqualFold(r.Name, req) || (r.Op == OpRenamed && strings.EqualFold(r.To, req)) {
			return true
		}
	}
	return false
}

// Format writes the chains: a heading per requirement, a row per change.
func Format(w io.Writer, chains []Chain) {
	for i, c := range chains {
		if i > 0 {
			fmt.Fprintln(w)
		}
		fmt.Fprintf(w, "%s / %s\n", c.Capability, c.Name)
		for _, r := range c.Rows {
			tag := ""
			if r.Seed {
				tag = "  (origin)"
			}
			fmt.Fprintln(w, strings.TrimRight(fmt.Sprintf("  %s  %-28s  %-8s%s", r.Date, r.Label, r.Op, tag), " "))
			switch r.Op {
			case OpRenamed:
				fmt.Fprintf(w, "    from %q to %q\n", r.Name, r.To)
			case OpRemoved:
				wrap(w, "Reason: "+r.Reason)
				wrap(w, "Migration: "+r.Migration)
			default:
				wrap(w, r.Text)
			}
		}
	}
}

const wrapAt = 100

func wrap(w io.Writer, text string) {
	line := "   "
	for _, word := range strings.Fields(text) {
		if len(line)+1+len(word) > wrapAt && strings.TrimSpace(line) != "" {
			fmt.Fprintln(w, line)
			line = "   "
		}
		line += " " + word
	}
	if strings.TrimSpace(line) != "" {
		fmt.Fprintln(w, line)
	}
}
