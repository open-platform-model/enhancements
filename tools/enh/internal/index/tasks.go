package index

import (
	"regexp"
	"strings"
)

var (
	sectionRe = regexp.MustCompile(`^##\s+([0-9]+)\.\s+(.+?)\s*$`)
	taskRe    = regexp.MustCompile(`^- \[([ xX])\]\s+([0-9]+\.[0-9]+)\s+([^\s:]+):\s*(.*?)\s*$`)
)

// ParseTasks reads tasks.md: `## n. Theme` headings and `- [ ] n.m repo:
// outcome` lines (ticked: `- [x]`). HTML comments and any other line are
// ignored. A task before the first heading goes into a section titled "Tasks".
func ParseTasks(text string) []Section {
	var out []Section
	inComment := false
	for _, line := range strings.Split(text, "\n") {
		line = strings.TrimRight(line, "\r")
		if inComment {
			if i := strings.Index(line, "-->"); i >= 0 {
				inComment = false
				line = line[i+3:]
			} else {
				continue
			}
		}
		for {
			i := strings.Index(line, "<!--")
			if i < 0 {
				break
			}
			if j := strings.Index(line[i:], "-->"); j >= 0 {
				line = line[:i] + line[i+j+3:]
				continue
			}
			line = line[:i]
			inComment = true
			break
		}
		if m := sectionRe.FindStringSubmatch(line); m != nil {
			out = append(out, Section{Title: m[1] + ". " + m[2]})
			continue
		}
		if m := taskRe.FindStringSubmatch(line); m != nil {
			if len(out) == 0 {
				out = append(out, Section{Title: "Tasks"})
			}
			s := &out[len(out)-1]
			s.Tasks = append(s.Tasks, Task{Num: m[2], Repo: m[3], Outcome: m[4], Done: m[1] != " "})
		}
	}
	return out
}
