package citerewrite

import (
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/cites"
)

type textKind int

const (
	textMarkdown textKind = iota
	textYAML
	textHash // shell and other files whose # lines are comments
)

var leadWordRe = regexp.MustCompile(`(?i)enhancements?[ \t]+$`)

var (
	headingRe   = regexp.MustCompile(`^ {0,3}#{1,6}([ \t]|$)`)
	fenceRe     = regexp.MustCompile("^\\s{0,3}(`{3,}|~{3,})")
	linkRe      = regexp.MustCompile(`\[([^\]\n]*)\]\(([^)\s]*)(?:\s+"[^"]*")?\)`)
	yamlKeyRe   = regexp.MustCompile(`^(\s*(?:-\s+)*)(?:"[^"]*"|'[^']*'|[^\s#'"\-][^:#]*?|-[^\s:][^:#]*?):(\s+|$)`)
	yamlListRe  = regexp.MustCompile(`^(\s*(?:-\s+)+)`)
	yamlBlockRe = regexp.MustCompile(`:\s+[|>][+-]?[0-9]?\s*(?:#.*)?$`)
)

// processText rewrites the citations of a Markdown, YAML or shell file. Text
// takes form 2; the retired ids form 3; paths and site URLs form 4. A
// citation that sits in code (a fence, a longer code span, a string) is a
// worklist row.
func processText(name string, src []byte, tt *Titles, kind textKind) FileResult {
	c := newCtx(name, src, tt)
	fence := ""
	blockIndent := -1
	for ln := 1; ln <= len(c.li.starts); ln++ {
		line := c.li.text(ln)
		base := c.li.starts[ln-1]
		if kind == textMarkdown {
			if m := fenceRe.FindStringSubmatch(line); m != nil {
				switch {
				case fence == "":
					fence = m[1]
				case m[1][0] == fence[0] && len(m[1]) >= len(fence) && strings.TrimSpace(line) == m[1]:
					fence = ""
				}
				continue
			}
			if fence != "" {
				c.lineSites(line, base, KindFenced)
				continue
			}
			if headingRe.MatchString(line) {
				// A heading is an anchor: a longer heading would move it
				// without a word, so an agent rewrites it and checks the links.
				c.lineSites(line, base, KindHeading)
				continue
			}
		}
		lc := lineCtx{kind: kind}
		if kind == textYAML {
			lc.yaml, blockIndent = classifyYAML(line, blockIndent)
		} else if kind == textHash {
			lc.yaml = yamlInfo{comment: strings.HasPrefix(strings.TrimSpace(line), "#")}
			if !lc.yaml.comment {
				c.lineSites(line, base, KindString)
				continue
			}
		}
		c.textLine(line, base, lc)
	}
	return c.res
}

// lineSites adds a worklist row for each citation phrase of a line, whatever its kind.
func (c *ctx) lineSites(line string, base int, kind string) {
	cs := cites.Scan(line)
	for _, ph := range groupPhrases(line, cs) {
		c.site(base+ph.start, kind, ph.cites)
	}
	c.bareRetired(line, cs, func(i int) int { return base + i })
	for _, p := range findPaths(line) {
		if p.rest != "" && p.rest != "/" {
			c.site(base+p.start, KindEntryFile, nil)
		}
	}
}

type lineCtx struct {
	kind textKind
	yaml yamlInfo
}

// yamlInfo says what a YAML line is, so that an inserted title keeps the
// scalar valid.
type yamlInfo struct {
	comment bool
	// block is true inside a literal or folded scalar: any text is safe.
	block bool
	// valueStart is the offset of the scalar in the line; -1 when the line
	// has none (a continuation line).
	valueStart int
	quote      byte // '"', '\'' or 0
	flow       bool
	commentAt  int // offset of a trailing " #", or -1
	none       bool
}

func classifyYAML(line string, blockIndent int) (yamlInfo, int) {
	trimmed := strings.TrimSpace(line)
	indent := len(line) - len(strings.TrimLeft(line, " \t"))
	info := yamlInfo{valueStart: -1, commentAt: -1}
	if trimmed == "" {
		return yamlInfo{comment: true, valueStart: -1, commentAt: -1}, blockIndent
	}
	if blockIndent >= 0 {
		if indent > blockIndent {
			info.block = true
			return info, blockIndent
		}
		blockIndent = -1
	}
	if strings.HasPrefix(trimmed, "#") {
		info.comment = true
		return info, blockIndent
	}
	rest := 0
	if m := yamlKeyRe.FindStringSubmatchIndex(line); m != nil {
		rest = m[1]
	} else if m := yamlListRe.FindStringSubmatchIndex(line); m != nil {
		rest = m[1]
	} else {
		info.none = true
		return info, blockIndent
	}
	info.valueStart = rest
	if yamlBlockRe.MatchString(line) {
		return info, indent
	}
	v := line[rest:]
	switch {
	case strings.HasPrefix(v, `"`):
		info.quote = '"'
		info.commentAt = commentAfterQuote(line, rest)
	case strings.HasPrefix(v, "'"):
		info.quote = '\''
		info.commentAt = commentAfterQuote(line, rest)
	case strings.HasPrefix(v, "[") || strings.HasPrefix(v, "{"):
		info.flow = true
	default:
		if i := strings.Index(v, " #"); i >= 0 {
			info.commentAt = rest + i
		}
	}
	return info, blockIndent
}

// fitYAML adapts the new text to the scalar around the citation. ok is false
// when the text would break the scalar.
func fitYAML(info yamlInfo, pos int, text string) (string, bool) {
	switch {
	case info.comment || info.block:
		return text, true
	case info.none || info.flow || info.valueStart < 0 || pos < info.valueStart:
		return "", false
	case info.commentAt >= 0 && pos > info.commentAt:
		return text, true
	case info.quote == '"':
		return strings.ReplaceAll(strings.ReplaceAll(text, `\`, `\\`), `"`, `\"`), true
	case info.quote == '\'':
		return strings.ReplaceAll(text, "'", "''"), true
	}
	if strings.Contains(text, ": ") || strings.Contains(text, " #") || strings.HasSuffix(text, ":") {
		return "", false
	}
	return text, true
}

// textLine handles one line of prose.
func (c *ctx) textLine(line string, base int, lc lineCtx) {
	var done [][2]int
	inDone := func(s, e int) bool {
		for _, d := range done {
			if s >= d[0] && e <= d[1] {
				return true
			}
		}
		return false
	}
	table := strings.HasPrefix(strings.TrimSpace(line), "|")

	if lc.kind == textMarkdown {
		c.linksInLine(line, base, &done, table)
	}

	spans := codeSpans(line, lc.kind == textMarkdown)
	cs := cites.Scan(line)
	for _, ph := range groupPhrases(line, cs) {
		if inDone(ph.start, ph.end) {
			continue
		}
		at := base + ph.cites[0].Start
		live, _ := splitRetired(ph.cites)
		switch {
		case ph.path:
			c.site(at, KindPathDecisions, ph.cites)
			done = append(done, [2]int{ph.start, ph.end})
		case ph.oq:
			c.site(at, KindOQ, ph.cites)
		case ph.glued && len(live) == 0:
			c.site(at, KindRetiredInline, ph.cites)
		case ph.glued:
			c.site(at, KindInline, ph.cites)
		case insideSpan(spans, ph.start, ph.end):
			c.site(at, KindCodeSpan, ph.cites)
		case ph.possessive:
			c.site(at, KindPossessive, ph.cites)
		case len(live) == 0:
			rs, re, repl, ok, lone := removal(line, ph.start, ph.end)
			switch {
			case lone:
				c.site(at, KindRetiredLone, ph.cites)
			case !ok:
				c.site(at, KindRetiredInline, ph.cites)
			default:
				c.edit(Edit{Start: base + rs, End: base + re, New: repl, Form: FormRetired})
			}
		default:
			c.proseEdit(line, base, lc, ph, live, table)
		}
	}
	c.bareRetired(line, cs, func(i int) int { return base + i })
	c.pathsInLine(line, base, lc, &done, spans)
}

// proseEdit writes form 2 for a phrase of live citations.
func (c *ctx) proseEdit(line string, base int, lc lineCtx, ph phrase, live []cites.Cite, table bool) {
	at := base + ph.cites[0].Start
	ls := extendLeadin(line, ph.start)
	b := trimBackSpaces(line, ls)
	a := skipSpaces(line, ph.end)
	start, end, compact := ph.start, ph.end, false
	if b > 0 && line[b-1] == '(' && a < len(line) && line[a] == ')' {
		// A parenthesis that holds only the citation: no nested parentheses.
		start, end, compact = b, a, true
	}
	text, bad := textForm(c.tt, live, compact)
	if bad != "" {
		c.site(at, bad, ph.cites)
		return
	}
	if !compact && (startsUpper(line[ph.start:]) || ls == ph.start && sentenceStart(line, ph.start)) {
		text = upperFirst(text)
	}
	if table {
		text = strings.ReplaceAll(text, "|", `\|`)
	}
	if lc.kind == textYAML {
		var ok bool
		if text, ok = fitYAML(lc.yaml, ph.start, text); !ok {
			c.site(at, KindUnsafeYAML, ph.cites)
			return
		}
	}
	if !c.edit(Edit{Start: base + start, End: base + end, New: text, Form: FormText}) {
		c.site(at, KindWrapped, ph.cites)
	}
}

// codeSpans returns the [open, close] offsets of the backtick pairs in a line.
func codeSpans(line string, markdown bool) [][2]int {
	if !markdown {
		return nil
	}
	var out [][2]int
	open := -1
	for i := 0; i < len(line); i++ {
		if line[i] != '`' {
			continue
		}
		if open < 0 {
			open = i
		} else {
			out = append(out, [2]int{open, i})
			open = -1
		}
	}
	return out
}

// insideSpan reports whether [s, e) lies strictly inside an inline code span,
// so that the span holds more than the citation.
func insideSpan(spans [][2]int, s, e int) bool {
	for _, sp := range spans {
		if s > sp[0] && e <= sp[1] {
			return true
		}
	}
	return false
}

// linksInLine rewrites the Markdown links whose text is a citation, and the
// links to an entry by path.
func (c *ctx) linksInLine(line string, base int, done *[][2]int, table bool) {
	for _, m := range linkRe.FindAllStringSubmatchIndex(line, -1) {
		text, dest := line[m[2]:m[3]], line[m[4]:m[5]]
		whole := [2]int{m[0], m[1]}
		at := base + m[0]
		refs := findPaths(dest)
		cs := cites.Scan(text)
		switch {
		case len(cs) > 0 && onlyCites(text, cs) && (len(refs) > 0 || strings.Contains(dest, "enhancement")):
			phs := groupPhrases(text, cs)
			live, _ := splitRetired(cs)
			switch {
			case len(live) == 0 || len(live) != len(cs):
				c.site(at, KindLink, cs)
			case len(phs) != 1 || phs[0].path || phs[0].oq:
				c.site(at, KindLink, cs)
			default:
				out, bad := textForm(c.tt, live, false)
				if bad != "" {
					c.site(at, bad, cs)
				} else {
					if table {
						out = strings.ReplaceAll(out, "|", `\|`)
					}
					if !c.edit(Edit{Start: base + m[0], End: base + m[1], New: upperIfLead(text, out), Form: FormText}) {
						c.site(at, KindWrapped, cs)
					}
				}
			}
			*done = append(*done, whole)
		case len(refs) > 0 && !refs[0].site && (refs[0].rest == "" || refs[0].rest == "/") && refs[0].end-refs[0].start == len(dest):
			c.entryLink(line, text, refs[0], base, whole, at)
			*done = append(*done, whole)
		case regexp.MustCompile(`^D[0-9]+$`).MatchString(strings.TrimSpace(text)) && strings.Contains(dest, "decisions"):
			c.site(at, KindDecisionAnchor, nil)
			*done = append(*done, whole)
		}
	}
}

func upperIfLead(text, out string) string {
	if startsUpper(strings.TrimLeft(text, "`")) {
		return upperFirst(out)
	}
	return out
}

// onlyCites reports whether text is made of citations and their joiners.
func onlyCites(text string, cs []cites.Cite) bool {
	rest := text
	for i := len(cs) - 1; i >= 0; i-- {
		rest = rest[:cs[i].LeadStart] + " " + rest[cs[i].End:]
	}
	return !hasLetter(strings.NewReplacer("and", "", "or", "").Replace(rest)) &&
		!strings.ContainsAny(rest, "0123456789")
}

// entryLink rewrites a link whose target is the folder of an entry by path.
func (c *ctx) entryLink(line, text string, ref pathRef, base int, whole [2]int, at int) {
	plain := strings.Trim(strings.TrimSpace(text), "`")
	word := "enhancement " + ref.id
	var out string
	switch {
	case plain == ref.id || plain == word || plain == "enhancements/"+ref.id:
		out = word
		if leadWordRe.MatchString(line[:whole[0]]) {
			out = ref.id // "Enhancement [0006](...)": the word is there already
		}
	case strings.Contains(plain, ref.id):
		c.site(at, KindLink, nil)
		return
	default:
		out = text + " (" + word + ")"
	}
	if !c.edit(Edit{Start: base + whole[0], End: base + whole[1], New: out, Form: FormPath}) {
		c.site(at, KindWrapped, nil)
	}
}

// pathsInLine rewrites the entry path references and site URLs of a line
// outside the links already handled.
func (c *ctx) pathsInLine(line string, base int, lc lineCtx, done *[][2]int, spans [][2]int) {
	for _, ref := range findPaths(line) {
		skip := false
		for _, d := range *done {
			if ref.start >= d[0] && ref.end <= d[1] {
				skip = true
			}
		}
		if skip {
			continue
		}
		at := base + ref.start
		switch {
		case ref.site:
			if rest, ok := slugEdit(c.tt, ref); ok {
				from := ref.end - len(ref.rest)
				c.edit(Edit{Start: base + from, End: base + ref.end, New: rest, Form: FormPath})
			}
		case ref.unknownPrefix || ref.rest != "" && ref.rest != "/":
			c.site(at, KindEntryFile, nil)
		default:
			s, e := ref.start, ref.end
			if s > 0 && e < len(line) && line[s-1] == '`' && line[e] == '`' {
				s, e = s-1, e+1
			} else if insideSpan(spans, s, e) {
				c.site(at, KindCodeSpan, nil)
				continue
			}
			out := "enhancement " + ref.id
			if lc.kind == textYAML {
				var ok bool
				if out, ok = fitYAML(lc.yaml, s, out); !ok {
					c.site(at, KindUnsafeYAML, nil)
					continue
				}
			}
			c.edit(Edit{Start: base + s, End: base + e, New: out, Form: FormPath})
		}
	}
}

// commentAfterQuote returns the offset of a " #" comment after the closing
// quote of the quoted scalar that starts at line[start], or -1.
func commentAfterQuote(line string, start int) int {
	q := line[start]
	for i := start + 1; i < len(line); i++ {
		switch {
		case q == '"' && line[i] == '\\':
			i++
		case line[i] == q && q == '\'' && i+1 < len(line) && line[i+1] == '\'':
			i++
		case line[i] == q:
			if j := strings.Index(line[i+1:], " #"); j >= 0 {
				return i + 1 + j
			}
			return -1
		}
	}
	return -1
}
