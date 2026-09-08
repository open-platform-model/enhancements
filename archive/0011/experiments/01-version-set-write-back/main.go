// Command main implements `opm catalog version set <semver>` as a surgical
// AST edit: locate the tool-owned version field by its @opm() marker, replace
// only the concrete operand of its value, and write the file back.
//
// It also implements the naive alternative — replace the whole value — so the
// two can be diffed against each other rather than argued about.
//
// It is a DEMONSTRATION, not production code.
package main

import (
	"fmt"
	"os"
	"strings"

	"cuelang.org/go/cue/ast"
	"cuelang.org/go/cue/format"
	"cuelang.org/go/cue/parser"
	"cuelang.org/go/cue/token"
)

const marker = "opm"

type result struct {
	Found   bool   // a field OPM owns and may write a version into
	Route   string // how it was found: "role" or "name-fallback"
	Field   string // the field's name, for the report
	Pos     string // file:line:col of the declaration
	Was     string // the value expression before
	Now     string // the value expression after
	Changed bool   // false when the value already equalled the target
	Bytes   []byte // the rewritten file, when Changed
	Refusal string // set when the command must refuse
}

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: version-set <file.cue> <semver> [--naive]")
		os.Exit(2)
	}
	path, version := os.Args[1], os.Args[2]
	naive := len(os.Args) > 3 && os.Args[3] == "--naive"

	r := versionSet(path, version, naive)

	switch {
	case r.Refusal != "":
		fmt.Printf("  REFUSED: %s\n", r.Refusal)
		os.Exit(1)
	case !r.Changed:
		fmt.Printf("  no-op: %s is already %q (found by %s, at %s)\n", r.Field, version, r.Route, r.Pos)
		fmt.Println("  file not written")
	default:
		if err := os.WriteFile(path, r.Bytes, 0o644); err != nil {
			fmt.Fprintln(os.Stderr, "write:", err)
			os.Exit(1)
		}
		fmt.Printf("  wrote %s at %s (found by %s)\n", r.Field, r.Pos, r.Route)
		fmt.Printf("    was: %s\n    now: %s\n", r.Was, r.Now)
	}
}

// versionSet locates the version field and rewrites it.
//
// Location is the interesting half. The marker as designed — @opm(identity,
// owner=publish) — says a field is identity that publish owns, but NOT which
// identity field it is, so a writer looking for "the version" has nothing to
// match on and must fall back to the field's NAME. That is the duplication the
// marker exists to remove, so this also accepts a role argument
// (@opm(identity, role=version)) and reports which route it used.
func versionSet(path, version string, naive bool) result {
	src, err := os.ReadFile(path)
	if err != nil {
		return result{Refusal: err.Error()}
	}
	f, err := parser.ParseFile(path, src, parser.ParseComments)
	if err != nil {
		return result{Refusal: fmt.Sprintf("parse: %v", err)}
	}

	var target *ast.Field
	var route string
	var unmarked []string

	ast.Walk(f, func(n ast.Node) bool {
		fl, ok := n.(*ast.Field)
		if !ok {
			return true
		}
		name, _, err := ast.LabelName(fl.Label)
		if err != nil {
			return true
		}
		role, marked := opmRole(fl)
		switch {
		case marked && role == "version":
			target, route = fl, "role"
		case marked && role == "" && name == "Version" && target == nil:
			// Name fallback. Only reached because the marker does not say what
			// it marks.
			target, route = fl, "name-fallback"
		case !marked && name == "Version":
			unmarked = append(unmarked, name)
		}
		return true
	}, nil)

	if target == nil {
		if len(unmarked) > 0 {
			return result{Refusal: fmt.Sprintf(
				"%s declares %s but it carries no @opm() marker — OPM does not own this field and will not write it",
				path, strings.Join(unmarked, ", "))}
		}
		return result{Refusal: fmt.Sprintf(
			"%s declares no @opm()-marked version field — nothing to write (a module carries no version in source)", path)}
	}

	name, _, _ := ast.LabelName(target.Label)
	r := result{
		Found: true,
		Route: route,
		Field: name,
		Pos:   trimPos(target.Pos()),
		Was:   expr(target.Value),
	}

	if r.Was == `"`+version+`"` || strings.HasSuffix(r.Was, ` & "`+version+`"`) {
		r.Now = r.Was
		return r // idempotent: nothing to write
	}

	if naive {
		// The obvious implementation, and the one that silently deletes a type
		// assertion the author wrote.
		target.Value = ast.NewString(version)
	} else {
		target.Value = replaceConcrete(target.Value, version)
	}
	r.Now = expr(target.Value)
	r.Changed = true

	b, err := format.Node(f)
	if err != nil {
		return result{Refusal: fmt.Sprintf("format: %v", err)}
	}
	r.Bytes = b
	return r
}

// replaceConcrete rebuilds `A & B & "old"` as `A & B & "new"`, preserving every
// operand that is not a string literal. An open field (`Version: #VersionType`)
// therefore becomes `#VersionType & "new"` — the committed file keeps asserting
// SemVer instead of losing the constraint the moment a version is written.
//
// A bare predeclared `string` is dropped rather than kept, because
// `string & "1.2.0"` says nothing that `"1.2.0"` does not.
func replaceConcrete(v ast.Expr, version string) ast.Expr {
	var keep []ast.Expr
	var collect func(ast.Expr)
	collect = func(e ast.Expr) {
		if b, ok := e.(*ast.BinaryExpr); ok && b.Op == token.AND {
			collect(b.X)
			collect(b.Y)
			return
		}
		if lit, ok := e.(*ast.BasicLit); ok && lit.Kind == token.STRING {
			return // the old concrete value; dropped
		}
		if id, ok := e.(*ast.Ident); ok && id.Name == "string" {
			return
		}
		keep = append(keep, e)
	}
	collect(v)

	out := ast.Expr(ast.NewString(version))
	for i := len(keep) - 1; i >= 0; i-- {
		out = ast.NewBinExpr(token.AND, keep[i], out)
	}
	return out
}

// opmRole reports whether a field carries an @opm() marker and what role, if
// any, it declares.
func opmRole(fl *ast.Field) (role string, marked bool) {
	for _, a := range fl.Attrs {
		name, body := a.Split()
		if name != marker {
			continue
		}
		marked = true
		for _, part := range strings.Split(body, ",") {
			part = strings.TrimSpace(part)
			if v, ok := strings.CutPrefix(part, "role="); ok {
				role = v
			}
		}
	}
	return role, marked
}

func expr(e ast.Expr) string {
	b, err := format.Node(e)
	if err != nil {
		return "<unprintable>"
	}
	return string(b)
}

func trimPos(p token.Pos) string {
	s := p.String()
	if i := strings.LastIndex(s, "/"); i >= 0 {
		return s[i+1:]
	}
	return s
}
