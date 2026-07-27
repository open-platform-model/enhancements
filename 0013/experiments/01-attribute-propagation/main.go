// Experiment 01 — attribute propagation.
//
// Part A (this file): a matrix of synthetic cases probing whether a CUE field
// attribute survives each construct the OPM artifact shape puts it through.
// Part B (real.go): the same question against a frozen snapshot of the real
// opmodel.dev/core@v1 schema, with the kernel-shaped discovery walk on top.
package main

import (
	"fmt"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/format"
)

var ctx = cuecontext.New()

func main() {
	e1DefinitionToValue()
	e2OPMShape()
	e3Paths()
	e4Shapes()
	e5MultipleConjuncts()
	e6ArgumentParsing()
	e7GenericWalk()
	e8SchemaOnly()
	e9ExportRoundTrip()

	realCore()
}

func hdr(s string) { fmt.Printf("\n=== %s ===\n", s) }

func compile(name, src string) cue.Value {
	v := ctx.CompileString(src, cue.Filename(name))
	if v.Err() != nil {
		fmt.Printf("  COMPILE ERROR %s: %v\n", name, v.Err())
	}
	return v
}

// report prints whether the value at path p carries an @opm attribute.
func report(label string, v cue.Value, p string) {
	val := v.LookupPath(cue.ParsePath(p))
	if !val.Exists() {
		fmt.Printf("  %-44s MISSING PATH\n", label)
		return
	}
	a := val.Attribute("opm")
	if a.Err() != nil {
		fmt.Printf("  %-44s no @opm   (val=%s)\n", label, short(val))
		return
	}
	fmt.Printf("  %-44s @opm(%s)  (val=%s)\n", label, a.Contents(), short(val))
}

func short(v cue.Value) string {
	s := strings.Join(strings.Fields(fmt.Sprint(v)), " ")
	if len(s) > 34 {
		s = s[:34] + "…"
	}
	return s
}

// E1 — does an attribute on a schema field survive unification with a value?
func e1DefinitionToValue() {
	hdr("E1  definition -> concrete unification")

	v := compile("e1", `
#config: {
	password: string @opm(secret, group="db-creds", key=password)
	host:     string
}
values: {password: "hunter2", host: "db.example.com"}
out: #config & values
`)
	report("#config.password (schema side)", v, "#config.password")
	report("out.password (unified)", v, "out.password")
	report("out.host (unmarked sibling)", v, "out.host")

	v2 := compile("e1b", `
#config: password: string @opm(secret, group=g, key=k)
out: {password: "hunter2"} & #config
`)
	report("out.password (reversed order)", v2, "out.password")

	a := compile("e1c-schema", `password: string @opm(secret, group=g, key=k)`)
	b := compile("e1c-values", `password: "hunter2"`)
	report("Go Unify(schema, values).password", a.Unify(b), "password")
}

// E2 — the real OPM artifact shape: #Module skeleton, required #module field,
// `let unified = #module & {#config: values}`, components derived from it.
func e2OPMShape() {
	hdr("E2  the #Module / #ModuleInstance shape")

	cases := []struct{ name, src, path string }{
		{"bare definition", `
#cfg: password: string @opm(secret, group=g, key=k)
out: #cfg & {password: "x"}`, "out.password"},

		{"definition field inside a struct", `
m: {#config: password: string @opm(secret, group=g, key=k)}
out: m.#config & {password: "x"}`, "out.password"},

		{"through a let binding", `
m: {#config: password: string @opm(secret, group=g, key=k)}
let u = m & {#config: password: "x"}
out: u.#config`, "out.password"},

		{"#Module skeleton with {...}", `
#Module: {#config: {...}}
m: #Module & {#config: password: string @opm(secret, group=g, key=k)}
out: m.#config & {password: "x"}`, "out.password"},

		{"required field #module!: #Module", `
#Module: {#config: {...}}
#Inst: {#module!: #Module, out: #module.#config}
mod: #Module & {#config: password: string @opm(secret, group=g, key=k)}
i: #Inst & {#module: mod, out: password: "x"}`, "i.out.password"},

		{"full OPM shape (let + values)", `
#Module: {#config: {...}}
#Inst: {
	#module!: #Module
	let u = #module & {#config: values}
	out: u.#config
	values: _
}
mod: #Module & {#config: db: password: string @opm(secret, group=g, key=k)}
i: #Inst & {#module: mod, values: db: password: "x"}`, "i.out.db.password"},

		{"…plus #components wiring the field", `
#Module: {#config: {...}, #components: {...}}
#Inst: {
	#module!: #Module
	let u = #module & {#config: values}
	components: u.#components
	out:        u.#config
	values: _
}
mod: #Module & {
	#config: db: password: string @opm(secret, group=g, key=k)
	#components: web: pw: #config.db.password
}
i: #Inst & {#module: mod, values: db: password: "x"}`, "i.out.db.password"},
	}

	for _, c := range cases {
		report(c.name, compile("e2", c.src), c.path)
	}

	// The negative control. `#module: #module` inside the instance literal is a
	// SELF-reference to the field being declared, not the outer definition — so
	// the module never arrives and the attribute is legitimately absent. Kept
	// because it produced a false negative during this experiment and is worth
	// recognising: a "missing attribute" can be a CUE scoping bug in the test.
	report("negative control: shadowed #module", compile("e2-shadow", `
#Module: {#config: {...}}
#module: #Module & {#config: db: password: string @opm(secret, group=g, key=k)}
#Inst: {
	#module!: #Module
	let u = #module & {#config: values}
	out: u.#config
	values: _
}
i: #Inst & {#module: #module, values: db: password: "hunter2"}`), "i.out.db.password")
}

// E3 — which paths of an instance carry the mark. This is what decides D3.
func e3Paths() {
	hdr("E3  where the mark is reachable from an instance")

	v := compile("e3", `
#Module: {#config: {...}, #components: {...}}
#Inst: {
	#module!: #Module
	let unified = #module & {#config: values}
	components: unified.#components
	values: _
}
mod: #Module & {
	#config: password: string @opm(secret, group=g, key=k)
	#components: web: pw: #config.password
}
i: #Inst & {#module: mod, values: password: "x"}
`)
	report("i.#module.#config.password  (schema)", v, "i.#module.#config.password")
	report("i.values.password           (data)", v, "i.values.password")
	report("i.components.web.pw         (reference)", v, "i.components.web.pw")
	fmt.Println("  -> the schema side carries the mark but not the value;")
	fmt.Println("     the values side carries the value but not the mark;")
	fmt.Println("     a reference carries neither. Discovery must read #config.")
}

// E4 — shapes: depth, lists, pattern constraints, optional, disjunctions.
func e4Shapes() {
	hdr("E4  depth / lists / patterns / optional / disjunction")

	v := compile("e4", `
deep: l1: l2: l3: l4: l5: l6: l7: l8: l9: l10: l11: l12: {
	secret: string @opm(secret, group=deep, key=k)
}
deepv: deep & {l1: l2: l3: l4: l5: l6: l7: l8: l9: l10: l11: l12: secret: "v"}

inList: [{password: string @opm(secret, group=lst, key=k)} & {password: "p"}]

pat: {
	[string]: string @opm(secret, group=pat, key=k)
	alpha: "a"
}

opt:       {password?: string @opm(secret, group=opt, key=k)}
optFilled: opt & {password: "x"}

disj: {mode: string @opm(secret, group=d, key=k)} | {mode: int}
disjResolved: disj & {mode: "s"}
`)
	report("12 levels deep", v, "deepv.l1.l2.l3.l4.l5.l6.l7.l8.l9.l10.l11.l12.secret")
	report("inside a list element", v, "inList[0].password")
	report("inherited from [string] pattern", v, "pat.alpha")
	report("optional, unfilled", v, "opt.password")
	report("optional, filled", v, "optFilled.password")
	report("after disjunction resolution", v, "disjResolved.mode")
}

// E5 — what happens when several conjuncts carry attributes.
func e5MultipleConjuncts() {
	hdr("E5  multiple conjuncts carrying attributes")

	v := compile("e5", `
a:     password: string @opm(secret, group=one, key=k)
b:     password: string @opm(secret, group=two, key=k)
same1: password: string @opm(secret, group=dup, key=k)
same2: password: string @opm(secret, group=dup, key=k)

conflicting: a & b & {password: "x"}
duplicated:  same1 & same2 & {password: "x"}
`)
	for _, p := range []string{"conflicting.password", "duplicated.password"} {
		attrs := v.LookupPath(cue.ParsePath(p)).Attributes(cue.ValueAttr)
		fmt.Printf("  %-30s %d attr(s)\n", p, len(attrs))
		for _, a := range attrs {
			fmt.Printf("      @%s(%s)\n", a.Name(), a.Contents())
		}
	}
	fmt.Println("  -> identical text is deduped; differing text is NOT merged.")
	fmt.Println("     A kernel must treat >1 secret marker on one field as an error.")
}

// E6 — the argument surface the kernel parses, including @opm namespace sharing.
func e6ArgumentParsing() {
	hdr("E6  argument parsing and @opm namespace sharing")

	v := compile("e6", `
f1: string @opm(secret)
f2: string @opm(secret, group="db-creds", key=password)
f3: string @opm(secret, group=tls, key="tls.crt", type="kubernetes.io/tls")
f4: string @opm(secret, group=g, key=k, description="the db password")
f5: string @opm(identity, owner=publish)
f6: string @opm(secret, group=g, key=k) @other(thing)
f7: string @opm(secrit, group=g)
`)
	for _, name := range []string{"f1", "f2", "f3", "f4", "f5", "f6", "f7"} {
		val := v.LookupPath(cue.ParsePath(name))
		a := val.Attribute("opm")
		if a.Err() != nil {
			fmt.Printf("  %s: no @opm\n", name)
			continue
		}
		kind, _ := a.String(0)
		fmt.Printf("  %s: kind=%-9q nargs=%d", name, kind, a.NumArgs())
		for _, key := range []string{"group", "key", "type", "description", "owner"} {
			if s, found, err := a.Lookup(1, key); err == nil && found {
				fmt.Printf(" %s=%q", key, s)
			}
		}
		if n := len(val.Attributes(cue.ValueAttr)); n > 1 {
			fmt.Printf("  [+%d other attr]", n-1)
		}
		fmt.Println()
	}
	fmt.Println("  -> position 0 separates `secret` from `identity` on one attribute name.")
	fmt.Println("     f7 shows the risk: a misspelled kind parses fine and is silently not a secret.")
}

// secretDecl is the experiment's stand-in for the kernel's #SecretDecl.
type secretDecl struct {
	path string
	args map[string]string
}

// discover is the whole of the kernel's discovery pass: an ordinary recursive
// walk. Compare against the ~240 lines of hand-unrolled CUE comprehension it
// replaces (core/src/schemas.cue #DiscoverSecrets).
func discover(root cue.Value) []secretDecl {
	var out []secretDecl
	var rec func(v cue.Value, prefix string)
	rec = func(v cue.Value, prefix string) {
		switch v.Kind() {
		case cue.StructKind:
			it, err := v.Fields(cue.All())
			if err != nil {
				return
			}
			for it.Next() {
				out = visit(out, it.Value(), join(prefix, it.Selector().String()))
				rec(it.Value(), join(prefix, it.Selector().String()))
			}
		case cue.ListKind:
			it, err := v.List()
			if err != nil {
				return
			}
			for i := 0; it.Next(); i++ {
				p := fmt.Sprintf("%s[%d]", prefix, i)
				out = visit(out, it.Value(), p)
				rec(it.Value(), p)
			}
		}
	}
	rec(root, "")
	return out
}

func visit(out []secretDecl, v cue.Value, path string) []secretDecl {
	a := v.Attribute("opm")
	if a.Err() != nil {
		return out
	}
	if kind, err := a.String(0); err != nil || kind != "secret" {
		return out
	}
	args := map[string]string{}
	for _, k := range []string{"group", "key", "type", "description"} {
		if s, found, err := a.Lookup(1, k); err == nil && found {
			args[k] = s
		}
	}
	return append(out, secretDecl{path: path, args: args})
}

func join(prefix, sel string) string {
	if prefix == "" {
		return sel
	}
	return prefix + "." + sel
}

// E7 — can one generic walk find every marked field, at any shape?
func e7GenericWalk() {
	hdr("E7  generic Go walk finds every marked field")

	v := compile("e7", `
#cfg: {
	db: {password: string @opm(secret, group="db-creds", key=password), host: string}
	tls: cert: string @opm(secret, group=tls, key="tls.crt")
	nested: a: b: c: d: e: f: g: h: i: j: k: deep: string @opm(secret, group=deep)
	list: [{tok: string @opm(secret, group=lst)}]
	plain: "not a secret"
}
out: #cfg & {
	db: {password: "hunter2", host: "h"}
	tls: cert: ""
	nested: a: b: c: d: e: f: g: h: i: j: k: deep: "d"
	list: [{tok: "t"}]
}
`)
	found := discover(v.LookupPath(cue.ParsePath("out")))
	for _, d := range found {
		fmt.Printf("  %-48s %v\n", d.path, d.args)
	}
	fmt.Printf("  -> %d marked fields, including one 12 levels deep and one in a list.\n", len(found))
}

// E8 — discovery with no values at all. This is what `opm module inspect` needs.
func e8SchemaOnly() {
	hdr("E8  discovery on a bare schema (no instance exists)")

	v := compile("e8", `
#cfg: {
	db: password: string @opm(secret, group="db-creds", key=password)
	apiKey?: string @opm(secret, group=api)
}
`)
	for _, d := range discover(v.LookupPath(cue.ParsePath("#cfg"))) {
		fmt.Printf("  %-24s %v\n", d.path, d.args)
	}
	fmt.Println("  -> a module's required secrets are listable before any values are supplied.")
}

// E9 — what survives export, and what does not.
func e9ExportRoundTrip() {
	hdr("E9  export round-trip")

	v := compile("e9", `out: {password: string @opm(secret, group=g, key=k)} & {password: "hunter2"}`)
	o := v.LookupPath(cue.ParsePath("out"))

	for _, tc := range []struct {
		name string
		opts []cue.Option
	}{
		{"Syntax(All)", []cue.Option{cue.All()}},
		{"Syntax(Attributes)", []cue.Option{cue.Attributes(true)}},
		{"Syntax(Final)", []cue.Option{cue.Final()}},
		{"Syntax(Concrete)", []cue.Option{cue.Concrete(true)}},
		{"Syntax() default", nil},
	} {
		b, err := format.Node(o.Syntax(tc.opts...))
		if err != nil {
			fmt.Printf("  %-22s format error: %v\n", tc.name, err)
			continue
		}
		s := strings.Join(strings.Fields(string(b)), " ")
		fmt.Printf("  %-22s @opm preserved=%-5v  %s\n", tc.name, strings.Contains(s, "@opm"), s)
	}

	b, _ := o.MarshalJSON()
	fmt.Printf("  %-22s %s   <- marks are lost, correctly\n", "MarshalJSON", string(b))

	src, _ := format.Node(o.Syntax(cue.All()))
	report("recompiled from Syntax(All)", compile("rt", "rt: "+string(src)), "rt.password")
}
