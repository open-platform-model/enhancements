package citelint

import "strings"

// The rest of this file is the surface that the rewrite tool
// (internal/citerewrite) uses, so that it reads comments exactly as the lint
// does: one lexer, one grouping into paragraphs, one rule for a lone id.

// IsCode reports whether a file name is a Go or CUE source for the lint.
func IsCode(name string) bool {
	_, ok := languageOf(name)
	return ok
}

// IsGo reports whether a file name is a Go source.
func IsGo(name string) bool {
	lang, ok := languageOf(name)
	return ok && lang == langGo
}

// Line is one line of a comment as a reader sees it.
type Line struct {
	// Line is the 1-based line of the source file.
	Line int
	// Text is the line without its comment markers and outer blanks.
	Text string
	// Off is the byte offset of Text in the source file.
	Off int
}

// Paragraph is the unit of the lone-id rule: the lines of one comment between
// blank lines.
type Paragraph struct {
	Lines []Line
	// Lone is true when the paragraph holds only ids and linking words, or
	// has a "WHY name: id" label (the lint fails both).
	Lone bool
}

// Joined returns the lines joined by one blank, as the lint reads them.
func (p Paragraph) Joined() string {
	parts := make([]string, len(p.Lines))
	for i, l := range p.Lines {
		parts[i] = l.Text
	}
	return strings.Join(parts, " ")
}

// String is a string literal found in a source file.
type String struct {
	Line int
	// Text is the raw source between the quotes.
	Text string
	// Off is the byte offset of Text in the source file.
	Off int
}

// Parse lexes a Go or CUE source into the paragraphs of its comments and its
// string literals. The language comes from name; another extension returns
// ok false.
func Parse(name string, src []byte) (paras []Paragraph, strs []String, ok bool) {
	lang, ok := languageOf(name)
	if !ok {
		return nil, nil, false
	}
	spans := lex(string(src), lang)
	for _, s := range spans {
		if !s.isComment {
			strs = append(strs, String{Line: s.line, Text: s.text, Off: s.pos})
		}
	}
	for _, g := range buildGroups(spans) {
		for _, para := range g.paragraphs() {
			p := Paragraph{}
			var texts []string
			for _, l := range para.lines {
				p.Lines = append(p.Lines, Line{Line: l.line, Text: l.text, Off: l.off})
				texts = append(texts, l.text)
			}
			p.Lone = LoneParagraph(texts)
			paras = append(paras, p)
		}
	}
	return paras, strs, true
}

// IsGeneratedSource reports whether a Go file carries the generated-code
// header before its package clause.
func IsGeneratedSource(src []byte) bool { return isGenerated(src) }

// UnderRoot returns p relative to root when p is an absolute path inside it.
func UnderRoot(root, p string) string { return underRoot(root, p) }

// Excluded reports whether a path matches one of the patterns, with the
// semantics of the --exclude flag.
func Excluded(p string, pats []string) bool { return excluded(p, pats) }

// SkipDir reports whether a walk never enters the directory. named is true for
// the root of a walk that the caller named: a folder .claude is entered then.
func SkipDir(rel string, named bool) bool { return skipDirAt(rel, named) }

// OnlyIDs reports whether text holds at least one id and nothing else but
// linking words and punctuation: the lint's lone-id test.
func OnlyIDs(text string) bool { return onlyIDs(text) }

// LoneParagraph reports whether the lines of one comment paragraph hold only
// ids and linking words, or a "WHY name: id" label (the lint fails both).
func LoneParagraph(lines []string) bool {
	for _, l := range lines {
		if m := whyRe.FindStringSubmatch(l); m != nil && onlyIDs(m[2]) {
			return true
		}
	}
	return onlyIDs(strings.Join(lines, " "))
}
