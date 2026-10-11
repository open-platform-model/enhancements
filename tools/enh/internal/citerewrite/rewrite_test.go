package citerewrite

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// rewrite runs the engine on one file and returns the new text and the
// worklist rows as "line:kind".
func rewrite(t *testing.T, name, src string) (string, []string) {
	t.Helper()
	tt := DefaultTitles()
	res := Process(name, []byte(src), tt)
	out := apply(src, res.Edits)
	var sites []string
	for _, s := range res.Sites {
		sites = append(sites, fmt.Sprintf("%d:%s", s.Line, s.Kind))
	}
	// Idempotence: the output needs no second edit.
	if again := Process(name, []byte(out), tt); len(again.Edits) != 0 {
		t.Errorf("not idempotent: %d more edits on %q", len(again.Edits), out)
	}
	return out, sites
}

type rewriteCase struct {
	name  string
	file  string
	in    string
	want  string   // the new text; "" means unchanged
	sites []string // expected worklist rows
}

func runCases(t *testing.T, cases []rewriteCase) {
	t.Helper()
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			want := tc.want
			if want == "" {
				want = tc.in
			}
			got, sites := rewrite(t, tc.file, tc.in)
			if got != want {
				t.Errorf("output\n got: %q\nwant: %q", got, want)
			}
			if strings.Join(sites, " ") != strings.Join(tc.sites, " ") {
				t.Errorf("worklist\n got: %v\nwant: %v", sites, tc.sites)
			}
		})
	}
}

// Form 1: code comments, kind 2.
func TestFormCodeComment(t *testing.T) {
	runCases(t, []rewriteCase{
		{name: "parenthesis at sentence end", file: "a.go",
			in:   "package a\n\n// Rejects the second write (0010:D11).\nvar x = 1\n",
			want: "package a\n\n// Rejects the second write (enhancement 0010).\nvar x = 1\n"},
		{name: "spoken form in parentheses", file: "a.go",
			in:   "package a\n\n// Tightens the gate (enhancement 0015 D9).\nvar x = 1\n",
			want: "package a\n\n// Tightens the gate (enhancement 0015).\nvar x = 1\n"},
		{name: "bare spoken id", file: "a.cue",
			in:   "// Version filing (0010 D49): the key decides.\nx: 1\n",
			want: "// Version filing (enhancement 0010): the key decides.\nx: 1\n"},
		{name: "two ids", file: "a.go",
			in:   "package a\n\n// Edit the module (0010:D8, 0011:D12). Then run.\nvar x = 1\n",
			want: "package a\n\n// Edit the module (enhancements 0010 and 0011). Then run.\nvar x = 1\n"},
		{name: "three ids", file: "a.go",
			in:   "package a\n\n// Edit the module (0010:D8, 0019:D2, 0026:D1).\nvar x = 1\n",
			want: "package a\n\n// Edit the module (enhancements 0010, 0019 and 0026).\nvar x = 1\n"},
		{name: "duplicates collapse", file: "a.go",
			in:   "package a\n\n// Edit the module (0010:D8, 0010:D9 and 0010 D10).\nvar x = 1\n",
			want: "package a\n\n// Edit the module (enhancement 0010).\nvar x = 1\n"},
		{name: "decision list of one id", file: "a.go",
			in:   "package a\n\n// Edit the module (enhancement 0010 D4 and D7).\nvar x = 1\n",
			want: "package a\n\n// Edit the module (enhancement 0010).\nvar x = 1\n"},
		{name: "per at the end of the sentence", file: "a.go",
			in:   "package a\n\n// The limit is set by the registry, per 0010:D4.\nvar x = 1\n",
			want: "package a\n\n// The limit is set by the registry (enhancement 0010).\nvar x = 1\n"},
		{name: "per without comma", file: "a.go",
			in:   "package a\n\n// The limit is set by the registry per 0010:D4. Next sentence.\nvar x = 1\n",
			want: "package a\n\n// The limit is set by the registry (enhancement 0010). Next sentence.\nvar x = 1\n"},
		{name: "after a dash in a parenthesis", file: "a.cue",
			in:   "// Experimental (v1alpha1 contracts — 0010 D34).\nx: 1\n",
			want: "// Experimental (v1alpha1 contracts — enhancement 0010).\nx: 1\n"},
		{name: "wrapped paragraph, citation on the second line", file: "a.go",
			in:   "package a\n\n// Rejects the second write so the order is the order of the\n// file (0010:D11).\nvar x = 1\n",
			want: "package a\n\n// Rejects the second write so the order is the order of the\n// file (enhancement 0010).\nvar x = 1\n"},
		{name: "lead word on the line above", file: "a.go",
			in:   "package a\n\n// Rejects the second write (enhancement\n// 0010:D11).\nvar x = 1\n",
			want: "package a\n\n// Rejects the second write (enhancement\n// 0010).\nvar x = 1\n"},
		{name: "block comment", file: "a.go",
			in:   "package a\n\n/* Rejects the second write (0010:D11). */\nvar x = 1\n",
			want: "package a\n\n/* Rejects the second write (enhancement 0010). */\nvar x = 1\n"},
		{name: "block comment lines", file: "a.go",
			in:   "package a\n\n/*\n * Rejects the second write\n * and says why (0010:D11, 0011:D2).\n */\nvar x = 1\n",
			want: "package a\n\n/*\n * Rejects the second write\n * and says why (enhancements 0010 and 0011).\n */\nvar x = 1\n"},
		{name: "trailing comment", file: "a.go",
			in:   "package a\n\nvar x = 1 // fixed width (0010:D3)\n",
			want: "package a\n\nvar x = 1 // fixed width (enhancement 0010)\n"},
		{name: "cue template", file: "r.cue.tmpl",
			in:   "// Renders the thing (enhancement 0019 D5).\nx: 1\n",
			want: "// Renders the thing (enhancement 0019).\nx: 1\n"},
		{name: "requirement part goes", file: "a.go",
			in:   "package a\n\n// Rejects the second write (0010:D4:R1/R2).\nvar x = 1\n",
			want: "package a\n\n// Rejects the second write (enhancement 0010).\nvar x = 1\n"},
		{name: "already correct", file: "a.go",
			in: "package a\n\n// Rejects the second write (enhancements 0010 and 0026).\nvar x = 1\n"},
	})
}

// Kinds 1 and 3, open questions, strings and the rest: only the worklist.
func TestCodeWorklistOnly(t *testing.T) {
	runCases(t, []rewriteCase{
		{name: "kind 1 lone id", file: "a.go",
			in: "package a\n\n// 0010:D4\nvar x = 1\n", sites: []string{"3:lone-id"}},
		{name: "kind 1 parenthesis alone", file: "a.go",
			in: "package a\n\n// (0010:D4)\nvar x = 1\n", sites: []string{"3:lone-id"}},
		{name: "kind 1 WHY label", file: "a.cue",
			in: "// WHY declaredFQN: 0010:D49.\nx: 1\n", sites: []string{"1:lone-id"}},
		{name: "kind 3 inside the sentence", file: "a.go",
			in: "package a\n\n// The 0010:D34 ladder decides the level.\nvar x = 1\n", sites: []string{"3:inline"}},
		{name: "kind 3 the contract is", file: "a.go",
			in: "package a\n\n// The contract is 0012:D4 and nothing else.\nvar x = 1\n", sites: []string{"3:inline"}},
		{name: "possessive", file: "a.go",
			in: "package a\n\n// This is 0010:D30's denylist.\nvar x = 1\n", sites: []string{"3:possessive"}},
		{name: "open question", file: "a.cue",
			in: "// Open until the vote (0014:OQ2).\nx: 1\n", sites: []string{"1:oq"}},
		{name: "string literal", file: "a.go",
			in: "package a\n\nvar s = \"retired (0006:D21)\"\n", sites: []string{"3:string"}},
		{name: "raw string over two lines", file: "a.go",
			in: "package a\n\nvar s = `a\nb 0006 D21`\n", sites: []string{"4:string"}},
		{name: "path with decisions", file: "a.go",
			in: "package a\n\n// See `enhancements/0010` D1, D6 for the split.\nvar x = 1\n", sites: []string{"3:path-decisions"}},
		{name: "citation split over two comment lines", file: "a.go",
			in: "package a\n\n// Rejects the write because it breaks the order (0010:D11,\n// 0011:D2).\nvar x = 1\n", sites: []string{"3:wrapped", "4:wrapped"}},
		{name: "path to an entry file in a comment", file: "a.go",
			in: "package a\n\n// Measured in enhancements/0026/experiments/01-x and more.\nvar x = 1\n", sites: []string{"3:entry-file"}},
		{name: "path to an entry in a comment", file: "a.go",
			in: "package a\n\n// Defined in enhancements/0026 and more.\nvar x = 1\n", sites: []string{"3:path-ref"}},
		{name: "generated file", file: "zz_generated_a.go",
			in: "// Code generated by x. DO NOT EDIT.\n\npackage a\n\n// Rejects the write (0010:D11).\nvar x = 1\n", sites: []string{"5:generated"}},
	})
}

// A bare id and an old "enhancement 0010 D4" mix: only the citation changes.
func TestCodeOnlyTheCitationChanges(t *testing.T) {
	in := "package a\n\nfunc f() {\n\t// Keep the tab   and the double blank (0010:D11).\n\tx := 1 // (0010:D12)\n\t_ = x\n}\n"
	got, sites := rewrite(t, "a.go", in)
	want := "package a\n\nfunc f() {\n\t// Keep the tab   and the double blank (enhancement 0010).\n\tx := 1 // (enhancement 0010)\n\t_ = x\n}\n"
	// the trailing "// (0010:D12)" is a lone id paragraph
	want = strings.Replace(want, "// (enhancement 0010)\n\t_ = x", "// (0010:D12)\n\t_ = x", 1)
	if got != want || len(sites) != 1 || sites[0] != "5:lone-id" {
		t.Errorf("got %q sites %v", got, sites)
	}
}

// Form 2: Markdown and YAML text.
func TestFormText(t *testing.T) {
	d4, _ := DefaultTitles().Title("0010", 4)
	d7, _ := DefaultTitles().Title("0010", 7)
	d11, _ := DefaultTitles().Title("0010", 11)
	q := func(s string) string { return Quoted(s) }
	runCases(t, []rewriteCase{
		{name: "sentence", file: "a.md",
			in:   "The key decides (see 0010:D4) the level.\n",
			want: "The key decides (enhancement 0010, " + q(d4) + ") the level.\n"},
		{name: "inline, not parenthesised", file: "a.md",
			in:   "Per 0010:D4 the key decides.\n",
			want: "Per enhancement 0010 (" + q(d4) + ") the key decides.\n"},
		{name: "sentence start capital", file: "a.md",
			in:   "0010:D4 decides the key.\n",
			want: "Enhancement 0010 (" + q(d4) + ") decides the key.\n"},
		{name: "lead word kept", file: "a.md",
			in:   "Enhancement 0010 D4 decides the key.\n",
			want: "Enhancement 0010 (" + q(d4) + ") decides the key.\n"},
		{name: "two decisions of one id", file: "a.md",
			in:   "Rules: enhancement 0010 D4 and D7 hold.\n",
			want: "Rules: enhancement 0010 (" + q(d4) + " and " + q(d7) + ") hold.\n"},
		{name: "requirement part goes", file: "a.md",
			in:   "x 0010:D4:R1/R2 y\n",
			want: "x enhancement 0010 (" + q(d4) + ") y\n"},
		{name: "two ids", file: "a.md",
			in:   "x 0010:D4 and 0010:D11 y\n",
			want: "x enhancement 0010 (" + q(d4) + " and " + q(d11) + ") y\n"},
		{name: "backticks go with the citation", file: "a.md",
			in:   "x `0010:D4` y\n",
			want: "x enhancement 0010 (" + q(d4) + ") y\n"},
		{name: "heading is a worklist row", file: "a.md",
			in: "### Filing (0010 D4)\n", sites: []string{"1:heading"}},
		{name: "table cell", file: "a.md",
			in:   "| Rule | Source |\n| --- | --- |\n| key | 0010:D4 |\n",
			want: "| Rule | Source |\n| --- | --- |\n| key | enhancement 0010 (" + q(d4) + ") |\n"},
		{name: "link with a citation as text", file: "a.md",
			in:   "x ([0010:D11](/enhancements/0010/decisions/)). y\n",
			want: "x (enhancement 0010 (" + q(d11) + ")). y\n"},
		{name: "html comment", file: "a.md",
			in:   "<!-- see 0010:D4 -->\n",
			want: "<!-- see enhancement 0010 (" + q(d4) + ") -->\n"},
		{name: "yaml comment", file: "a.yaml",
			in:   "# keep the key (0010:D4)\nkey: value\n",
			want: "# keep the key (enhancement 0010, " + q(d4) + ")\nkey: value\n"},
		{name: "possessive stays", file: "a.md",
			in: "x 0010:D4's rule\n", sites: []string{"1:possessive"}},
		{name: "open question stays", file: "a.md",
			in: "x 0014:OQ2 is open\n", sites: []string{"1:oq"}},
		{name: "fenced block stays", file: "a.md",
			in: "```cue\n// x (0010:D4)\n```\n", sites: []string{"2:fenced"}},
		{name: "longer code span stays", file: "a.md",
			in: "run `grep 0010:D4 x` now\n", sites: []string{"1:code-span"}},
		{name: "unknown decision stays", file: "a.md",
			in: "x 0010:D999 y\n", sites: []string{"1:unknown-decision"}},
		{name: "id of no entry stays", file: "a.md",
			in: "x 0099:D1 y\n", sites: []string{"1:unknown-id"}},
		{name: "no match: year, date, version", file: "a.md",
			in: "In 2026 D4 and 2026-10-11 D4, v1.0010 D3 and 10010 D4. portal:D4 is local.\n"},
		{name: "decision anchor link", file: "a.md",
			in: "its first decision is [D1](/enhancements/0001/decisions/#d1)\n", sites: []string{"1:decision-anchor"}},
	})
}

func TestFormTextYAML(t *testing.T) {
	d4, _ := DefaultTitles().Title("0010", 4)
	d4 = strings.ReplaceAll(d4, "`", "`") // titles carry backticks; no YAML special
	runCases(t, []rewriteCase{
		{name: "block scalar", file: "a.yaml",
			in:   "rule: |\n  keep the key (0010:D4)\n  next line\n",
			want: "rule: |\n  keep the key (enhancement 0010, " + Quoted(d4) + ")\n  next line\n"},
		{name: "double quoted", file: "a.yaml",
			in:   "rule: \"keep the key (0010:D4)\"\n",
			want: "rule: \"keep the key (enhancement 0010, \\\"" + d4 + "\\\")\"\n"},
		{name: "single quoted", file: "a.yaml",
			in:   "rule: 'keep the key (0010:D4)'\n",
			want: "rule: 'keep the key (enhancement 0010, " + Quoted(d4) + ")'\n"},
		{name: "plain scalar", file: "a.yaml",
			in:   "rule: keep the key (0010:D4)\n",
			want: "rule: keep the key (enhancement 0010, " + Quoted(d4) + ")\n"},
		{name: "plain scalar with a colon in the title stays", file: "a.yaml",
			in: "rule: keep the key (0001:D10)\n", sites: []string{"1:unsafe-yaml"}},
		{name: "list item", file: "a.yaml",
			in:   "- keep the key (0010:D4)\n",
			want: "- keep the key (enhancement 0010, " + Quoted(d4) + ")\n"},
		{name: "flow sequence stays", file: "a.yaml",
			in: "rules: [keep the key (0010:D4)]\n", sites: []string{"1:unsafe-yaml"}},
		{name: "trailing comment", file: "a.yaml",
			in:   "key: value # keep it (0010:D4)\n",
			want: "key: value # keep it (enhancement 0010, " + Quoted(d4) + ")\n"},
		{name: "shell comment", file: "a.sh",
			in:   "#!/bin/sh\n# keep it (0010:D4)\necho \"0010:D4\"\n",
			want: "#!/bin/sh\n# keep it (enhancement 0010, " + Quoted(d4) + ")\necho \"0010:D4\"\n", sites: []string{"3:string"}},
	})
}

// Form 3: 0030 and 0031 lose the id and keep the reason text.
func TestFormRetired(t *testing.T) {
	runCases(t, []rewriteCase{
		{name: "parenthesis at the end", file: "a.md",
			in: "The portal fails fast (0030:D3).\n", want: "The portal fails fast.\n"},
		{name: "parenthesis in the middle", file: "a.md",
			in: "The portal (0030:D3:R2) fails fast.\n", want: "The portal fails fast.\n"},
		{name: "per at the start", file: "a.md",
			in: "Per 0030:D4, the graph is read only.\n", want: "The graph is read only.\n"},
		{name: "per in the middle", file: "a.md",
			in: "The graph is, per 0030:D4, read only.\n", want: "The graph is, read only.\n"},
		{name: "see at the end", file: "a.md",
			in: "The graph is read only, see 0030:D4.\n", want: "The graph is read only.\n"},
		{name: "label", file: "a.md",
			in: "0030:D4: the graph is read only.\n", want: "The graph is read only.\n"},
		{name: "source sentence", file: "a.md",
			in: "The graph is read only. Source: 0030:D4:R5.\n", want: "The graph is read only.\n"},
		{name: "source sentence after text without stop", file: "a.md",
			in: "The graph is read only, Source: 0030:D4.\n", sites: []string{"1:retired-inline"}},
		{name: "list in parentheses", file: "a.md",
			in: "It holds (0030:D2, 0030:D3). Then more.\n", want: "It holds. Then more.\n"},
		{name: "mixed list keeps the live id", file: "a.md",
			in: "It holds (0030:D2 and 0010:D4).\n", want: "It holds (enhancement 0010, " + Quoted(titleOf("0010", 4)) + ").\n"},
		{name: "in a code comment", file: "a.go",
			in: "package a\n\n// It holds the line (0030:D2).\nvar x = 1\n", want: "package a\n\n// It holds the line.\nvar x = 1\n"},
		{name: "0031", file: "a.md",
			in: "It holds (0031:D2).\n", want: "It holds.\n"},
		{name: "inside the sentence stays", file: "a.md",
			in: "The rule 0030:D6:R2 wants a non-empty name.\n", sites: []string{"1:retired-inline"}},
		{name: "only the citation stays", file: "a.md",
			in: "(0030:D6)\n", sites: []string{"1:retired-lone"}},
		{name: "wrapped line that opens with the parenthesis", file: "a.md",
			in: "a sentence that goes on\n(0030:D5:R4). A new one.\n", sites: []string{"2:retired-inline"}},
		{name: "bare id", file: "a.md",
			in: "Where this design and 0030 disagree, 0030 wins.\n", sites: []string{"1:retired-id", "1:retired-id"}},
	})
}

func titleOf(id string, n int) string {
	t, _ := DefaultTitles().Title(id, n)
	return t
}

// Form 4: paths and site URLs.
func TestFormPath(t *testing.T) {
	runCases(t, []rewriteCase{
		{name: "folder in prose", file: "a.md",
			in:   "The design lives in enhancements/0010 and more.\n",
			want: "The design lives in enhancement 0010 and more.\n"},
		{name: "folder with slash in a code span", file: "a.md",
			in:   "see `enhancements/0009/` now\n",
			want: "see enhancement 0009 now\n"},
		{name: "relative link with a bare id", file: "a.md",
			in:   "Enhancement [0006](../../../../enhancements/0006/) makes it.\n",
			want: "Enhancement 0006 makes it.\n"},
		{name: "relative link with words", file: "a.md",
			in:   "see [the entry](../enhancements/0006/) now\n",
			want: "see the entry (enhancement 0006) now\n"},
		{name: "file inside an entry", file: "a.md",
			in: "see `enhancements/0019/schemas/target.cue` now\n", sites: []string{"1:entry-file"}},
		{name: "converted entry slug", file: "a.md",
			in:   "[the rules](/enhancements/0013/decisions/#d3) and [why](/enhancements/0013/problem/) and [more](/enhancements/0013/graduation/)\n",
			want: "[the rules](/enhancements/0013/requirements/) and [why](/enhancements/0013/proposal/) and [more](/enhancements/0013/tasks/)\n"},
		{name: "converted entry keeps new slug and design", file: "a.md",
			in: "[a](/enhancements/0013/tasks/) [b](/enhancements/0013/design/#x) [c](/enhancements/0013/)\n"},
		{name: "archived entry keeps its slug", file: "a.md",
			in: "[the rules](/enhancements/0010/decisions/#d3) [c](/enhancements/0010/)\n"},
		{name: "yaml", file: "a.yaml",
			in:   "# see enhancements/0010 for it\nkey: value\n",
			want: "# see enhancement 0010 for it\nkey: value\n"},
		{name: "not a path: other directory", file: "a.md",
			in: "x library/enhancements/001 y\n"},
	})
}

func TestRunFiles(t *testing.T) {
	root := t.TempDir()
	write := func(rel, body string, mode os.FileMode) {
		p := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), mode); err != nil {
			t.Fatal(err)
		}
	}
	d4 := titleOf("0010", 4)
	write("docs/a.md", "Keeps the key (0010:D4)", 0o640) // no trailing newline
	write("run.sh", "#!/bin/sh\n# keep it (0010:D4)\n", 0o755)
	write("openspec/changes/archive/2026-01-01-x/enhancement.yaml", "enhancement: \"0010\"\n", 0o644)
	write("openspec/changes/live/proposal.md", "Keeps the key (0010:D4)\n", 0o644)
	write("tests/fixtures/f.cue", "// Keeps the key (0010:D4).\nx: 1\n", 0o644)
	write("vendor/v.go", "package v\n\n// Keeps the key (0010:D4).\n", 0o644)
	write("CHANGELOG.md", "- fix (0010:D4)\n", 0o644)
	write("src/a.go", "package a\n\n// Keeps the key (0010:D4).\n", 0o644)
	excl := []string{"tests/fixtures/", "openspec/changes/live/"}

	rep, err := Run(Options{Root: root, Exclude: excl})
	if err != nil {
		t.Fatal(err)
	}
	if len(rep.Changed) != 3 || len(rep.Deleted) != 1 {
		t.Fatalf("dry run: changed %v deleted %v", rep.Changed, rep.Deleted)
	}
	body, _ := os.ReadFile(filepath.Join(root, "docs/a.md"))
	if string(body) != "Keeps the key (0010:D4)" {
		t.Fatalf("a dry run changed a file: %q", body)
	}
	if _, err := os.Stat(filepath.Join(root, "openspec/changes/archive/2026-01-01-x/enhancement.yaml")); err != nil {
		t.Fatalf("a dry run deleted a file: %v", err)
	}

	if _, err := Run(Options{Root: root, Exclude: excl, Write: true}); err != nil {
		t.Fatal(err)
	}
	body, _ = os.ReadFile(filepath.Join(root, "docs/a.md"))
	if want := "Keeps the key (enhancement 0010, " + Quoted(d4) + ")"; string(body) != want {
		t.Errorf("a.md = %q, want %q (no newline added)", body, want)
	}
	info, _ := os.Stat(filepath.Join(root, "run.sh"))
	if info.Mode().Perm() != 0o755 {
		t.Errorf("run.sh mode = %v", info.Mode().Perm())
	}
	info, _ = os.Stat(filepath.Join(root, "docs/a.md"))
	if info.Mode().Perm() != 0o640 {
		t.Errorf("a.md mode = %v", info.Mode().Perm())
	}
	if _, err := os.Stat(filepath.Join(root, "openspec/changes/archive/2026-01-01-x/enhancement.yaml")); err == nil {
		t.Errorf("enhancement.yaml was not deleted")
	}
	for _, rel := range []string{"openspec/changes/live/proposal.md", "tests/fixtures/f.cue", "vendor/v.go", "CHANGELOG.md"} {
		b, _ := os.ReadFile(filepath.Join(root, rel))
		if !strings.Contains(string(b), "0010:D4") {
			t.Errorf("%s was rewritten: %q", rel, b)
		}
	}
	// A second write changes nothing.
	rep, err = Run(Options{Root: root, Exclude: excl, Write: true})
	if err != nil || len(rep.Changed) != 0 || len(rep.Deleted) != 0 || len(rep.Sites) != 0 {
		t.Errorf("second write: %+v err=%v", rep, err)
	}
}

func effTitle(id string, n int) string {
	_, t, _ := DefaultTitles().Effective(id, n)
	return t
}

// The cases of the two reviews T5.10a and T5.10b.
func TestReviewCases(t *testing.T) {
	d5 := Quoted(effTitle("0011", 5))
	runCases(t, []rewriteCase{
		// T5.10a blocking 1: a title holds no decision number
		{name: "0012 D1 short form has no id", file: "a.md",
			in:   "| b | 0012:D1 |\n",
			want: "| b | enhancement 0012 (" + Quoted(effTitle("0012", 1)) + ") |\n"},
		{name: "0025 D3 resolves to its moved target", file: "a.md",
			in:   "Moved: 0025:D3.\n",
			want: "Moved: enhancement 0027 (" + Quoted(effTitle("0027", 3)) + ").\n"},
		{name: "0025 D3 in a code comment names 0027", file: "a.go",
			in:   "package a\n\n// Reads the limit (0025:D3).\nvar x = 1\n",
			want: "package a\n\n// Reads the limit (enhancement 0027).\nvar x = 1\n"},
		{name: "merged decision resolves inside its entry", file: "a.md",
			in:   "x 0010:D12 y\n",
			want: "x enhancement 0010 (" + Quoted(effTitle("0010", 10)) + ") y\n"},
		// T5.10a blocking 2: generated files
		{name: "controller-gen annotation marks a file generated", file: "crd.yaml",
			in:    "metadata:\n  annotations:\n    controller-gen.kubebuilder.io/version: v0.19.0\n# there is no range (0010:D14)\n",
			sites: []string{"4:generated"}},
		// T5.10a should-fix 1: a retired lead-in mid-sentence keeps the clause break
		{name: "retired per then semicolon", file: "a.go",
			in:   "package a\n\n// We cache it per 0030:D4; the next call reads it.\nvar x = 1\n",
			want: "package a\n\n// We cache it; the next call reads it.\nvar x = 1\n"},
		{name: "retired per then colon", file: "a.go",
			in:   "package a\n\n// Do it per 0030:D4: the rule says so.\nvar x = 1\n",
			want: "package a\n\n// Do it: the rule says so.\nvar x = 1\n"},
		{name: "retired per then comma", file: "a.go",
			in:   "package a\n\n// We cache it per 0030:D4, so the next call reads it.\nvar x = 1\n",
			want: "package a\n\n// We cache it, so the next call reads it.\nvar x = 1\n"},
		{name: "retired per then semicolon in Markdown", file: "a.md",
			in:   "We cache it per 0030:D4; the next call reads it.\n",
			want: "We cache it; the next call reads it.\n"},
		// T5.10a should-fix 2: an id glued to a word
		{name: "glued by a hyphen in a comment", file: "a.go",
			in: "package a\n\n// The fallback (PRE-0010:D41) applies.\nvar x = 1\n", sites: []string{"3:inline"}},
		{name: "glued by a hyphen without a word before", file: "a.go",
			in: "package a\n\n// Uses the value (x-0010:D4) here.\nvar x = 1\n", sites: []string{"3:inline"}},
		{name: "glued by a hyphen in Markdown", file: "a.md",
			in: "The fallback PRE-0010:D41 holds.\n", sites: []string{"1:inline"}},
		{name: "glued by a letter after", file: "a.go",
			in: "package a\n\n// L4 suffix 0010:D4x keeps it.\nvar x = 1\n", sites: []string{"3:inline"}},
		{name: "two ids joined by a slash are not glued", file: "a.go",
			in:   "package a\n\n// Reads the limit, per 0010:D4/0011:D5.\nvar x = 1\n",
			want: "package a\n\n// Reads the limit (enhancements 0010 and 0011).\nvar x = 1\n"},
		// T5.10a should-fix 3: a comment after a quoted YAML value
		{name: "comment after a double-quoted value", file: "a.yaml",
			in:   "key: \"value per 0010:D4\" # see 0011:D5\n",
			want: "key: \"value per enhancement 0010 (\\\"" + effTitle("0010", 4) + "\\\")\" # see enhancement 0011 (" + d5 + ")\n"},
		// T5.10a should-fix 5: form 1 checks the table
		{name: "unknown id and decision in a comment", file: "a.go",
			in: "package a\n\n// Unknown (0099:D1) and (0010:D999).\nvar x = 1\n", sites: []string{"3:unknown-id", "3:unknown-decision"}},
		// T5.10a nit 1: a dash goes with the lead-in
		{name: "dash before see", file: "a.go",
			in:   "package a\n\n// Hyphen dash case - see 0010:D4.\nvar x = 1\n",
			want: "package a\n\n// Hyphen dash case (enhancement 0010).\nvar x = 1\n"},
		// T5.10a should-fix 4: a CUE template is source
		{name: "template with GENERATED in its text", file: "r.cue.tmpl",
			in:   "// GENERATED by the OPM kernel for one render (enhancement 0019 D9).\nx: 1\n",
			want: "// GENERATED by the OPM kernel for one render (enhancement 0019).\nx: 1\n"},
		{name: "template with the Go header is generated", file: "r.cue.tmpl",
			in:    "// Code generated by x. DO NOT EDIT.\n// Renders (0010:D4).\nx: 1\n",
			sites: []string{"2:generated"}},
		// T5.10a question 2 and ruling 5: headings
		{name: "heading with a spoken citation", file: "a.md",
			in: "### D2: deviating from enhancement 0011 D14/D17 item 5\n", sites: []string{"1:heading"}},
		{name: "heading without a citation is untouched", file: "a.md",
			in: "### D2: deviating\n"},
		{name: "hash comment in a fence is not a heading", file: "a.md",
			in: "```sh\n# 0010:D4\n```\n", sites: []string{"2:fenced"}},
		// T5.10b should-fix 1: the old colon rule is the minimum
		{name: "colon floor: any four digits", file: "a.go",
			in: "package a\n\n// typo id 1234:D5 keeps it.\nvar x = 1\n", sites: []string{"3:unknown-id"}},
		{name: "colon floor: question suffix", file: "a.go",
			in: "package a\n\n// question 0010:OQ2b keeps it.\nvar x = 1\n", sites: []string{"3:oq"}},
		{name: "quoted comment keeps its own quote rule", file: "a.yaml",
			in:   "plain: reads per 0011:D5 # see it\n",
			want: "plain: reads per enhancement 0011 (" + d5 + ") # see it\n"},
	})
}
