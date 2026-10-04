package main

import (
	"encoding/json"
	"fmt"
	"strings"

	"cuelang.org/go/cue"
)

// Gaps collects walker limitations per module.
type Walker struct {
	Gaps map[string]int
}

func (w *Walker) gap(s string) { w.Gaps[s]++ }

type S = map[string]any

func isConcrete(v cue.Value) bool { return v.IsConcrete() }

func jsonOf(v cue.Value) any {
	b, err := v.MarshalJSON()
	if err != nil {
		return nil
	}
	var a any
	json.Unmarshal(b, &a)
	return a
}

func (w *Walker) Schema(v cue.Value, depth int) S {
	out := S{}
	if depth > 12 {
		w.gap("depth-limit")
		out["x-kubernetes-preserve-unknown-fields"] = true
		return out
	}
	k := v.IncompleteKind()
	if docs := v.Doc(); len(docs) > 0 {
		var sb strings.Builder
		for _, d := range docs {
			sb.WriteString(strings.TrimSpace(d.Text()))
			sb.WriteString("\n")
		}
		out["description"] = strings.TrimSpace(sb.String())
	}
	if as := v.Attribute("ui"); as.Err() == nil {
		out["x-opm-ui"] = as.Contents()
	}
	// Expr() drops a default alternative subsumed by another one and reports
	// a lone remaining alternative as NoOp with one operand; unwrap it.
	cur := v
	if k != cue.StructKind {
		for i := 0; i < 6; i++ {
			op0, a0 := cur.Expr()
			if op0 == cue.NoOp && len(a0) == 1 && fmt.Sprint(a0[0]) != fmt.Sprint(cur) {
				cur = a0[0]
				continue
			}
			break
		}
	}
	op, args := cur.Expr()
	if op == cue.OrOp {
		w.disjunction(v, args, out, depth)
		return out
	}
	if cur.IncompleteKind() != k {
		k = cur.IncompleteKind()
	}
	v0 := v
	v = cur
	defer func() {
		if d, ok := v0.Default(); ok && d.IsConcrete() {
			if k != cue.StructKind && !(k == cue.ListKind && fmt.Sprint(jsonOf(d)) == "[]") {
				out["default"] = jsonOf(d)
			}
		}
	}()
	switch {
	case k == cue.StructKind:
		w.structSchema(v, out, depth)
	case k == cue.ListKind:
		out["type"] = "array"
		el := v.LookupPath(cue.MakePath(cue.AnyIndex))
		if !el.Exists() {
			if e2, ok := v.Elem(); ok {
				el = e2
			}
		}
		if el.Exists() {
			out["items"] = w.Schema(el, depth+1)
		} else {
			w.gap("list-no-elem")
			out["items"] = S{"x-kubernetes-preserve-unknown-fields": true}
		}
		w.collect(v, out) // minItems etc
	case k.IsAnyOf(cue.StringKind|cue.IntKind|cue.FloatKind|cue.NumberKind|cue.BoolKind|cue.BytesKind) && isSingleKind(k):
		w.scalar(v, k, out)
	case k == cue.IntKind|cue.StringKind || k == cue.NumberKind|cue.StringKind:
		out["x-kubernetes-int-or-string"] = true
	case k == cue.TopKind:
		w.gap("top-type")
		out["x-kubernetes-preserve-unknown-fields"] = true
	default:
		w.gap("mixed-kind:" + k.String())
		out["x-kubernetes-preserve-unknown-fields"] = true
	}
	return out
}

func isSingleKind(k cue.Kind) bool {
	switch k {
	case cue.StringKind, cue.IntKind, cue.FloatKind, cue.NumberKind, cue.BoolKind, cue.BytesKind:
		return true
	}
	return false
}

func (w *Walker) scalar(v cue.Value, k cue.Kind, out S) {
	switch k {
	case cue.StringKind:
		out["type"] = "string"
	case cue.IntKind:
		out["type"] = "integer"
	case cue.FloatKind, cue.NumberKind:
		out["type"] = "number"
	case cue.BoolKind:
		out["type"] = "boolean"
	case cue.BytesKind:
		out["type"] = "string"
		out["format"] = "byte"
	}
	w.collect(v, out)
	if isConcrete(v) {
		out["enum"] = []any{jsonOf(v)}
		if op, _ := v.Expr(); op == cue.InterpolationOp {
			out["x-opm-computed"] = true
		}
	}
}

// collect walks the Expr tree gathering bound/pattern constraints.
func (w *Walker) collect(v cue.Value, out S) {
	op, args := v.Expr()
	switch op {
	case cue.AndOp:
		for _, a := range args {
			w.collect(a, out)
		}
	case cue.OrOp:
		allC := true
		var en []any
		for _, a := range args {
			if !a.IsConcrete() {
				allC = false
			}
			en = append(en, jsonOf(a))
		}
		if allC {
			out["enum"] = en
		} else {
			w.gap("nested-disjunction-in-conjunct")
		}
	case cue.LessThanOp:
		out["maximum"] = jsonOf(args[0])
		out["exclusiveMaximum"] = true
	case cue.LessThanEqualOp:
		out["maximum"] = jsonOf(args[0])
	case cue.GreaterThanOp:
		out["minimum"] = jsonOf(args[0])
		out["exclusiveMinimum"] = true
	case cue.GreaterThanEqualOp:
		out["minimum"] = jsonOf(args[0])
	case cue.RegexMatchOp:
		out["pattern"] = jsonOf(args[0])
	case cue.NotRegexMatchOp:
		w.gap("not-regex")
	case cue.NotEqualOp:
		w.gap("not-equal")
	case cue.CallOp:
		name := fmt.Sprint(args[0])
		switch name {
		case "strings.MinRunes":
			out["minLength"] = jsonOf(args[1])
		case "strings.MaxRunes":
			out["maxLength"] = jsonOf(args[1])
		case "list.MinItems":
			out["minItems"] = jsonOf(args[1])
		case "list.MaxItems":
			out["maxItems"] = jsonOf(args[1])
		case "math.MultipleOf":
			out["multipleOf"] = jsonOf(args[1])
		default:
			w.gap("call:" + name)
		}
	case cue.NoOp, cue.SelectorOp, cue.InterpolationOp, cue.IndexOp, cue.SliceOp:
		if op != cue.NoOp {
			w.gap("op:" + op.String())
		}
	default:
		w.gap("op:" + op.String())
	}
}

func (w *Walker) disjunction(v cue.Value, alts []cue.Value, out S, depth int) {
	def, hasDef := v.Default()
	// drop alternatives that are the default marker duplicate of another alt
	var keep []cue.Value
	for _, a := range alts {
		if hasDef && a.IsConcrete() && jsonEq(a, def) && len(alts) > 1 {
			// is it subsumed by another non-concrete alt?
			dup := false
			for _, b := range alts {
				if b.IsConcrete() {
					continue
				}
				if b.Unify(a).Validate() == nil {
					dup = true
				}
			}
			if dup {
				continue
			}
		}
		keep = append(keep, a)
	}
	// dedupe concretes
	var uniq []cue.Value
	for _, a := range keep {
		d := false
		for _, u := range uniq {
			if a.IsConcrete() && u.IsConcrete() && jsonEq(a, u) {
				d = true
			}
		}
		if !d {
			uniq = append(uniq, a)
		}
	}
	keep = uniq
	if hasDef && def.IsConcrete() {
		out["default"] = jsonOf(def)
	}
	if len(keep) == 1 {
		s := w.Schema(keep[0], depth+1)
		for kk, vv := range s {
			if _, ok := out[kk]; !ok || kk != "description" {
				out[kk] = vv
			}
		}
		return
	}
	allConcrete := true
	kinds := cue.BottomKind
	for _, a := range keep {
		if !a.IsConcrete() || a.IncompleteKind() == cue.StructKind || a.IncompleteKind() == cue.ListKind {
			allConcrete = false
		}
		kinds |= a.IncompleteKind()
	}
	if allConcrete {
		var en []any
		for _, a := range keep {
			en = append(en, jsonOf(a))
		}
		out["enum"] = en
		switch {
		case kinds == cue.StringKind:
			out["type"] = "string"
		case kinds == cue.IntKind:
			out["type"] = "integer"
		case kinds == cue.BoolKind:
			out["type"] = "boolean"
		case kinds == cue.NumberKind|cue.IntKind || kinds == cue.NumberKind:
			out["type"] = "number"
		default:
			w.gap("heterogeneous-enum")
			out["x-kubernetes-preserve-unknown-fields"] = true
			delete(out, "enum")
		}
		return
	}
	// non-enum: int|string, struct unions, ...
	if kinds == cue.IntKind|cue.StringKind || kinds == cue.NumberKind|cue.StringKind || kinds == cue.IntKind|cue.NumberKind|cue.StringKind {
		out["x-kubernetes-int-or-string"] = true
		out["anyOf"] = []any{S{"type": "integer"}, S{"type": "string"}}
		for _, a := range keep {
			if a.IncompleteKind() == cue.StringKind {
				if p, ok := w.Schema(a, depth+1)["pattern"]; ok {
					out["pattern"] = p
				}
			}
		}
		return
	}
	// struct union: flatten into a permissive struct (all alts' props, optional)
	allStruct := true
	for _, a := range keep {
		if a.IncompleteKind() != cue.StructKind {
			allStruct = false
		}
	}
	if allStruct {
		w.gap("struct-union-flattened")
		props := S{}
		for _, a := range keep {
			s := w.Schema(a, depth+1)
			if p, ok := s["properties"].(S); ok {
				for pk, pv := range p {
					props[pk] = pv
				}
			}
		}
		out["type"] = "object"
		out["properties"] = props
		return
	}
	w.gap("mixed-disjunction")
	out["x-kubernetes-preserve-unknown-fields"] = true
}

func jsonEq(a, b cue.Value) bool {
	x, _ := a.MarshalJSON()
	y, _ := b.MarshalJSON()
	return string(x) == string(y)
}

func (w *Walker) structSchema(v cue.Value, out S, depth int) {
	out["type"] = "object"
	props := S{}
	var req []any
	it, err := v.Fields(cue.Optional(true))
	if err == nil {
		for it.Next() {
			sel := it.Selector()
			if sel.IsDefinition() || sel.PkgPath() != "" {
				continue
			}
			name := sel.Unquoted()
			fv := it.Value()
			props[name] = w.Schema(fv, depth+1)
			_, hasDef := fv.Default()
			if !it.IsOptional() && !hasDef {
				req = append(req, name)
			}
		}
	}
	if len(props) > 0 {
		out["properties"] = props
	}
	if len(req) > 0 {
		out["required"] = req
	}
	ap := v.LookupPath(cue.MakePath(cue.AnyString))
	if ap.Exists() {
		if len(props) > 0 {
			w.gap("pattern-and-fixed-props")
		}
		out["additionalProperties"] = w.Schema(ap, depth+1)
	} else if len(props) == 0 {
		out["x-kubernetes-preserve-unknown-fields"] = true
	}
}
