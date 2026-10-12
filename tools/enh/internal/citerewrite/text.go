package citerewrite

import (
	"regexp"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/citelint"
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
// takes form 2; paths and site URLs form 4. A
// citation that sits in code (a fence, a longer code span, a string) is a
// worklist row.
func processText(name string, src []byte, tt *Titles, kind textKind) FileResult {
	c := newCtx(name, src, tt)
	fence := ""
	blockIndent := -1
	fl := c.flows(kind)
	var cm commentRun
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
		lc := lineCtx{kind: kind, rule: fl.rule[ln]}
		if kind == textYAML {
			lc.yaml, blockIndent = classifyYAML(line, blockIndent)
		}
		if kind == textYAML && fl.cont[ln] && !lc.yaml.block {
			// A line of a plain or quoted scalar that goes on: a "key:" look is
			// text. A title cannot be fitted to it (fitYAML refuses); form 1 can.
			lc.yaml.valueStart, lc.yaml.none, lc.yaml.commentAt = -1, true, -1
			lc.yamlCont = true
		}
		if kind == textMarkdown || kind == textYAML {
			lc.prevCont = fl.cont[ln] && !endsSentenceLine(c.li.text(ln-1))
			lc.nextCont = ln < len(c.li.starts) && fl.cont[ln+1] && !endsSentenceLine(line)
			lc.paraText, lc.paraOff = fl.paraText(c, ln)
		}
		// A comment of a YAML or shell file is a comment, as in Go: the words
		// around the citation state the reason, so it takes form 1 only. The
		// engine of the Go comments reads it.
		trimmed := strings.TrimSpace(line)
		switch {
		case kind == textYAML && !lc.yaml.block && strings.HasPrefix(trimmed, "#"),
			kind == textHash && strings.HasPrefix(trimmed, "#"):
			if ln == 1 && strings.HasPrefix(trimmed, "#!") {
				cm.flush(c)
				continue // the interpreter line
			}
			cm.add(commentLine(line, strings.Index(line, "#"), base, ln))
			continue
		case kind == textYAML && !lc.yaml.block && trimmed == "", kind == textHash && trimmed == "":
			cm.flush(c)
			continue
		case kind == textHash:
			cm.flush(c)
			c.lineSites(line, base, KindString)
			continue
		}
		cm.flush(c)
		if kind == textYAML && lc.yaml.commentAt >= 0 && lc.yaml.commentAt+1 < len(line) && line[lc.yaml.commentAt+1] == '#' {
			// A trailing comment after a value is a paragraph of its own.
			cm.add(commentLine(line, lc.yaml.commentAt+1, base, ln))
			cm.flush(c)
			line = line[:lc.yaml.commentAt]
		}
		c.textLine(line, base, lc)
	}
	cm.flush(c)
	return c.res
}

// lineSites adds a worklist row for each citation phrase of a line, whatever its kind.
func (c *ctx) lineSites(line string, base int, kind string) {
	cs := cites.Scan(line)
	for _, ph := range groupPhrases(line, cs) {
		c.site(base+ph.start, kind, ph.cites)
	}
	c.bareRetired(line, cs, func(i int) int { return base + i })
	if kind != KindGenerated {
		c.oldPathSites(line, func(i int) int { return base + i })
	}
	for _, p := range findPaths(line) {
		if p.rest != "" && p.rest != "/" {
			c.site(base+p.start, KindEntryFile, nil)
		}
	}
}

type lineCtx struct {
	kind textKind
	yaml yamlInfo
	// prevCont is true when the line goes on from the sentence of the line
	// above, nextCont when its sentence goes on in the line below.
	prevCont, nextCont bool
	// rule is true when the paragraph holds a rule keyword (SHALL, MUST): the
	// sentence states a rule and no title goes into it.
	rule bool
	// paraText is the text of the whole paragraph of the line when it has
	// more than one line, and paraOff the offset of the line in it. A sentence
	// can cross a line edge, so the repeat check reads the paragraph.
	paraText string
	paraOff  int
	// yamlCont is true on a line that continues a plain or quoted YAML scalar.
	yamlCont bool
}

// commentRun collects the lines of one comment of a YAML or shell file.
type commentRun struct{ lines []citelint.Line }

func (r *commentRun) add(l citelint.Line) {
	if l.Text == "" {
		return // an empty comment line ends the paragraph at the next flush
	}
	r.lines = append(r.lines, l)
}

// flush hands the collected lines to the engine of code comments.
func (r *commentRun) flush(c *ctx) {
	if len(r.lines) == 0 {
		return
	}
	texts := make([]string, len(r.lines))
	for i, l := range r.lines {
		texts[i] = l.Text
	}
	c.codeParagraph(citelint.Paragraph{Lines: r.lines, Lone: citelint.LoneParagraph(texts)})
	r.lines = nil
}

// commentLine reads a comment that starts with the # at index hash of line.
func commentLine(line string, hash, base, ln int) citelint.Line {
	i := hash
	for i < len(line) && line[i] == '#' {
		i++
	}
	for i < len(line) && (line[i] == ' ' || line[i] == '\t') {
		i++
	}
	return citelint.Line{Line: ln, Text: strings.TrimRight(line[i:], " \t\r"), Off: base + i}
}

var ruleKeywordRe = regexp.MustCompile(`\b(?:SHALL|MUST|SHOULD|REQUIRED)\b`)

// flowInfo says how the lines of a Markdown or YAML file join into
// paragraphs: cont[ln] is true when line ln goes on from line ln-1; para is the
// paragraph number of each line; rule is true on the lines of a paragraph that
// holds a rule keyword.
type flowInfo struct {
	cont  []bool
	para  []int
	rule  []bool
	first map[int]int // paragraph number to its first line
	last  map[int]int
}

var listMarkRe = regexp.MustCompile(`^(?:[-*+]|\d+[.)])[ \t]+`)

// quoteBody reports whether a line is a Markdown quote line, and gives what
// follows the quote marks. A quote can sit in a list item ("- > text").
func quoteBody(line string) (bool, string) {
	t := strings.TrimLeft(line, " \t")
	for {
		m := listMarkRe.FindString(t)
		if m == "" {
			break
		}
		t = strings.TrimLeft(t[len(m):], " \t")
	}
	if strings.HasPrefix(t, ">") {
		return true, strings.TrimLeft(t, "> \t")
	}
	return false, line
}

// flows reads the paragraphs of a Markdown or YAML file. A paragraph is a run
// of prose lines up to a blank line, a heading, a fence, a list item or a table
// row. A quote line follows a quote line. In YAML a line is a paragraph of its
// own, except the lines of a block scalar and the lines that continue a plain
// or quoted scalar (deeper than its key and without a key of their own).
func (c *ctx) flows(kind textKind) *flowInfo {
	n := len(c.li.starts)
	f := &flowInfo{cont: make([]bool, n+2), para: make([]int, n+2), rule: make([]bool, n+2), first: map[int]int{}, last: map[int]int{}}
	kw := map[int]bool{}
	id, blockIndent, scalarIndent := 0, -1, -1
	var quoteOpen byte
	fence := ""
	prevProse, prevQuote := false, false
	for ln := 1; ln <= n; ln++ {
		line := c.li.text(ln)
		prose, cont := false, false
		switch kind {
		case textYAML:
			var info yamlInfo
			info, blockIndent = classifyYAML(line, blockIndent)
			t := strings.TrimSpace(line)
			indent := len(line) - len(strings.TrimLeft(line, " \t"))
			switch {
			case info.block:
				prose, cont = true, prevProse
				scalarIndent, quoteOpen = -1, 0
			case t == "" || info.comment:
				scalarIndent, quoteOpen = -1, 0
			case quoteOpen != 0 && scalarIndent >= 0:
				// A quoted scalar that is still open: the line is its text, whatever it looks like.
				prose, cont = true, true
				if scanQuote(line, quoteOpen) {
					scalarIndent, quoteOpen = -1, 0
				}
			case scalarIndent >= 0 && indent > scalarIndent && info.valueStart < 0 && info.none:
				// Deeper than the key and without a key of its own: the scalar goes on.
				prose, cont = true, true
			default:
				scalarIndent, quoteOpen = -1, 0
				prose = true
				if col, q, ok := yamlScalar(line, info); ok {
					scalarIndent, quoteOpen = col, q
				}
			}
		default:
			if m := fenceRe.FindStringSubmatch(line); m != nil {
				switch {
				case fence == "":
					fence = m[1]
				case m[1][0] == fence[0] && len(m[1]) >= len(fence) && strings.TrimSpace(line) == m[1]:
					fence = ""
				}
				prevQuote = false
				break
			}
			if fence != "" || strings.TrimSpace(line) == "" || headingRe.MatchString(line) {
				prevQuote = false
				break
			}
			quote, body := quoteBody(line)
			prose = strings.TrimSpace(body) != ""
			switch {
			case quote:
				// A quote line follows a quote line; a quote mark ends a plain paragraph.
				cont = prose && prevProse && prevQuote && !startsBlock(body) && !listMarkRe.MatchString(strings.TrimLeft(line, " \t"))
			default:
				// A prose line after a quote line is a lazy continuation of the quote.
				cont = prose && prevProse && !startsBlock(line)
			}
			prevQuote = quote || cont && prevQuote
		}
		prevProse = prose
		f.cont[ln] = cont
		if !cont {
			id++
			f.first[id] = ln
		}
		f.last[id] = ln
		f.para[ln] = id
		if ruleKeywordRe.MatchString(line) {
			kw[id] = true
		}
	}
	for ln := 1; ln <= n; ln++ {
		f.rule[ln] = kw[f.para[ln]]
	}
	return f
}

// paraText returns the text of the paragraph of line ln, lines joined by a
// newline, and the offset of the line in it; "" when the paragraph is one line.
func (f *flowInfo) paraText(c *ctx, ln int) (string, int) {
	p := f.para[ln]
	if f.first[p] == f.last[p] {
		return "", 0
	}
	var b strings.Builder
	off := 0
	for l := f.first[p]; l <= f.last[p]; l++ {
		if l == ln {
			off = b.Len()
		}
		b.WriteString(c.li.text(l))
		b.WriteByte('\n')
	}
	return b.String(), off
}

// repeatsIn is repeats for the paragraph of a line: a sentence can cross a line
// edge, and the id may sit on the other line.
func (c *ctx) repeatsIn(line string, phs []phrase, idx int, ids []string, lc lineCtx) (named []bool, any, all bool) {
	if lc.paraText == "" {
		return repeats(line, phs, idx, ids)
	}
	pt := lc.paraText
	pp := groupPhrases(pt, cites.Scan(pt))
	for k, p := range pp {
		if p.start == phs[idx].start+lc.paraOff {
			return repeats(pt, pp, k, ids)
		}
	}
	return repeats(line, phs, idx, ids)
}

var blockStartRe = regexp.MustCompile(`^\s*(?:[-*+]\s|\d+[.)]\s|\||#)`)

// startsBlock reports whether a line opens a new block (a list item, a table
// row, a quote, a heading) and so does not continue the line above.
func startsBlock(line string) bool { return blockStartRe.MatchString(line) }

// endsSentenceLine reports whether a line ends with a mark that closes a
// sentence or introduces a list.
func endsSentenceLine(line string) bool {
	t := strings.TrimRight(line, " \t")
	return t == "" || strings.ContainsRune(".!?:", rune(t[len(t)-1]))
}

// yamlScalar says whether the line opens a plain or quoted scalar that can go
// on in the lines below. col is the column of its key (after any "- "): a
// continuation line is deeper than that. quote is the quote mark of a quoted
// scalar that the line leaves open, or 0. An empty value, an anchor, a tag or an
// alias alone opens no scalar: the lines below are its children or its siblings.
func yamlScalar(line string, info yamlInfo) (col int, quote byte, ok bool) {
	if info.valueStart < 0 || info.valueStart >= len(line) || info.flow || yamlBlockRe.MatchString(line) {
		return 0, 0, false
	}
	indent := len(line) - len(strings.TrimLeft(line, " \t"))
	col = indent
	if m := yamlKeyRe.FindStringSubmatchIndex(line); m != nil {
		col = m[3]
	}
	v := strings.TrimSpace(line[info.valueStart:])
	for {
		m := yamlPropRe.FindString(v)
		if m == "" {
			break
		}
		v = strings.TrimSpace(v[len(m):])
	}
	if v == "" || strings.HasPrefix(v, "#") {
		return 0, 0, false
	}
	if info.quote != 0 && !scanQuote(line[info.valueStart+1:], info.quote) {
		return col, info.quote, true
	}
	return col, 0, true
}

var yamlPropRe = regexp.MustCompile(`^[&!*][^\s]*(?:\s+|$)`)

// scanQuote reports whether the quoted scalar closes in s, the text after the
// opening quote (or a continuation line).
func scanQuote(s string, q byte) bool {
	for i := 0; i < len(s); i++ {
		switch {
		case q == '"' && s[i] == '\\':
			i++
		case s[i] == q && q == '\'' && i+1 < len(s) && s[i+1] == q:
			i++
		case s[i] == q:
			return true
		}
	}
	return false
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
	// An anchor, a tag or an alias before the value is not the value.
	for {
		m := yamlPropRe.FindString(line[rest:])
		if m == "" {
			break
		}
		rest += len(m)
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
	c.oldPathSites(line, func(i int) int { return base + i })

	if lc.kind == textMarkdown {
		c.linksInLine(line, base, &done, table)
	}

	spans := codeSpans(line, lc.kind == textMarkdown)
	cs := cites.Scan(line)
	phs := groupPhrases(line, cs)
	for idx, ph := range phs {
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
		case len(live) < len(ph.cites):
			// A citation of 0030 or 0031 is never removed: either id may name a
			// new entry. An agent reads the sentence.
			c.site(at, KindRetiredInline, ph.cites)
		case ph.glued:
			c.site(at, KindInline, ph.cites)
		case insideSpan(spans, ph.start, ph.end):
			c.site(at, KindCodeSpan, ph.cites)
		case ph.possessive:
			c.site(at, KindPossessive, ph.cites)
		default:
			c.proseEdit(line, base, lc, phs, idx, live, table)
		}
	}
	c.bareRetired(line, cs, func(i int) int { return base + i })
	c.pathsInLine(line, base, lc, &done, spans)
}

// A requirement range or contrast ("R3 to R5", "R3, not R4") gives its title
// once. When a line break falls inside it the tool cannot tell the two ends
// from two sentences, so the site is a worklist row.
var (
	// wrapTailRe matches what may follow a phrase at the end of a line: nothing,
	// a comma, or a connector word.
	wrapTailRe = regexp.MustCompile(`^[ \t]*(?:,[ \t]*)?(to|through|not|but not|and not|and|or|up to|rather than|rather|vs\.?|versus|-|\x{2013}|\x{2014})?[ \t]*$`)
	// wrapHeadRe matches the start of the next line: a connector and an end of
	// the range, or an end of the range alone.
	wrapHeadRe = regexp.MustCompile(`^(?:(?:to|through|not|but not|and not|up to|rather than|than|and|or|vs\.?|versus|-|\x{2013}|\x{2014})[ \t]+)?(?:R[0-9]+|[0-9]{4}:)`)
	wrapEndRe  = regexp.MustCompile(`^(?:R[0-9]+|[0-9]{4}:)`)
)

// rangeSplit reports whether a line break separates the phrase that ends at
// ph.end from the other end of a range.
func rangeSplit(line string, ph phrase, lc lineCtx) bool {
	if !lc.nextCont {
		return false
	}
	m := wrapTailRe.FindStringSubmatch(line[ph.end:])
	if m == nil {
		return false
	}
	next := nextLineBody(lc)
	switch m[1] {
	case "":
		return wrapHeadRe.MatchString(next)
	case "and", "or":
		return wrapEndRe.MatchString(next)
	}
	return true // "to", "-", "not", "up to", "rather", ...: a connector ends the line
}

// nextLineBody returns the line below the line in the paragraph, without quote
// marks.
func nextLineBody(lc lineCtx) string {
	i := strings.IndexByte(lc.paraText[lc.paraOff:], '\n')
	if lc.paraText == "" || i < 0 {
		return ""
	}
	rest := lc.paraText[lc.paraOff+i+1:]
	if j := strings.IndexByte(rest, '\n'); j >= 0 {
		rest = rest[:j]
	}
	_, body := quoteBody(rest)
	return strings.TrimLeft(body, " \t")
}

// proseEdit writes form 2 for a phrase of live citations.
func (c *ctx) proseEdit(line string, base int, lc lineCtx, phs []phrase, idx int, live []cites.Cite, table bool) {
	ph := phs[idx]
	at := base + ph.cites[0].Start
	if rangeSplit(line, ph, lc) {
		c.site(at, KindWrapped, ph.cites)
		return
	}
	if lc.rule {
		c.ruleEdit(line, base, lc, phs, idx, live)
		return
	}
	ls := extendLeadin(line, ph.start)
	b := trimBackSpaces(line, ls)
	a := skipSpaces(line, ph.end)
	start, end, compact := ph.start, ph.end, false
	if b > 0 && line[b-1] == '(' && a < len(line) && line[a] == ')' {
		// A parenthesis that holds only the citation: no nested parentheses.
		start, end, compact = b, a, true
	}
	text, bad := textForm(c.tt, live, compact)
	if ids, rbad := resolvedIDs(c.tt, live); bad == "" && rbad == "" {
		if named, any, _ := c.repeatsIn(line, phs, idx, ids, lc); any {
			// The sentence names the enhancement already. "enhancement 0001
			// (0001:D3)" keeps its id and gains the title; any other repeat is
			// for an agent.
			open := strings.TrimRight(line[:b-btoi(compact)], " \t")
			if compact && len(ids) == 1 && named[0] && strings.HasSuffix(open, ids[0]) {
				text = strings.TrimPrefix(text, "enhancement "+ids[0]+", ")
			} else {
				c.site(at, KindRepeatID, ph.cites)
				return
			}
		}
	}
	if bad != "" {
		c.site(at, bad, ph.cites)
		return
	}
	if !compact && (startsUpper(line[ph.start:]) || ls == ph.start && sentenceStartAt(line, ph.start, lc.prevCont)) {
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

// ruleEdit writes form 1 for a citation in a sentence that states a rule: the
// sentence already says what the rule is, so a decision title does not go in.
// When no safe shape fits, the site is a worklist row.
func (c *ctx) ruleEdit(line string, base int, lc lineCtx, phs []phrase, idx int, live []cites.Cite) {
	ph := phs[idx]
	at := base + ph.cites[0].Start
	ids, bad := resolvedIDs(c.tt, live)
	if bad != "" {
		c.site(at, bad, ph.cites)
		return
	}
	e, ok := formOneEdit(line, ph, canonicalIDs(ids), lc.nextCont)
	if !ok {
		c.site(at, KindRuleSentence, ph.cites)
		return
	}
	if _, any, all := c.repeatsIn(line, phs, idx, ids, lc); any {
		d, ok := dropEdit(line, e)
		if !all || !ok {
			c.site(at, KindRepeatID, ph.cites)
			return
		}
		e = d
	}
	if lc.kind == textYAML && !lc.yamlCont {
		if _, ok := fitYAML(lc.yaml, ph.start, e.New); !ok {
			c.site(at, KindUnsafeYAML, ph.cites)
			return
		}
	}
	if !c.edit(Edit{Start: base + e.Start, End: base + e.End, New: e.New, Form: FormCodeComment}) {
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
				if insideSpan(spans, ref.start, ref.end) {
					// A URL in code is an example (often of the retired slug
					// itself): the words around it decide, not the table.
					c.site(at, KindCodeSpan, nil)
					continue
				}
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

func btoi(b bool) int {
	if b {
		return 1
	}
	return 0
}
