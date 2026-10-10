// Package cueschema checks a new-layout config.yaml against #EntryConfig in
// the repository's schema.cue, and reads the reserved and blocked id lists
// from the same file. This is the only package that imports CUE.
package cueschema

import (
	"fmt"
	"os"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	cueerrors "cuelang.org/go/cue/errors"
	cueyaml "cuelang.org/go/encoding/yaml"
)

// Issue is one schema error.
type Issue struct {
	// Field is the top-level field the error is about, empty when the error
	// is about the whole file.
	Field string
	// Path is the full path of the error inside the document.
	Path []string
	Msg  string
}

// Schema is a compiled schema.cue.
type Schema struct {
	ctx *cue.Context
	def cue.Value
	// Reserved and Blocked are the id lists of schema.cue.
	Reserved, Blocked []string
}

// Load compiles the schema file at path.
func Load(path string) (*Schema, error) {
	src, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	ctx := cuecontext.New()
	v := ctx.CompileBytes(src, cue.Filename(path))
	if err := v.Err(); err != nil {
		return nil, fmt.Errorf("compile %s: %s", path, cueerrors.Details(err, nil))
	}
	def := v.LookupPath(cue.ParsePath("#EntryConfig"))
	if !def.Exists() {
		return nil, fmt.Errorf("%s: #EntryConfig is not defined", path)
	}
	s := &Schema{ctx: ctx, def: def}
	if s.Reserved, err = stringList(v, "reservedIds"); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if s.Blocked, err = stringList(v, "blockedIds"); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return s, nil
}

func stringList(v cue.Value, name string) ([]string, error) {
	l := v.LookupPath(cue.ParsePath(name))
	if !l.Exists() {
		return nil, fmt.Errorf("%s is not defined", name)
	}
	var out []string
	if err := l.Decode(&out); err != nil {
		return nil, fmt.Errorf("%s: %w", name, err)
	}
	return out, nil
}

// CheckConfig validates the text of a config.yaml and returns every error.
// An empty slice means the file satisfies #EntryConfig.
func (s *Schema) CheckConfig(src []byte) []Issue {
	f, err := cueyaml.Extract("config.yaml", src)
	if err != nil {
		return []Issue{{Msg: "not valid YAML: " + firstLine(err.Error())}}
	}
	data := s.ctx.BuildFile(f)
	if err := data.Err(); err != nil {
		return []Issue{{Msg: "cannot read config.yaml: " + firstLine(err.Error())}}
	}
	err = s.def.Unify(data).Validate(cue.Concrete(true), cue.All())
	if err == nil {
		return nil
	}
	type raw struct {
		path []string
		msg  string
	}
	var all []raw
	var conflicts []raw // "conflicting values A and B" errors
	heads := map[string]bool{}
	for _, e := range cueerrors.Errors(err) {
		format, args := e.Msg()
		msg := fmt.Sprintf(format, args...)
		path := e.Path()
		if len(path) > 0 && path[0] == "#EntryConfig" {
			path = path[1:]
		}
		switch {
		case strings.HasPrefix(msg, "conflicting values "):
			conflicts = append(conflicts, raw{path, msg})
		default:
			if strings.Contains(msg, "errors in empty disjunction") {
				heads[strings.Join(path, ".")] = true
			}
			all = append(all, raw{path, msg})
		}
	}
	// A conflict at the path of a disjunction head is one arm of that
	// disjunction: the head reports it, with the refused value. A conflict
	// anywhere else is a type error on a plain field and stays an issue.
	refused := map[string][]string{} // path -> operand pairs
	for _, c := range conflicts {
		key := strings.Join(c.path, ".")
		if heads[key] {
			refused[key] = append(refused[key], c.msg)
			continue
		}
		all = append(all, c)
	}
	var out []Issue
	seen := map[string]bool{}
	for _, r := range all {
		msg, path := r.msg, r.path
		if strings.Contains(msg, "errors in empty disjunction") {
			if v := refusedValue(refused[strings.Join(path, ".")]); v != "" {
				msg = fmt.Sprintf("value %s is not one of the allowed values", v)
			}
		}
		key := strings.Join(path, ".") + "|" + msg
		if seen[key] {
			continue
		}
		seen[key] = true
		is := Issue{Path: path, Msg: msg}
		if len(path) > 0 {
			is.Field = path[0]
		} else if name, ok := strings.CutPrefix(msg, "required field missing: "); ok {
			is.Field = name
		}
		out = append(out, is)
	}
	return out
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}

// refusedValue finds the value the data holds in the arms of a disjunction:
// the operand that all the "conflicting values A and B" messages share.
func refusedValue(msgs []string) string {
	var pairs [][2]string
	for _, m := range msgs {
		m = strings.TrimPrefix(m, "conflicting values ")
		if i := strings.LastIndex(m, " (mismatched types"); i >= 0 {
			m = m[:i]
		}
		if i := strings.Index(m, " and "); i >= 0 {
			pairs = append(pairs, [2]string{m[:i], m[i+5:]})
		}
	}
	if len(pairs) == 0 {
		return ""
	}
	if len(pairs) > 1 {
		count := map[string]int{}
		for _, p := range pairs {
			count[p[0]]++
			count[p[1]]++
		}
		for _, p := range pairs {
			for _, v := range p {
				if count[v] == len(pairs) {
					return v
				}
			}
		}
	}
	return pairs[0][1]
}
