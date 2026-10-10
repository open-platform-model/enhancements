// Package words counts the words of an entry's Markdown by the rule of
// T2.2 section 3 and splits a document into its level-two sections.
//
// The rule: count whitespace-separated words after removing front matter,
// HTML comments, fenced code (the diagram included), headings and Markdown
// markup. List markers, task boxes, table pipes, quote marks and emphasis
// marks are not words. A link counts its text, not its address. A token with
// no letter and no digit is not a word.
package words

import (
	"regexp"
	"strings"
	"unicode"
)

var (
	commentRe   = regexp.MustCompile(`(?s)<!--.*?-->`)
	headingRe   = regexp.MustCompile(`^\s{0,3}#{1,6}(\s|$)`)
	quoteRe     = regexp.MustCompile(`^\s*(>\s?)+`)
	listRe      = regexp.MustCompile(`^\s*([-*+]|\d+[.)])\s+(\[[ xX]\]\s+)?`)
	ruleRe      = regexp.MustCompile(`^\s*([-*_])(\s*[-*_]){2,}\s*$`)
	tableSepRe  = regexp.MustCompile(`^[\s|:\-]+$`)
	imageRe     = regexp.MustCompile(`!\[[^\]]*\]\([^)]*\)`)
	linkRe      = regexp.MustCompile(`\[([^\]]*)\]\([^)]*\)`)
	fenceOpenRe = regexp.MustCompile("^\\s{0,3}(`{3,}|~{3,})")
)

// Count returns the number of words in md by the counting rule.
func Count(md string) int {
	md = normalize(md)
	md = stripFrontMatter(md)
	lines := strings.Split(md, "\n")
	mask := FenceMask(lines)
	var kept []string
	for i, l := range lines {
		if !mask[i] {
			kept = append(kept, l)
		}
	}
	text := commentRe.ReplaceAllString(strings.Join(kept, "\n"), "")
	n := 0
	for _, l := range strings.Split(text, "\n") {
		n += countLine(l)
	}
	return n
}

func countLine(l string) int {
	if strings.TrimSpace(l) == "" || headingRe.MatchString(l) || ruleRe.MatchString(l) {
		return 0
	}
	l = quoteRe.ReplaceAllString(l, "")
	l = listRe.ReplaceAllString(l, "")
	if t := strings.TrimSpace(l); strings.HasPrefix(t, "|") {
		if tableSepRe.MatchString(t) {
			return 0
		}
		l = strings.ReplaceAll(t, "|", " ")
	}
	l = imageRe.ReplaceAllString(l, "")
	l = linkRe.ReplaceAllString(l, "$1")
	l = strings.NewReplacer("*", "", "`", "", "~~", "").Replace(l)
	n := 0
	for _, tok := range strings.Fields(l) {
		tok = strings.Trim(tok, "_")
		if hasLetterOrDigit(tok) {
			n++
		}
	}
	return n
}

func hasLetterOrDigit(s string) bool {
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			return true
		}
	}
	return false
}

func normalize(s string) string {
	return strings.ReplaceAll(s, "\r\n", "\n")
}

func stripFrontMatter(s string) string {
	if !strings.HasPrefix(s, "---\n") {
		return s
	}
	rest := s[4:]
	if i := strings.Index(rest, "\n---\n"); i >= 0 {
		return rest[i+5:]
	}
	if strings.HasSuffix(rest, "\n---") {
		return ""
	}
	return s
}

// FenceMask marks the lines that are a code fence or lie inside one. A fence
// closes on a line of the same character, at least as long as the opener.
func FenceMask(lines []string) []bool {
	mask := make([]bool, len(lines))
	var open string
	for i, l := range lines {
		m := fenceOpenRe.FindStringSubmatch(l)
		switch {
		case open == "" && m != nil:
			open = m[1]
			mask[i] = true
		case open != "":
			mask[i] = true
			if m != nil && m[1][0] == open[0] && len(m[1]) >= len(open) && strings.TrimSpace(l[strings.Index(l, m[1])+len(m[1]):]) == "" {
				open = ""
			}
		}
	}
	return mask
}

// Section is one level-two section of a document.
type Section struct {
	// Name is the heading text without the marks, for example "Open questions".
	Name string
	// Line is the 1-based line of the heading.
	Line int
	// Body is the text between this heading and the next level-two heading.
	Body string
}

// Sections splits md at its level-two headings outside code fences. The text
// before the first level-two heading is returned as preamble.
func Sections(md string) (preamble string, secs []Section) {
	lines := strings.Split(normalize(md), "\n")
	mask := FenceMask(lines)
	var cur *Section
	var buf []string
	flush := func() {
		if cur != nil {
			cur.Body = strings.Join(buf, "\n")
			secs = append(secs, *cur)
		} else {
			preamble = strings.Join(buf, "\n")
		}
		buf = nil
	}
	for i, l := range lines {
		if !mask[i] && strings.HasPrefix(l, "## ") {
			flush()
			cur = &Section{Name: strings.TrimSpace(strings.TrimLeft(l, "# ")), Line: i + 1}
			continue
		}
		buf = append(buf, l)
	}
	flush()
	return preamble, secs
}

// CountExcluding counts md without the level-two sections named in skip
// (compared without case).
func CountExcluding(md string, skip ...string) int {
	pre, secs := Sections(md)
	n := Count(pre)
	for _, s := range secs {
		drop := false
		for _, k := range skip {
			if strings.EqualFold(s.Name, k) {
				drop = true
			}
		}
		if !drop {
			n += Count(s.Body)
		}
	}
	return n
}
