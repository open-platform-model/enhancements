// Package delta parses OpenSpec spec files: a delta spec of a change
// (ADDED, MODIFIED, REMOVED and RENAMED requirement sections, with an optional
// Purpose) and a main spec (a Requirements section). The reading rules follow
// OpenSpec 1.14.1 (requirement-blocks.ts, requirement-text.ts), read at commit
// 9111a76: code fences hide headers, a scenario is any level-four header with a
// body, and the requirement text is the body above the first header.
package delta

import (
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/words"
)

// Op is the operation a requirement block carries.
type Op string

// The operations of a delta spec. Main marks a requirement of a main spec.
const (
	Main     Op = "MAIN"
	Added    Op = "ADDED"
	Modified Op = "MODIFIED"
	Removed  Op = "REMOVED"
)

// Scenario is one level-four block of a requirement.
type Scenario struct {
	// Name is the heading text after "Scenario:".
	Name string
	// Line is the 1-based line of the heading.
	Line int
	// Empty reports a scenario with no body, which OpenSpec does not count.
	Empty bool
}

// Requirement is one "### Requirement:" block.
type Requirement struct {
	Op   Op
	Name string
	// Line is the 1-based line of the heading.
	Line int
	// Text is the paragraph between the heading and the first header below
	// it, as OpenSpec reads the requirement body.
	Text string
	// Scenarios lists the level-four blocks, empty ones included.
	Scenarios []Scenario
	// Reason and Migration hold the "**Reason**:" and "**Migration**:" lines
	// of a REMOVED block; HasReason and HasMigration tell absent from empty.
	Reason, Migration       string
	HasReason, HasMigration bool
	// Raw is the whole block, heading to last line.
	Raw string
}

// RealScenarios counts the scenarios that have a body.
func (r Requirement) RealScenarios() int {
	n := 0
	for _, s := range r.Scenarios {
		if !s.Empty {
			n++
		}
	}
	return n
}

// Rename is one FROM and TO pair of a RENAMED section.
type Rename struct {
	From, To string
	Line     int
}

// Spec is a parsed spec file.
type Spec struct {
	// Path is the file path as given to Parse.
	Path string
	// Capability is the folder name of the capability, as given to Parse.
	Capability string
	// HasPurpose reports a "## Purpose" section; Purpose is its trimmed text.
	HasPurpose  bool
	Purpose     string
	PurposeLine int
	// Requirements holds every block in file order.
	Requirements []Requirement
	Renames      []Rename
	// UnpairedRenames lists the lines of FROM or TO lines that formed no pair.
	UnpairedRenames []int
}

// By returns the requirements of one operation, in file order.
func (s *Spec) By(op Op) []Requirement {
	var out []Requirement
	for _, r := range s.Requirements {
		if r.Op == op {
			out = append(out, r)
		}
	}
	return out
}

var (
	opSectionRe = regexp.MustCompile(`(?i)^##\s+(ADDED|MODIFIED|REMOVED|RENAMED)\s+Requirements\s*$`)
	mainRe      = regexp.MustCompile(`(?i)^##\s+Requirements\s*$`)
	purposeRe   = regexp.MustCompile(`(?i)^##\s+Purpose\s*$`)
	topHeaderRe = regexp.MustCompile(`^##\s+`)
	reqHeaderRe = regexp.MustCompile(`(?i)^###\s*Requirement:\s*(.+?)\s*$`)
	anyHeaderRe = regexp.MustCompile(`^#{1,6}\s`)
	scenHeadRe  = regexp.MustCompile(`^####\s+(.*)$`)
	scenEndRe   = regexp.MustCompile(`^#{1,4}\s`)
	metaLineRe  = regexp.MustCompile(`^\*\*[^*]+\*\*:`)
	reasonRe    = regexp.MustCompile(`^\*\*Reason\*\*:\s*(.*)$`)
	migrationRe = regexp.MustCompile(`^\*\*Migration\*\*:\s*(.*)$`)
	fromRe      = regexp.MustCompile("(?i)^\\s*-?\\s*FROM:\\s*`?###\\s*Requirement:\\s*(.+?)`?\\s*$")
	toRe        = regexp.MustCompile("(?i)^\\s*-?\\s*TO:\\s*`?###\\s*Requirement:\\s*(.+?)`?\\s*$")
	closingRe   = regexp.MustCompile(`[ \t]+#+[ \t]*$`)
	scenPrefix  = regexp.MustCompile(`(?i)^Scenario:\s*`)
)

// NormalizeName folds a requirement name the way OpenSpec matches it: a
// closing run of "#" and the outer space are not part of the name.
func NormalizeName(s string) string {
	return strings.TrimSpace(closingRe.ReplaceAllString(s, ""))
}

// Parse reads one spec file. A file that holds no section yields an empty Spec.
func Parse(path, capability string, src []byte) *Spec {
	lines := strings.Split(strings.ReplaceAll(string(src), "\r\n", "\n"), "\n")
	mask := words.FenceMask(lines)
	sp := &Spec{Path: path, Capability: capability}

	type secKind int
	const (
		none secKind = iota
		purpose
		ops
		renamed
	)
	kind := none
	curOp := Op("")
	var purposeLines []string
	var pendingFrom string
	var pendingFromLine int

	// blocks of the current op section, as line ranges
	type span struct {
		op         Op
		start, end int // [start, end)
		name       string
	}
	var spans []span
	open := -1
	closeSpan := func(end int) {
		if open >= 0 {
			spans[open].end = end
			open = -1
		}
	}

	for i, l := range lines {
		if mask[i] {
			if kind == purpose {
				purposeLines = append(purposeLines, l)
			}
			continue
		}
		if topHeaderRe.MatchString(l) {
			closeSpan(i)
			if pendingFrom != "" {
				sp.UnpairedRenames = append(sp.UnpairedRenames, pendingFromLine)
				pendingFrom = ""
			}
			switch {
			case purposeRe.MatchString(l):
				kind = purpose
				sp.HasPurpose = true
				sp.PurposeLine = i + 1
			case opSectionRe.MatchString(l):
				name := strings.ToUpper(opSectionRe.FindStringSubmatch(l)[1])
				if name == "RENAMED" {
					kind = renamed
				} else {
					kind = ops
					curOp = Op(name)
				}
			case mainRe.MatchString(l):
				kind = ops
				curOp = Main
			default:
				kind = none
			}
			continue
		}
		switch kind {
		case purpose:
			purposeLines = append(purposeLines, l)
		case renamed:
			if m := fromRe.FindStringSubmatch(l); m != nil {
				if pendingFrom != "" {
					sp.UnpairedRenames = append(sp.UnpairedRenames, pendingFromLine)
				}
				pendingFrom, pendingFromLine = NormalizeName(m[1]), i+1
			} else if m := toRe.FindStringSubmatch(l); m != nil {
				if pendingFrom == "" {
					sp.UnpairedRenames = append(sp.UnpairedRenames, i+1)
				} else {
					sp.Renames = append(sp.Renames, Rename{From: pendingFrom, To: NormalizeName(m[1]), Line: pendingFromLine})
					pendingFrom = ""
				}
			}
		case ops:
			if m := reqHeaderRe.FindStringSubmatch(l); m != nil {
				closeSpan(i)
				spans = append(spans, span{op: curOp, start: i, name: NormalizeName(m[1])})
				open = len(spans) - 1
			}
		}
	}
	closeSpan(len(lines))
	if pendingFrom != "" {
		sp.UnpairedRenames = append(sp.UnpairedRenames, pendingFromLine)
	}
	sp.Purpose = strings.TrimSpace(strings.Join(purposeLines, "\n"))

	for _, s := range spans {
		sp.Requirements = append(sp.Requirements, readBlock(lines[s.start:s.end], mask[s.start:s.end], s.start, s.op, s.name))
	}
	return sp
}

func readBlock(block []string, mask []bool, startLine int, op Op, name string) Requirement {
	r := Requirement{Op: op, Name: name, Line: startLine + 1, Raw: strings.TrimRight(strings.Join(block, "\n"), "\n ")}
	body := block[1:]
	bmask := mask[1:]

	// requirement text: up to the first non-fenced header, blank lines and
	// (when other text exists) metadata lines skipped
	var captured, meta []string
	for j, l := range body {
		if bmask[j] {
			continue
		}
		if anyHeaderRe.MatchString(l) {
			break
		}
		t := strings.TrimSpace(l)
		if t == "" {
			continue
		}
		if metaLineRe.MatchString(t) {
			meta = append(meta, t)
			continue
		}
		captured = append(captured, t)
	}
	if len(captured) > 0 {
		r.Text = strings.Join(captured, "\n")
	} else {
		r.Text = strings.Join(meta, "\n")
	}

	if op == Removed {
		r.Reason, r.HasReason = metaValue(body, bmask, reasonRe)
		r.Migration, r.HasMigration = metaValue(body, bmask, migrationRe)
	}

	for j := 0; j < len(body); j++ {
		if bmask[j] {
			continue
		}
		m := scenHeadRe.FindStringSubmatch(body[j])
		if m == nil {
			continue
		}
		end := j + 1
		for end < len(body) && (bmask[end] || !scenEndRe.MatchString(body[end])) {
			end++
		}
		sc := Scenario{
			Name:  strings.TrimSpace(scenPrefix.ReplaceAllString(strings.TrimSpace(m[1]), "")),
			Line:  startLine + 2 + j,
			Empty: strings.TrimSpace(strings.Join(body[j+1:end], "\n")) == "",
		}
		r.Scenarios = append(r.Scenarios, sc)
		j = end - 1
	}
	return r
}

// metaValue returns the text of a "**Key**:" line and the lines that follow
// it up to the next blank line or header.
func metaValue(body []string, mask []bool, re *regexp.Regexp) (string, bool) {
	for j, l := range body {
		if mask[j] {
			continue
		}
		m := re.FindStringSubmatch(strings.TrimSpace(l))
		if m == nil {
			continue
		}
		parts := []string{m[1]}
		for k := j + 1; k < len(body) && !mask[k]; k++ {
			t := strings.TrimSpace(body[k])
			if t == "" || anyHeaderRe.MatchString(t) || metaLineRe.MatchString(t) {
				break
			}
			parts = append(parts, t)
		}
		return strings.TrimSpace(strings.Join(parts, " ")), true
	}
	return "", false
}
