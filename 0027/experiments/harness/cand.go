package main

// cand.go: the candidate encoder for experiments E1/E3/OQ21. It reuses the
// corpus walker's scalar/list/collect logic (walker.go, unchanged) and changes
// four things:
//
//  1. Disjunction arms are recovered with Eval().Expr() when Expr() hides them
//     (a field typed by an imported definition, e.g. `pw: core.#Secret`).
//  2. Struct unions are classified: discriminated (one field concrete and
//     distinct in every arm), presence-discriminated (every arm owns at least
//     one field no other arm declares), or refused. Mode "cel" encodes the
//     rule as x-kubernetes-validations; mode "oneof" as oneOf/not (no CEL).
//  3. Required: `!` fields, plus regular fields with no default that are
//     neither concrete nor computed (interpolation). Defaulted, optional,
//     concrete and computed fields are not required.
//  4. No `default` and no x-opm-* keys are emitted into the CRD schema; side
//     facts (secret paths, refusals) are returned out of band.

import (
	"encoding/json"
	"fmt"
	"sort"
	"strings"

	"cuelang.org/go/cue"
)

var exactlyOneForm = "pairwise"

type Cand struct {
	Mode     string // "cel" | "oneof"
	CorePkgs []string
	Gaps     map[string]int
	Refusals []string
	Secrets  []string
	base     *Walker
}

func NewCand(mode string) *Cand {
	c := &Cand{Mode: mode, CorePkgs: []string{"x1a.example/s/corev2", "x1a.example/s/corev2w2"}, Gaps: map[string]int{}}
	c.base = &Walker{Gaps: c.Gaps}
	return c
}

func (c *Cand) refuse(path, why string) {
	c.Refusals = append(c.Refusals, path+": "+why)
}

func arms(v cue.Value) []cue.Value {
	if op, a := v.Expr(); op == cue.OrOp {
		return a
	}
	if op, a := v.Eval().Expr(); op == cue.OrOp {
		return a
	}
	return nil
}

func (c *Cand) Schema(v cue.Value, path string, depth int) S {
	out := S{}
	if depth > 12 {
		c.refuse(path, "depth>12")
		out["x-kubernetes-preserve-unknown-fields"] = true
		return out
	}
	if docs := v.Doc(); len(docs) > 0 {
		var sb strings.Builder
		for _, d := range docs {
			sb.WriteString(strings.TrimSpace(d.Text()))
			sb.WriteString("\n")
		}
		out["description"] = strings.TrimSpace(sb.String())
	}
	k := v.IncompleteKind()
	if a := arms(v); len(a) > 1 {
		// Scalar enums and int-or-string stay with the base walker.
		allStruct := true
		anyStruct := false
		for _, x := range a {
			if x.IncompleteKind() != cue.StructKind {
				allStruct = false
			} else {
				anyStruct = true
			}
		}
		if allStruct {
			// A default arm only matters for `required`; the struct union
			// itself is encoded from the non-default-duplicate arms.
			if d := dedupeArms(v, a); len(d) == 1 {
				c.structSchema(d[0], path, out, depth)
			} else {
				c.structUnion(v, d, path, out, depth)
			}
			return out
		}
		if anyStruct {
			c.refuse(path, "union mixes struct and scalar arms")
			out["x-kubernetes-preserve-unknown-fields"] = true
			if c.Mode == "cel" {
				var kinds []string
				for _, x := range a {
					switch x.IncompleteKind() {
					case cue.StructKind:
						kinds = append(kinds, "type(self) == map")
					case cue.StringKind:
						kinds = append(kinds, "type(self) == string")
					case cue.IntKind:
						kinds = append(kinds, "type(self) == int")
					case cue.BoolKind:
						kinds = append(kinds, "type(self) == bool")
					}
				}
				out["x-kubernetes-validations"] = []any{S{"rule": strings.Join(kinds, " || "), "message": "must be one of the union's kinds"}}
			}
			return out
		}
	}
	if k == cue.StructKind {
		c.structSchema(v, path, out, depth)
		return out
	}
	if k == cue.ListKind {
		out["type"] = "array"
		el := v.LookupPath(cue.MakePath(cue.AnyIndex))
		if el.Exists() {
			out["items"] = c.Schema(el, path+"[_]", depth+1)
		} else {
			out["items"] = S{"x-kubernetes-preserve-unknown-fields": true}
		}
		c.base.collect(v, out)
		return out
	}
	// A reference into another package (core.#SecretKeyType) hides its
	// constraints from Expr(); the evaluated value shows them.
	if op, _ := v.Expr(); op == cue.SelectorOp {
		v = v.Eval()
	}
	s := c.base.Schema(v, depth)
	notRegex(v, s)
	delete(s, "default")
	delete(s, "x-opm-ui")
	if _, ok := s["x-opm-computed"]; ok {
		delete(s, "x-opm-computed")
	}
	for kk, vv := range s {
		out[kk] = vv
	}
	return out
}

func dedupeArms(v cue.Value, a []cue.Value) []cue.Value {
	// `*{concrete} | T` is a struct default, not a union: drop the arm equal
	// to the field's default when another arm admits it.
	var reduced []cue.Value
	d, hasDef := v.Default()
	dropped := false
	for i, x := range a {
		if hasDef && !dropped && jsonEq(x, d) && x.Validate(cue.Concrete(true)) == nil {
			admitted := false
			for j, y := range a {
				if i != j && y.Unify(x).Validate(cue.Concrete(true)) == nil {
					admitted = true
				}
			}
			if admitted {
				dropped = true
				continue
			}
		}
		reduced = append(reduced, x)
	}
	a = reduced
	var keep []cue.Value
	for _, x := range a {
		dup := false
		for _, y := range keep {
			if fmt.Sprint(x) == fmt.Sprint(y) {
				dup = true
			}
		}
		if !dup {
			keep = append(keep, x)
		}
	}
	return keep
}

// required reports whether a field must be supplied by the user (OQ21 rule).
func requiredField(sel cue.Selector, fv cue.Value) bool {
	if sel.ConstraintType() == cue.RequiredConstraint {
		return true
	}
	if sel.ConstraintType() == cue.OptionalConstraint {
		return false
	}
	if _, ok := fv.Default(); ok {
		return false
	}
	// A struct whose own fields are all optional/defaulted is not required.
	// (Checked before IsConcrete, which is true for every struct.)
	if fv.IncompleteKind() == cue.StructKind && arms(fv) == nil {
		it, err := fv.Fields(cue.Optional(true))
		if err == nil {
			for it.Next() {
				if requiredField(it.Selector(), it.Value()) {
					return true
				}
			}
		}
		return false
	}
	if fv.IncompleteKind() != cue.StructKind && fv.IsConcrete() {
		return false
	}
	if isComputed(fv) {
		return false
	}
	return true
}

func isComputed(v cue.Value) bool {
	op, args := v.Expr()
	if op == cue.InterpolationOp {
		return true
	}
	if op == cue.NoOp && len(args) == 1 {
		if op2, _ := args[0].Expr(); op2 == cue.InterpolationOp {
			return true
		}
	}
	return false
}

func (c *Cand) structSchema(v cue.Value, path string, out S, depth int) {
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
			props[name] = c.Schema(fv, path+"."+name, depth+1)
			if requiredField(sel, fv) {
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
	if ap.Exists() && ap.IncompleteKind() == cue.TopKind {
		// `...`: an open struct; unknown fields are kept, not typed
		out["x-kubernetes-preserve-unknown-fields"] = true
	} else if ap.Exists() {
		if len(props) > 0 {
			c.refuse(path, "pattern constraint beside fixed fields")
		}
		out["additionalProperties"] = c.Schema(ap, path+"[_]", depth+1)
	} else if len(props) == 0 {
		out["x-kubernetes-preserve-unknown-fields"] = true
	}
}

type armInfo struct {
	v      cue.Value
	props  map[string]any
	req    map[string]bool
	consts map[string]any
	open   bool
	tagged bool
	order  []string
	legacy bool
}

func (c *Cand) tagged(a cue.Value) bool {
	for _, p := range c.CorePkgs {
		if a.LookupPath(cue.MakePath(cue.Hid("_opmSecret", p))).Exists() {
			return true
		}
	}
	return false
}

func lit(x any) string {
	b, _ := json.Marshal(x)
	s := string(b)
	if strings.HasPrefix(s, "\"") {
		return "'" + strings.ReplaceAll(strings.Trim(s, "\""), "'", "\\'") + "'"
	}
	return s
}

func norm(s any) string {
	m, ok := s.(S)
	if !ok {
		b, _ := json.Marshal(s)
		return string(b)
	}
	cp := S{}
	for k, v := range m {
		if k == "description" || k == "default" {
			continue
		}
		cp[k] = v
	}
	b, _ := json.Marshal(cp)
	return string(b)
}

func (c *Cand) structUnion(v cue.Value, alts []cue.Value, path string, out S, depth int) {
	var as []armInfo
	for _, a := range alts {
		ai := armInfo{v: a, props: map[string]any{}, req: map[string]bool{}, consts: map[string]any{}}
		s := S{}
		c.structSchema(a, path, s, depth+1)
		if p, ok := s["properties"].(S); ok {
			for k, x := range p {
				ai.props[k] = x
			}
		}
		if r, ok := s["required"].([]any); ok {
			for _, x := range r {
				ai.req[x.(string)] = true
			}
		}
		it, _ := a.Fields(cue.Optional(true))
		for it != nil && it.Next() {
			fv := it.Value()
			ai.order = append(ai.order, it.Selector().Unquoted())
			if it.Selector().ConstraintType()&(cue.OptionalConstraint|cue.RequiredConstraint) == 0 && fv.IsConcrete() && fv.IncompleteKind() != cue.StructKind && fv.IncompleteKind() != cue.ListKind {
				ai.consts[it.Selector().Unquoted()] = jsonOf(fv)
			}
			if it.Selector().Unquoted() == "$opm" {
				ai.legacy = true
			}
		}
		ai.open = a.LookupPath(cue.MakePath(cue.AnyString)).Exists()
		ai.tagged = c.tagged(a)
		as = append(as, ai)
	}
	allTagged := true
	for _, a := range as {
		if !a.tagged {
			allTagged = false
		}
	}
	if allTagged {
		c.Secrets = append(c.Secrets, path)
	}
	// merged property set; refuse conflicting schemas for the same name
	props := S{}
	in := map[string][]int{}
	for i, a := range as {
		for k, s := range a.props {
			if prev, ok := props[k]; ok && norm(prev) != norm(s) {
				// arm constants (single-value enums) merge into one enum
				if _, c1 := a.consts[k]; c1 {
					pm, _ := prev.(S)
					sm, _ := s.(S)
					pe, _ := pm["enum"].([]any)
					se, _ := sm["enum"].([]any)
					merged := S{}
					for kk, vv := range sm {
						merged[kk] = vv
					}
					merged["enum"] = append(append([]any{}, pe...), se...)
					s = merged
				} else {
					c.refuse(path, "arms declare "+k+" with different schemas")
				}
			}
			props[k] = s
			in[k] = append(in[k], i)
		}
	}
	// discriminator candidates
	var cands []string
	for k := range as[0].consts {
		ok := true
		seen := map[string]bool{}
		for _, a := range as {
			x, has := a.consts[k]
			if !has {
				ok = false
				break
			}
			key := lit(x)
			if seen[key] {
				ok = false
				break
			}
			seen[key] = true
		}
		if ok {
			cands = append(cands, k)
		}
	}
	sort.Strings(cands)
	if attr := v.Attribute("opm"); attr.Err() == nil {
		if p0, _ := attr.String(0); p0 == "ui" {
			if d, ok, _ := attr.Lookup(1, "discriminator"); ok {
				cands = []string{d}
			}
		}
	}
	anyOpen := false
	for _, a := range as {
		if a.open {
			anyOpen = true
		}
	}
	out["type"] = "object"
	out["properties"] = props
	if anyOpen {
		out["x-kubernetes-preserve-unknown-fields"] = true
	}
	var rules []any
	var oneOf []any
	switch {
	case len(cands) == 1:
		d := cands[0]
		var en []any
		for _, a := range as {
			en = append(en, a.consts[d])
		}
		ds := S{}
		for k, x := range props[d].(S) {
			if k != "enum" {
				ds[k] = x
			}
		}
		ds["enum"] = en
		props[d] = ds
		req := []any{d}
		for k := range props {
			if k == d {
				continue
			}
			all := true
			for _, a := range as {
				if !a.req[k] {
					all = false
				}
			}
			if all {
				req = append(req, k)
			}
		}
		out["required"] = req
		for _, a := range as {
			var must, forbid []string
			for k := range a.req {
				if k != d {
					must = append(must, "has(self."+k+")")
				}
			}
			if !a.open {
				for k := range props {
					if _, mine := a.props[k]; !mine {
						forbid = append(forbid, "!has(self."+k+")")
					}
				}
			}
			// other constants of this arm (e.g. class: "object" beside kind)
			for k, cv := range a.consts {
				if k != d {
					must = append(must, fmt.Sprintf("(!has(self.%s) || self.%s == %s)", k, k, lit(cv)))
				}
			}
			sort.Strings(must)
			sort.Strings(forbid)
			conds := append(append([]string{}, must...), forbid...)
			if len(conds) == 0 {
				continue
			}
			if c.Mode == "cel" {
				rules = append(rules, S{"rule": fmt.Sprintf("self.%s != %s || (%s)", d, lit(a.consts[d]), strings.Join(conds, " && ")),
					"message": fmt.Sprintf("when %s is %v: %s", d, a.consts[d], strings.Join(conds, ", "))})
			}
		}
		if c.Mode == "oneof" {
			for _, a := range as {
				bp := S{}
				for k, cv := range a.consts {
					bp[k] = S{"enum": []any{cv}}
				}
				br := S{"properties": bp}
				var r []any
				for k := range a.req {
					r = append(r, k)
				}
				if len(r) > 0 {
					br["required"] = r
				}
				if f := foreign(a, props); len(f) > 0 && !a.open {
					br["not"] = S{"anyOf": f}
				}
				oneOf = append(oneOf, br)
			}
		}
	case len(cands) > 1:
		c.refuse(path, "ambiguous discriminator "+strings.Join(cands, ",")+" (needs @opm(ui, discriminator=...))")
		out["x-kubernetes-preserve-unknown-fields"] = true
	default:
		// presence-discriminated?
		own := make([][]string, len(as))
		ok := true
		for i, a := range as {
			for _, k := range a.order {
				if _, ok := a.props[k]; ok && len(in[k]) == 1 {
					own[i] = append(own[i], k)
				}
			}
			if len(own[i]) == 0 {
				ok = false
			}
		}
		if !ok || anyOpen {
			c.refuse(path, "struct union with no discriminator and no arm-owned field")
			out["x-kubernetes-preserve-unknown-fields"] = true
			break
		}
		// Each arm is represented by one field it owns (a required one when
		// it has one). Rules are kept small: the CEL cost budget is per rule,
		// multiplied by the estimated cardinality of an unbounded list or map.
		rep := make([]string, len(as))
		repName := make([]string, len(as))
		for i, a := range as {
			for _, k := range own[i] {
				if a.req[k] {
					rep[i], repName[i] = "has(self."+k+")", k
					break
				}
			}
			if rep[i] == "" {
				var hs []string
				for _, k := range own[i] {
					hs = append(hs, "has(self."+k+")")
				}
				rep[i], repName[i] = "("+strings.Join(hs, " || ")+")", strings.Join(own[i], "/")
			}
		}
		var groups []string
		for i := range as {
			groups = append(groups, strings.Join(own[i], ","))
		}
		if c.Mode == "cel" {
			rules = append(rules, S{"rule": strings.Join(rep, " || "), "message": "set one of: " + strings.Join(repName, " | ")})
			for i := range as {
				for j := i + 1; j < len(as); j++ {
					rules = append(rules, S{"rule": "!(" + rep[i] + " && " + rep[j] + ")", "message": repName[i] + " and " + repName[j] + " are mutually exclusive"})
				}
			}
			for i, a := range as {
				for _, k := range own[i] {
					if k != repName[i] && strings.HasPrefix(rep[i], "has(") {
						rules = append(rules, S{"rule": "!has(self." + k + ") || " + rep[i], "message": k + " requires " + repName[i]})
					}
				}
				for k := range a.req {
					if k != repName[i] {
						rules = append(rules, S{"rule": "!" + rep[i] + " || has(self." + k + ")", "message": repName[i] + " requires " + k})
					}
				}
			}
			for k, idx := range in {
				if len(idx) > 1 && len(idx) < len(as) {
					var hs []string
					for _, i := range idx {
						hs = append(hs, rep[i])
					}
					rules = append(rules, S{"rule": "!has(self." + k + ") || " + strings.Join(hs, " || "), "message": k + " is not allowed here"})
				}
			}
		} else {
			for i, a := range as {
				br := S{}
				var r []any
				for k := range a.req {
					r = append(r, k)
				}
				if len(r) > 0 {
					br["required"] = r
				} else {
					var any_ []any
					for _, k := range own[i] {
						any_ = append(any_, S{"required": []any{k}})
					}
					br["anyOf"] = any_
				}
				if f := foreign(a, props); len(f) > 0 {
					br["not"] = S{"anyOf": f}
				}
				oneOf = append(oneOf, br)
			}
		}
		// fields required in every arm are required outright
		var req []any
		for k := range props {
			all := true
			for _, a := range as {
				if !a.req[k] {
					all = false
				}
			}
			if all {
				req = append(req, k)
			}
		}
		if len(req) > 0 {
			out["required"] = req
		}
	}
	if len(rules) > 0 {
		sort.Slice(rules, func(i, j int) bool { return rules[i].(S)["rule"].(string) < rules[j].(S)["rule"].(string) })
		out["x-kubernetes-validations"] = rules
	}
	if len(oneOf) > 0 {
		out["oneOf"] = oneOf
	}
}

func foreign(a armInfo, props S) []any {
	var f []string
	for k := range props {
		if _, mine := a.props[k]; !mine {
			f = append(f, k)
		}
	}
	sort.Strings(f)
	var r []any
	for _, k := range f {
		r = append(r, S{"required": []any{k}})
	}
	return r
}

// notRegex encodes `!~` bounds as allOf/not/pattern, which is structural.
func notRegex(v cue.Value, out S) {
	op, args := v.Expr()
	switch op {
	case cue.AndOp:
		for _, a := range args {
			notRegex(a, out)
		}
	case cue.NotRegexMatchOp:
		l, _ := out["allOf"].([]any)
		out["allOf"] = append(l, S{"not": S{"pattern": jsonOf(args[0])}})
	}
}
