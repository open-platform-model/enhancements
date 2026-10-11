// Package citelint checks the comments of Go and CUE files for the citation
// rules of the enhancement format (T2.2 section 5, T2.3 sections 6 and 9):
//
//   - no decision number (NNNN:Dn, NNNN:Dn:Rn, NNNN:OQn, and the spoken forms
//     NNNN Dn, "enhancement NNNN D4 and D7", NNNN D3/D15), in a comment or in
//     a string literal;
//   - no comment that is only an id;
//   - no "WHY name: id" label.
//
// An id beside a reason in words passes, for one id or for several written
// "(enhancements 0010 and 0026)".
package citelint

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/cites"
)

// Rule names.
const (
	RuleDecisionNumber = "decision-number"
	RuleLoneID         = "lone-id"
	RuleWhyLabel       = "why-label"
)

// Finding is one violation.
type Finding struct {
	Path    string
	Line    int
	Rule    string
	Text    string
	Message string
}

func (f Finding) String() string {
	return fmt.Sprintf("%s:%d: %s: %s", f.Path, f.Line, f.Rule, f.Message)
}

// Options tunes a run.
type Options struct {
	// Exclude holds slash-separated patterns. A pattern matches a whole
	// path, a base name, or, when it ends in "/", a directory at any depth.
	Exclude []string
	// SkipStrings turns the decision-number rule off for string literals.
	SkipStrings bool
}

// Result is the outcome of LintFiles.
type Result struct {
	Findings []Finding
	// Checked counts the Go and CUE files that were read and linted.
	Checked int
	// Skipped counts files left out: other languages, excluded paths and
	// generated Go files.
	Skipped int
}

var (
	// An id with an optional decision suffix and slash continuations
	// (NNNN:Dn/OQn). Ids start with 0 (0001 to 0999), so a year or a
	// port number is not an id.
	idRe = regexp.MustCompile(`\b0\d{3}(?::(?:D\d+(?::R\d+)?|OQ\d+))?(?:/(?:D|R|OQ)\d+)*\b`)

	// Words that link ids and carry no reason.
	linkWordRe = regexp.MustCompile(`(?i)\b(?:enhancements?|see|and|or|per|cf|refs?|also|as|amended|by)\b`)

	whyRe = regexp.MustCompile(`^WHY\s+([^:\s]+)\s*:\s*(.*)$`)

	generatedRe = regexp.MustCompile(`^// Code generated .* DO NOT EDIT\.$`)
)

// onlyIDs reports whether text holds at least one id and nothing else but
// linking words and punctuation.
func onlyIDs(text string) bool {
	text = collapseCites(text)
	if !idRe.MatchString(text) {
		return false
	}
	rest := idRe.ReplaceAllString(text, " ")
	rest = linkWordRe.ReplaceAllString(rest, " ")
	for _, r := range rest {
		if r >= '0' && r <= '9' || r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r > 127 {
			return false
		}
	}
	return true
}

// collapseCites replaces every citation, spoken ones included, by its bare
// id, so that "(0010 D49)" counts as an id like "(0010)".
func collapseCites(text string) string {
	cs := cites.Scan(text)
	if len(cs) == 0 {
		return text
	}
	var b strings.Builder
	last := 0
	for _, c := range cs {
		b.WriteString(text[last:c.Start])
		b.WriteString(c.ID)
		last = c.End
	}
	b.WriteString(text[last:])
	return b.String()
}

type textLine struct {
	line int
	text string
	// off is the byte offset of text in the source file.
	off int
}

// group is one comment as a reader sees it: consecutive own-line // comments
// at one column, a trailing // comment, or a block comment.
type group struct {
	lines []textLine
}

func (g group) joined() string {
	parts := make([]string, len(g.lines))
	for i, l := range g.lines {
		parts[i] = l.text
	}
	return strings.Join(parts, " ")
}

// paragraphs splits a comment at its blank lines. A paragraph that holds
// only an id fails even when other paragraphs in the same comment hold words
// (the owner's rule: an id is never alone).
func (g group) paragraphs() []group {
	var out []group
	var cur []textLine
	flush := func() {
		if len(cur) > 0 {
			out = append(out, group{lines: cur})
			cur = nil
		}
	}
	for _, l := range g.lines {
		if l.text == "" {
			flush()
			continue
		}
		cur = append(cur, l)
	}
	flush()
	return out
}

// trimStar strips the blanks and one leading star of a block comment line,
// and returns the text and the count of bytes cut from its start.
func trimStar(raw string) (string, int) {
	cut := len(raw) - len(strings.TrimLeft(raw, " \t"))
	rest := raw[cut:]
	if strings.HasPrefix(rest, "*") {
		rest = rest[1:]
		cut++
		n := len(rest) - len(strings.TrimLeft(rest, " \t"))
		cut += n
		rest = rest[n:]
	}
	return strings.TrimSpace(rest), cut
}

func buildGroups(spans []span) []group {
	var groups []group
	var cur *group
	lastLine, lastCol := -1, -1
	flush := func() {
		if cur != nil {
			groups = append(groups, *cur)
			cur = nil
		}
	}
	for _, s := range spans {
		if !s.isComment {
			flush()
			continue
		}
		if s.block {
			flush()
			g := group{}
			off := s.pos
			for i, raw := range strings.Split(s.text, "\n") {
				l, skip := trimStar(raw)
				g.lines = append(g.lines, textLine{s.line + i, l, off + skip})
				off += len(raw) + 1
			}
			groups = append(groups, g)
			continue
		}
		tl := textLine{s.line, strings.TrimSpace(s.text), s.pos + len(s.text) - len(strings.TrimLeft(s.text, " \t"))}
		if s.ownLine && cur != nil && s.line == lastLine+1 && s.col == lastCol {
			cur.lines = append(cur.lines, tl)
		} else {
			flush()
			cur = &group{lines: []textLine{tl}}
		}
		if s.ownLine {
			lastLine, lastCol = s.line, s.col
		} else {
			// A trailing comment never joins another one.
			flush()
			lastLine, lastCol = -1, -1
		}
	}
	flush()
	return groups
}

func languageOf(name string) (language, bool) {
	lower := strings.ToLower(filepath.ToSlash(name))
	if strings.HasSuffix(lower, ".cue.tmpl") {
		// A CUE template (library render.cue.tmpl) holds // comments.
		return langCUE, true
	}
	switch path.Ext(lower) {
	case ".go":
		return langGo, true
	case ".cue":
		return langCUE, true
	}
	return 0, false
}

// LintSource lints one file given as bytes. name decides the language by its
// extension (.go or .cue); another extension yields no finding.
func LintSource(name string, src []byte, opts Options) []Finding {
	lang, ok := languageOf(name)
	if !ok {
		return nil
	}
	spans := lex(string(src), lang)
	var out []Finding
	add := func(line int, rule, text, msg string) {
		out = append(out, Finding{Path: name, Line: line, Rule: rule, Text: text, Message: msg})
	}

	decisions := func(line int, text string) {
		for _, ct := range cites.Scan(text) {
			shown := strings.Trim(ct.Text, "`")
			add(line, RuleDecisionNumber, shown,
				fmt.Sprintf("decision number %s: write the reason in words and name the enhancement (enhancement NNNN)", shown))
		}
	}
	for _, s := range spans {
		if s.isComment {
			continue
		}
		if opts.SkipStrings {
			continue
		}
		for i, l := range strings.Split(s.text, "\n") {
			decisions(s.line+i, l)
		}
	}

	for _, g := range buildGroups(spans) {
		for _, para := range g.paragraphs() {
			why := false
			for _, l := range para.lines {
				decisions(l.line, l.text)
				if m := whyRe.FindStringSubmatch(l.text); m != nil && onlyIDs(m[2]) {
					why = true
					add(l.line, RuleWhyLabel, l.text,
						fmt.Sprintf("WHY label %q holds only an id: state the reason in words", m[1]))
				}
			}
			// A paragraph is the unit of "never alone": an id on a line of
			// its own passes only when the paragraph around it says why.
			if !why && onlyIDs(para.joined()) {
				add(para.lines[0].line, RuleLoneID, para.joined(),
					"comment is only an id: write the reason in words beside the id")
			}
		}
	}

	sort.SliceStable(out, func(i, j int) bool { return out[i].Line < out[j].Line })
	return out
}

// isGenerated reports whether a Go file carries the generated-code header
// before its package clause.
func isGenerated(src []byte) bool {
	for _, l := range strings.Split(string(src), "\n") {
		if generatedRe.MatchString(strings.TrimRight(l, "\r")) {
			return true
		}
		if strings.HasPrefix(l, "package ") {
			return false
		}
	}
	return false
}

func excluded(p string, pats []string) bool {
	p = filepath.ToSlash(p)
	for _, pat := range pats {
		if strings.HasSuffix(pat, "/") {
			if strings.HasPrefix(p, pat) || strings.Contains(p, "/"+pat) {
				return true
			}
			continue
		}
		if ok, _ := path.Match(pat, p); ok {
			return true
		}
		if ok, _ := path.Match(pat, path.Base(p)); ok {
			return true
		}
	}
	return false
}

// skipDir names the directories a walk never enters: version control, vendored
// code, the CUE caches, agent worktrees and the swarm folder.
func skipDir(rel string) bool {
	base := path.Base(rel)
	switch base {
	case ".git", "node_modules", "vendor", ".cue-cache", "agent-swarm":
		return true
	}
	if strings.HasPrefix(rel, ".claude/worktrees") {
		return true
	}
	return strings.HasPrefix(rel, "cue.mod/pkg") || strings.HasPrefix(rel, "cue.mod/gen") ||
		strings.HasPrefix(rel, "cue.mod/usr") || strings.Contains(rel, "/cue.mod/pkg") ||
		strings.Contains(rel, "/cue.mod/gen") || strings.Contains(rel, "/cue.mod/usr")
}

// Skipped reports whether a file path (slash-separated, relative to the repo
// root) is outside every citation tool: release-please history (CHANGELOG.md)
// and anything under a directory that skipDir names (vendor/**, agent-swarm/,
// .claude/worktrees/, the CUE caches). A walk never enters such a directory;
// this check covers a file named in a path list.
func Skipped(rel string) bool {
	rel = filepath.ToSlash(rel)
	if path.Base(rel) == "CHANGELOG.md" {
		return true
	}
	parts := strings.Split(rel, "/")
	for i := range parts[:len(parts)-1] {
		if skipDir(strings.Join(parts[:i+1], "/")) {
			return true
		}
	}
	return false
}

// underRoot returns p relative to root when p is an absolute path inside it,
// so that a directory name above the root (the swarm folder) never counts.
func underRoot(root, p string) string {
	if !filepath.IsAbs(p) {
		return p
	}
	r, err := filepath.Rel(root, p)
	if err != nil || r == ".." || strings.HasPrefix(r, "../") {
		return p
	}
	return r
}

// LintFiles lints a list of paths relative to root (or absolute). A path
// that names a directory is walked. A path that cannot be read is an error:
// a lint that skips a file in silence passes what it did not see.
func LintFiles(root string, paths []string, opts Options) (Result, error) {
	var res Result
	var errs []error

	lintOne := func(rel string) {
		if excluded(rel, opts.Exclude) || Skipped(underRoot(root, rel)) {
			res.Skipped++
			return
		}
		if _, ok := languageOf(rel); !ok {
			res.Skipped++
			return
		}
		full := rel
		if !filepath.IsAbs(rel) {
			full = filepath.Join(root, rel)
		}
		src, err := os.ReadFile(full)
		if err != nil {
			errs = append(errs, err)
			return
		}
		if lang, _ := languageOf(rel); lang == langGo && isGenerated(src) {
			res.Skipped++
			return
		}
		res.Checked++
		res.Findings = append(res.Findings, LintSource(filepath.ToSlash(rel), src, opts)...)
	}

	for _, p := range paths {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		full := p
		if !filepath.IsAbs(p) {
			full = filepath.Join(root, p)
		}
		info, err := os.Stat(full)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		if !info.IsDir() {
			lintOne(p)
			continue
		}
		walkErr := filepath.WalkDir(full, func(fp string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			rel, rerr := filepath.Rel(root, fp)
			if rerr != nil || filepath.IsAbs(p) {
				rel = fp
			}
			rel = filepath.ToSlash(rel)
			if d.IsDir() {
				if skipDir(rel) || excluded(rel+"/", opts.Exclude) {
					return filepath.SkipDir
				}
				return nil
			}
			lintOne(rel)
			return nil
		})
		if walkErr != nil {
			errs = append(errs, walkErr)
		}
	}
	sort.SliceStable(res.Findings, func(i, j int) bool {
		if res.Findings[i].Path != res.Findings[j].Path {
			return res.Findings[i].Path < res.Findings[j].Path
		}
		return res.Findings[i].Line < res.Findings[j].Line
	})
	return res, errors.Join(errs...)
}

// ReadFileList reads a list of paths, one per line (the output of
// "git ls-files") or separated by NUL bytes ("git ls-files -z"). Blank lines
// are dropped.
func ReadFileList(r io.Reader) ([]string, error) {
	data, err := io.ReadAll(r)
	if err != nil {
		return nil, err
	}
	sep := "\n"
	if bytes.IndexByte(data, 0) >= 0 {
		sep = "\x00"
	}
	var out []string
	for _, p := range strings.Split(string(data), sep) {
		p = strings.TrimRight(p, "\r")
		if strings.TrimSpace(p) == "" {
			continue
		}
		out = append(out, p)
	}
	return out, nil
}
