package links

import (
	"regexp"
	"strings"
)

// link is one relative-link candidate found in a Markdown file.
type link struct {
	line   int
	target string
}

var (
	fenceRe   = regexp.MustCompile("^\\s*(`{3,}|~{3,})(.*)$")
	codeRe    = regexp.MustCompile("`[^`]*`")
	refDefRe  = regexp.MustCompile(`^\s*\[[^\]]+\]:\s+(\S+)`)
	inlineRe  = regexp.MustCompile(`\]\(([^)]*)\)`)
	schemeRe  = regexp.MustCompile(`^[a-zA-Z][a-zA-Z0-9+.-]*:`)
	commentRe = regexp.MustCompile(`<!--.*?-->`)
)

// extract returns the links of a Markdown text outside fenced code, outside
// inline code spans and outside HTML comments: inline links and images
// `[text](target)` and reference definitions `[label]: target`.
func extract(src string) []link {
	var out []link
	var fenceChar byte
	fenceLen := 0
	inComment := false
	for i, raw := range strings.Split(src, "\n") {
		ln := i + 1
		raw = strings.TrimRight(raw, "\r")

		if fenceLen > 0 {
			if m := fenceRe.FindStringSubmatch(raw); m != nil && m[1][0] == fenceChar &&
				len(m[1]) >= fenceLen && strings.TrimSpace(m[2]) == "" {
				fenceLen = 0
			}
			continue
		}
		if m := fenceRe.FindStringSubmatch(raw); m != nil && !inComment {
			fenceChar, fenceLen = m[1][0], len(m[1])
			continue
		}

		line := raw
		// HTML comments, on one line or over several.
		if inComment {
			end := strings.Index(line, "-->")
			if end < 0 {
				continue
			}
			line = line[end+3:]
			inComment = false
		}
		line = commentRe.ReplaceAllString(line, "")
		if start := strings.Index(line, "<!--"); start >= 0 {
			line = line[:start]
			inComment = true
		}
		line = codeRe.ReplaceAllString(line, "")

		if m := refDefRe.FindStringSubmatch(line); m != nil {
			out = append(out, link{ln, m[1]})
			continue
		}
		for _, m := range inlineRe.FindAllStringSubmatch(line, -1) {
			t := strings.TrimSpace(m[1])
			if strings.HasPrefix(t, "<") {
				t = strings.TrimPrefix(t, "<")
				if end := strings.Index(t, ">"); end >= 0 {
					t = t[:end]
				}
			} else if sp := strings.IndexAny(t, " \t"); sp >= 0 {
				t = t[:sp]
			}
			if t != "" {
				out = append(out, link{ln, t})
			}
		}
	}
	return out
}
