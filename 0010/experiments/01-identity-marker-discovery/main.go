// Command main is the read half of enhancement 0010's identity design: it
// finds an artifact's tool-owned identity fields BY THEIR @opm() MARKER, with
// no knowledge of what those fields are called, classifies each as absent /
// open / concrete, and prints the identity surface the tree derives.
//
// This is what `opm … publish` reads before it decides anything, and what
// `opm … version set` locates before it writes. Enhancement 0011 owns the
// writing; this program only reads.
//
// It is a DEMONSTRATION, not production code. No tests, no error taxonomy, no
// abstraction that outlives the question being asked.
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"cuelang.org/go/cue"
	"cuelang.org/go/cue/cuecontext"
	"cuelang.org/go/cue/errors"
	"cuelang.org/go/cue/load"
)

// marker is the attribute name OPM claims. The whole point of the design is
// that this is the ONLY name the tool hardcodes — never a field name.
const marker = "opm"

func main() {
	root, err := os.Getwd()
	must(err)

	section("1. MARKER DISCOVERY — which fields does OPM own, and what state are they in?")
	fmt.Println(`Nothing below is looked up by name. Every field is found because it carries
@opm(...), and the "expected" column is the only place a name appears — it is
how ABSENCE is detected, since a field that was never declared carries no
attribute to be found by.`)
	fmt.Println()

	// Each artifact declares which identity fields it must carry. This models
	// `opm module publish` vs `opm catalog publish` knowing what identity the
	// kind it is publishing requires.
	report(root, artifact{
		label:    "module  ./mod",
		dir:      "./mod",
		expected: []string{"metadata.modulePath"},
	})
	report(root, artifact{
		label:    "catalog ./cat  [root package — does the marker survive a reference?]",
		dir:      "./cat",
		expected: []string{"metadata.modulePath", "metadata.version"},
		note: "CONTROL, not a malformed artifact. The catalog root writes\n" +
			"    `metadata: modulePath: id.ModulePath`, and a REFERENCE does not carry the\n" +
			"    attribute attached to the declaration it points at. So tooling has to know\n" +
			"    WHERE identity lives per artifact kind, and a consumer importing this\n" +
			"    catalog can never see the marker at all.",
	})
	report(root, artifact{
		label:    "catalog ./cat/identity",
		dir:      "./cat/identity",
		expected: []string{"ModulePath", "Version"},
	})
	// Same catalog with the Version declaration deleted in memory — a malformed
	// artifact rather than an unfinished one. Nothing on disk changes.
	report(root, artifact{
		label:    "catalog ./cat/identity  [overlay: Version declaration deleted]",
		dir:      "./cat/identity",
		expected: []string{"ModulePath", "Version"},
		overlay:  deleteVersionOverlay(root),
	})

	section("2. WHAT THE TREE DERIVES — open Version vs filled Version")
	fmt.Println(`Every row is evaluated twice: once against the tree exactly as committed
(Version open), and once against the same tree with Version filled to 1.2.0 by
an in-memory overlay — the value ` + "`opm catalog version set 1.2.0`" + ` would write.

D6's claim is the verdict column. Identity and every match key are byte-identical
across the two, so an unfilled tree still computes the whole key space; only the
compatibility signal MOVED.`)
	fmt.Println()

	openVals := derive(root, nil)
	filledVals := derive(root, fillVersionOverlay(root, "1.2.0"))
	compare(openVals, filledVals)

	section("3. THE FAILURE AN OPEN FIELD PRODUCES")
	fmt.Println(`An open field is an ABSENT value, not a placeholder one. Asking for it names
the file and the line rather than returning something that renders.`)
	fmt.Println()
	v := build(root, "./cat", nil)
	ver := v.LookupPath(cue.ParsePath("metadata.version"))
	if err := ver.Validate(cue.Concrete(true)); err != nil {
		d := errors.Details(err, &errors.Config{Cwd: root})
		for _, line := range strings.Split(strings.TrimRight(d, "\n"), "\n") {
			fmt.Println("    " + line)
		}
	} else {
		fmt.Printf("    UNEXPECTED: metadata.version is concrete (%v)\n", ver)
	}
}

// ─── 1. Marker discovery ────────────────────────────────────────────────────

type artifact struct {
	label    string
	dir      string
	expected []string // identity fields this artifact kind must carry
	overlay  map[string]load.Source
	note     string // printed under the rows
}

type found struct {
	path     string
	concrete bool
	value    string
	attr     string
	pos      string
}

func report(root string, a artifact) {
	fmt.Printf("── %s\n", a.label)

	v := build(root, a.dir, a.overlay)
	if v.Err() != nil {
		fmt.Printf("    build failed: %v\n\n", v.Err())
		return
	}

	seen := map[string]found{}
	v.Walk(func(x cue.Value) bool {
		// The same attribute is reported under more than one AttrKind; collect
		// once and dedupe by CUE path.
		for _, kind := range []cue.AttrKind{cue.FieldAttr, cue.ValueAttr} {
			for _, at := range x.Attributes(kind) {
				if at.Name() != marker {
					continue
				}
				p := x.Path().String()
				if _, dup := seen[p]; dup {
					continue
				}
				f := found{
					path:     p,
					concrete: x.IsConcrete(),
					attr:     "@" + marker + "(" + at.Contents() + ")",
					pos:      rel(root, x.Pos().String()),
				}
				if f.concrete {
					s, err := x.String()
					if err == nil {
						f.value = `"` + s + `"`
					}
				}
				seen[p] = f
			}
		}
		return true
	}, nil)

	// State per EXPECTED field. `absent` cannot come from the scan — a field
	// that was never declared has no attribute to be found by — so it comes
	// from the expectation list instead.
	for _, name := range a.expected {
		f, ok := seen[name]
		switch {
		case !ok:
			fmt.Printf("    %-22s %-9s %s\n", name, "ABSENT", "(no declaration carries the marker — malformed artifact)")
		case f.concrete:
			fmt.Printf("    %-22s %-9s %s  %s\n", name, "concrete", f.value, f.attr)
			fmt.Printf("    %-22s %-9s %s\n", "", "", f.pos)
		default:
			fmt.Printf("    %-22s %-9s %s\n", name, "OPEN", f.attr)
			fmt.Printf("    %-22s %-9s %s\n", "", "", f.pos)
		}
	}

	// Anything marked but not expected — a field OPM owns that this artifact
	// kind was not asked about.
	var extra []string
	for p := range seen {
		if !contains(a.expected, p) {
			extra = append(extra, p)
		}
	}
	sort.Strings(extra)
	for _, p := range extra {
		fmt.Printf("    %-22s %-9s (marked, not in the expected set)\n", p, "extra")
	}
	if a.note != "" {
		fmt.Printf("    → %s\n", a.note)
	}
	fmt.Println()
}

// ─── 2. Derived surface ─────────────────────────────────────────────────────

type row struct {
	label string
	value string
}

func derive(root string, ov map[string]load.Source) []row {
	mod := build(root, "./mod", ov)
	cat := build(root, "./cat", ov)
	res := build(root, "./cat/resources", ov)
	tr := build(root, "./cat/transformers", ov)

	get := func(v cue.Value, path string) string {
		x := v.LookupPath(cue.ParsePath(path))
		if !x.Exists() {
			return "<missing>"
		}
		s, err := x.String()
		if err != nil {
			return "<open>"
		}
		return s
	}

	return []row{
		{"module   metadata.fqn", get(mod, "metadata.fqn")},
		{"module   metadata.uuid", get(mod, "metadata.uuid")},
		{"catalog  metadata.fqn", get(cat, "metadata.fqn")},
		{"catalog  metadata.version", get(cat, "metadata.version")},
		{"resource metadata.fqn", get(res, "#ConfigMapsResource.metadata.fqn")},
		{"resource metadata.version", get(res, "#ConfigMapsResource.metadata.version")},
		{"transf.  metadata.fqn", get(tr, "#ConfigMapTransformer.metadata.fqn")},
		{"transf.  metadata.version", get(tr, "#ConfigMapTransformer.metadata.version")},
		{"module   demanded FQN", demandedFQN(mod)},
	}
}

// demandedFQN is the key the matcher will look up: the FQN of the primitive
// the module's component actually demands.
func demandedFQN(mod cue.Value) string {
	res := mod.LookupPath(cue.ParsePath("#components.config.#resources"))
	it, err := res.Fields(cue.All())
	if err != nil {
		return "<none>"
	}
	for it.Next() {
		return it.Selector().Unquoted()
	}
	return "<none>"
}

func compare(open, filled []row) {
	for i := range open {
		verdict := "same"
		if open[i].value != filled[i].value {
			verdict = "MOVED"
		}
		fmt.Printf("    %-5s %-28s open:   %s\n", verdict, open[i].label, open[i].value)
		if verdict == "MOVED" {
			fmt.Printf("    %-5s %-28s filled: %s\n", "", "", filled[i].value)
		}
	}
}

// ─── Plumbing ───────────────────────────────────────────────────────────────

func build(root, dir string, ov map[string]load.Source) cue.Value {
	ctx := cuecontext.New()
	insts := load.Instances([]string{dir}, &load.Config{Dir: root, Overlay: ov})
	if len(insts) == 0 {
		return ctx.CompileString("_|_")
	}
	if insts[0].Err != nil {
		return ctx.CompileString(fmt.Sprintf("_|_ // %v", insts[0].Err))
	}
	return ctx.BuildInstance(insts[0])
}

// fillVersionOverlay adds a sibling file to the identity package holding a
// concrete Version. This is what a FILLED tree evaluates to; it is done in
// memory so the committed tree stays open and reviewable.
func fillVersionOverlay(root, version string) map[string]load.Source {
	p := filepath.Join(root, "cat", "identity", "zz_filled.cue")
	return map[string]load.Source{
		p: load.FromString("package identity\n\nVersion: \"" + version + "\"\n"),
	}
}

// deleteVersionOverlay replaces identity.cue with a copy that never declares
// Version at all — the `absent` state, which is a malformed artifact rather
// than an unfinished one.
func deleteVersionOverlay(root string) map[string]load.Source {
	p := filepath.Join(root, "cat", "identity", "identity.cue")
	src, err := os.ReadFile(p)
	must(err)
	var keep []string
	for _, line := range strings.Split(string(src), "\n") {
		if strings.HasPrefix(line, "Version:") {
			continue
		}
		keep = append(keep, line)
	}
	return map[string]load.Source{p: load.FromString(strings.Join(keep, "\n"))}
}

func rel(root, s string) string { return strings.ReplaceAll(s, root+"/", "./") }

func contains(xs []string, s string) bool {
	for _, x := range xs {
		if x == s {
			return true
		}
	}
	return false
}

func section(title string) {
	fmt.Printf("\n%s\n%s\n\n", title, strings.Repeat("═", len(title)))
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
