package reconcile

import (
	"regexp"
	"strings"
)

// Declaration is one "Delivers NNNN, task X.Y." line of a repo change.
type Declaration struct {
	Repo     string
	Change   string
	Archived bool
	Entry    string
	Task     string
	// Path is the proposal, relative to the workspace root and prefixed with
	// the repo name.
	Path string
	Line int
}

// Task is one line of an entry's tasks.md.
type Task struct {
	Line    int
	ID      string
	Repo    string
	Outcome string
	Done    bool
	// Refs holds the change names of the tick, "(a-change)" or
	// "(a-change, b-change)". PR references are left out.
	Refs []string
}

var (
	deliversRe = regexp.MustCompile(`^\s*(?:[-*]\s+)?Delivers\s+(\d{4}),\s+task\s+(\d+\.\d+)\.?\s*$`)
	taskRe     = regexp.MustCompile(`^\s*- \[([ xX])\] (\d+\.\d+) ([A-Za-z0-9._-]+): (.*)$`)
	trailRe    = regexp.MustCompile(`\(([^()]*)\)\s*$`)
	nameRe     = regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`)
	fenceRe    = regexp.MustCompile("^\\s*(`{3,}|~{3,})")
)

// blank returns src with HTML comments and fenced code replaced by empty
// lines, so that line numbers stay the same.
func blank(src string) []string {
	lines := strings.Split(src, "\n")
	inComment := false
	var fenceChar byte
	fenceLen := 0
	for i, l := range lines {
		l = strings.TrimRight(l, "\r")
		if fenceLen > 0 {
			if m := fenceRe.FindString(l); m != "" {
				m = strings.TrimSpace(m)
				if m[0] == fenceChar && len(m) >= fenceLen {
					fenceLen = 0
				}
			}
			lines[i] = ""
			continue
		}
		if !inComment {
			if m := fenceRe.FindString(l); m != "" {
				m = strings.TrimSpace(m)
				fenceChar, fenceLen = m[0], len(m)
				lines[i] = ""
				continue
			}
		}
		var b strings.Builder
		rest := l
		for rest != "" {
			if inComment {
				end := strings.Index(rest, "-->")
				if end < 0 {
					rest = ""
					break
				}
				rest = rest[end+3:]
				inComment = false
				continue
			}
			start := strings.Index(rest, "<!--")
			if start < 0 {
				b.WriteString(rest)
				break
			}
			b.WriteString(rest[:start])
			rest = rest[start+4:]
			inComment = true
		}
		lines[i] = b.String()
	}
	return lines
}

// ParseDeclarations returns the Delivers lines of a proposal, outside code
// and comments. The repo, change and path fields are left for the caller.
func ParseDeclarations(src string) []Declaration {
	var out []Declaration
	for i, l := range blank(src) {
		if m := deliversRe.FindStringSubmatch(l); m != nil {
			out = append(out, Declaration{Entry: m[1], Task: m[2], Line: i + 1})
		}
	}
	return out
}

// ParseTasks returns the task lines of a tasks.md, outside code and comments.
func ParseTasks(src string) []Task {
	var out []Task
	for i, l := range blank(src) {
		m := taskRe.FindStringSubmatch(l)
		if m == nil {
			continue
		}
		t := Task{Line: i + 1, ID: m[2], Repo: m[3], Outcome: strings.TrimSpace(m[4]), Done: m[1] != " "}
		if t.Done {
			t.Refs = refsOf(t.Outcome)
		}
		out = append(out, t)
	}
	return out
}

// refsOf reads the trailing "(change-name)" of a ticked line. Text that is
// not a list of change names, and "PR n", yields none.
func refsOf(outcome string) []string {
	m := trailRe.FindStringSubmatch(outcome)
	if m == nil {
		return nil
	}
	var refs []string
	for _, part := range strings.FieldsFunc(m[1], func(r rune) bool { return r == ',' }) {
		part = strings.TrimSpace(part)
		if strings.HasPrefix(part, "and ") {
			part = strings.TrimSpace(strings.TrimPrefix(part, "and "))
		}
		if !nameRe.MatchString(part) {
			return nil
		}
		refs = append(refs, part)
	}
	return refs
}
