package citelint

import "strings"

// language selects the lexical rules of a source file.
type language int

const (
	langGo language = iota
	langCUE
)

// span is a comment or a string literal found in a source file.
type span struct {
	isComment bool
	// line is the 1-based line where the text starts.
	line int
	// col is the 0-based column where the span starts.
	col int
	// ownLine is true when only blanks precede a line comment on its line.
	ownLine bool
	// block is true for a /* */ comment.
	block bool
	// text is the content: for a comment without its markers, for a string
	// the raw source between the quotes.
	text string
}

// lex returns the comments and string literals of src, in source order.
// It is not a parser: it follows only what decides where a comment or a
// string starts and ends.
func lex(src string, lang language) []span {
	var out []span
	line, lineStart := 1, 0
	i := 0
	n := len(src)

	// blankBefore reports whether src[lineStart:pos] holds only blanks.
	blankBefore := func(pos int) bool {
		return strings.TrimLeft(src[lineStart:pos], " \t") == ""
	}

	for i < n {
		c := src[i]
		switch {
		case c == '\n':
			line++
			i++
			lineStart = i
		case c == '/' && i+1 < n && src[i+1] == '/':
			end := strings.IndexByte(src[i:], '\n')
			if end < 0 {
				end = n - i
			}
			out = append(out, span{
				isComment: true, line: line, col: i - lineStart,
				ownLine: blankBefore(i), text: src[i+2 : i+end],
			})
			i += end
		case c == '/' && i+1 < n && src[i+1] == '*' && lang == langGo:
			end := strings.Index(src[i+2:], "*/")
			stop := n
			body := src[i+2:]
			if end >= 0 {
				stop = i + 2 + end + 2
				body = src[i+2 : i+2+end]
			}
			out = append(out, span{
				isComment: true, line: line, col: i - lineStart,
				ownLine: blankBefore(i), block: true, text: body,
			})
			for j := i; j < stop; j++ {
				if src[j] == '\n' {
					line++
					lineStart = j + 1
				}
			}
			i = stop
		case c == '`' && lang == langGo:
			end := strings.IndexByte(src[i+1:], '`')
			stop := n
			body := src[i+1:]
			if end >= 0 {
				stop = i + 1 + end + 1
				body = src[i+1 : i+1+end]
			}
			out = append(out, span{line: line, col: i - lineStart, text: body})
			for j := i; j < stop; j++ {
				if src[j] == '\n' {
					line++
					lineStart = j + 1
				}
			}
			i = stop
		case c == '"' || (c == '\'' && lang == langGo) || (lang == langCUE && (c == '\'' || c == '#')):
			s, stop, ok := lexQuoted(src, i, lang)
			if !ok {
				i++
				continue
			}
			s.line, s.col = line, i-lineStart
			out = append(out, s)
			for j := i; j < stop; j++ {
				if src[j] == '\n' {
					line++
					lineStart = j + 1
				}
			}
			i = stop
		default:
			i++
		}
	}
	return out
}

// lexQuoted reads a string or rune literal that starts at src[i]. CUE strings
// may start with hashes (#"..."#), use a single quote for bytes and three double or
// three single quotes for multi-line text. It returns the literal, the index after it, and false when
// src[i] does not start a literal.
func lexQuoted(src string, i int, lang language) (span, int, bool) {
	hashes := 0
	j := i
	if lang == langCUE {
		for j < len(src) && src[j] == '#' {
			hashes++
			j++
		}
	}
	if j >= len(src) || (src[j] != '"' && src[j] != '\'') {
		return span{}, 0, false
	}
	q := src[j]
	quote := string(q)
	if lang == langCUE && strings.HasPrefix(src[j:], strings.Repeat(quote, 3)) {
		quote = strings.Repeat(quote, 3)
	}
	closer := quote + strings.Repeat("#", hashes)
	escape := `\` + strings.Repeat("#", hashes)
	multi := len(quote) == 3
	k := j + len(quote)
	start := k
	for k < len(src) {
		switch {
		case strings.HasPrefix(src[k:], escape) && k+len(escape) < len(src):
			k += len(escape) + 1
		case strings.HasPrefix(src[k:], closer):
			return span{text: src[start:k]}, k + len(closer), true
		case src[k] == '\n' && !multi:
			// An unterminated line literal: stop at the line end.
			return span{text: src[start:k]}, k, true
		default:
			k++
		}
	}
	return span{text: src[start:]}, len(src), true
}
