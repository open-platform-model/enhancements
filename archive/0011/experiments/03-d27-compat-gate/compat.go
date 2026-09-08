package main

import (
	"fmt"
	"cuelang.org/go/cue"
)

// Violation is one D27 breach, located by path.
type Violation struct {
	Path string
	Kind string
	Detail string
}

func (v Violation) String() string { return fmt.Sprintf("%s: %s (%s)", v.Path, v.Kind, v.Detail) }

// CheckAtLevel is the gate as it would run inside `opm catalog publish`.
// Per D34 the promise binds at beta and GA only, so an alpha contract is
// waved through without comparison. The apiVersion is read from the primitive
// being published, not from the catalog.
func CheckAtLevel(apiVersion string, prev, next cue.Value) []Violation {
	lvl, ok := ParseLevel(apiVersion)
	if !ok {
		return []Violation{{"", "unparseable apiVersion", apiVersion}}
	}
	if !lvl.Enforced() {
		return nil
	}
	return Check(prev, next)
}

// Check reports how `next` breaks compatibility with `prev` under enhancement
// 0010 D27: fields and options may be added, never removed; an added field must
// be optional or defaulted; an existing default is immutable.
//
// Subsume alone cannot express this — adding a struct field makes a value more
// specific while adding a disjunct makes it less specific, and D27 permits both.
// So the walk splits the two cases and checks defaults explicitly.
func Check(prev, next cue.Value) []Violation {
	return walk("", prev, next, nil)
}

func walk(path string, prev, next cue.Value, acc []Violation) []Violation {
	// 1. Defaults are immutable — checked at every level, because subsume is
	//    blind to defaults in both directions.
	if pd, has := prev.Default(); has {
		nd, nhas := next.Default()
		if !nhas {
			acc = append(acc, Violation{path, "default removed", fmt.Sprintf("was %v", pd)})
		} else if !equalConcrete(pd, nd) {
			acc = append(acc, Violation{path, "default changed", fmt.Sprintf("%v -> %v", pd, nd)})
		}
	}

	pk, nk := prev.IncompleteKind(), next.IncompleteKind()
	if pk == cue.StructKind && nk == cue.StructKind {
		return walkStruct(path, prev, next, acc)
	}

	// 2. Leaf: the new domain must accept everything the old one did.
	//    Forward subsume is correct here (widening ok, narrowing refused).
	if err := next.Subsume(prev, cue.Schema(), cue.Raw()); err != nil {
		acc = append(acc, Violation{path, "domain narrowed", err.Error()})
	}
	return acc
}

func walkStruct(path string, prev, next cue.Value, acc []Violation) []Violation {
	seen := map[string]bool{}

	pit, _ := prev.Fields(cue.All())
	for pit.Next() {
		sel := pit.Selector()
		name := sel.String()
		seen[name] = true
		nv := next.LookupPath(cue.MakePath(sel))
		if !nv.Exists() {
			acc = append(acc, Violation{join(path, name), "field removed", "present in previous build"})
			continue
		}
		acc = walk(join(path, name), pit.Value(), nv, acc)
	}

	nit, _ := next.Fields(cue.All())
	for nit.Next() {
		sel := nit.Selector()
		name := sel.String()
		if seen[name] {
			continue
		}
		// 3. An added field must be optional or carry a default.
		optional := sel.ConstraintType()&cue.OptionalConstraint != 0
		_, hasDefault := nit.Value().Default()
		if !optional && !hasDefault {
			acc = append(acc, Violation{join(path, name), "field added without optional or default",
				"new required field breaks existing consumers"})
		}
	}
	return acc
}

func equalConcrete(a, b cue.Value) bool {
	if !a.IsConcrete() || !b.IsConcrete() {
		return false
	}
	return a.Equals(b)
}

func join(p, n string) string {
	if p == "" {
		return n
	}
	return p + "." + n
}
