// Package shipped reads the "Shipped by" table of the source.md of a
// correction: one row for each requirement block of its delta specs, with the
// change that shipped the behaviour and the code read.
package shipped

import (
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/history"
	"github.com/open-platform-model/enhancements/tools/enh/internal/words"
)

var (
	headRe      = regexp.MustCompile(`(?i)^##\s+Shipped by\s*$`)
	nextHeadRe  = regexp.MustCompile(`^##\s`)
	separatorRe = regexp.MustCompile(`^:?-{3,}:?$`)
)

// Row is one row of the table.
type Row struct {
	// Line is the 1-based line in source.md.
	Line int
	// Cells is the number of cells the row has; a complete row has 5.
	Cells int
	// Capability, Name and Op identify the requirement block; Name is
	// normalized as OpenSpec does, Op is upper case.
	Capability, Name, Op string
	// By holds the references to the shipping change; Code the code read.
	By, Code string
}

// Key identifies the requirement a row speaks of, with its operation.
func (r Row) Key() string { return r.Capability + "\x00" + r.Name + "\x00" + r.Op }

// Parse reads the table under "## Shipped by". found is false when the
// heading is absent. A comment and a fenced block are not read. The pipe
// character is the cell separator and cannot occur inside a cell.
func Parse(text string) (rows []Row, found bool) {
	lines := strings.Split(words.BlankComments(text), "\n")
	mask := words.FenceMask(lines)
	in := false
	for i, l := range lines {
		if mask[i] {
			continue
		}
		switch {
		case headRe.MatchString(l):
			in, found = true, true
			continue
		case in && nextHeadRe.MatchString(l):
			in = false
		}
		t := strings.TrimSpace(l)
		if !in || !strings.HasPrefix(t, "|") {
			continue
		}
		cells := strings.Split(strings.Trim(t, "|"), "|")
		for j := range cells {
			cells[j] = strings.TrimSpace(cells[j])
		}
		if isSeparator(cells) || strings.EqualFold(cells[0], "capability") {
			continue
		}
		row := Row{Line: i + 1, Cells: len(cells)}
		if len(cells) >= 5 {
			row.Capability = strings.Trim(cells[0], "`")
			row.Name = delta.NormalizeName(strings.Trim(cells[1], "`"))
			row.Op = strings.ToUpper(cells[2])
			row.By, row.Code = cells[3], cells[4]
		}
		rows = append(rows, row)
	}
	return rows, found
}

func isSeparator(cells []string) bool {
	for _, c := range cells {
		if !separatorRe.MatchString(c) {
			return false
		}
	}
	return true
}

// Replacements returns the requirements that a REMOVED block of the deltas
// replaces, as `Replaced by "<name>"` in its Migration line. The key is
// capability, a NUL byte and the normalized name. A replacement may sit in
// another capability of the same change, so the name counts for every
// capability the deltas cover.
func Replacements(specs []*delta.Spec) map[string]bool {
	out := map[string]bool{}
	for _, sp := range specs {
		for _, q := range sp.By(delta.Removed) {
			to, ok := history.ReplacedBy(q.Migration)
			if !ok {
				continue
			}
			for _, other := range specs {
				out[other.Capability+"\x00"+to] = true
			}
		}
	}
	return out
}
