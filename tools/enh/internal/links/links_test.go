package links

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// tree writes a fixture repo from a map of relative path to content.
func tree(t *testing.T, files map[string]string) string {
	t.Helper()
	root := t.TempDir()
	for rel, body := range files {
		p := filepath.Join(root, filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

// found renders findings as "path:line rule" for comparison.
func found(fs []Finding) []string {
	var out []string
	for _, f := range fs {
		out = append(out, f.Path+":"+itoa(f.Line)+" "+f.Rule)
	}
	sort.Strings(out)
	return out
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	var b []byte
	for ; n > 0; n /= 10 {
		b = append([]byte{byte('0' + n%10)}, b...)
	}
	return string(b)
}

func expect(t *testing.T, got []Finding, want ...string) {
	t.Helper()
	sort.Strings(want)
	g := found(got)
	if strings.Join(g, "\n") != strings.Join(want, "\n") {
		t.Errorf("findings\n got: %q\nwant: %q", g, want)
	}
}

const (
	live13 = "openspec/changes/0013-secret-field-attributes"
	live14 = "openspec/changes/0014-export-lines"
	arch12 = "openspec/changes/archive/2026-09-01-0012-render"
)

func fixture(t *testing.T) string {
	return tree(t, map[string]string{
		"schema.cue": "package x\n",
		"INDEX.md": "# Index\n\n[0013](" + live13 + "/README.md) and [old](archive/0016/README.md)\n" +
			"[bad](openspec/changes/0099-none/README.md)\n",
		"GRAPH.md": "[abs](/INDEX.md)\n[out](../../x.md)\n",

		live13 + "/README.md":             "[proposal](proposal.md) [design](./design.md#how) [ev](evidence/note.md)\n",
		live13 + "/proposal.md":           "See [the schema](../../../schema.cue).\n[other](../0014-export-lines/README.md)\n[arch](../archive/2026-09-01-0012-render/README.md)\n[dir](../archive/)\n",
		live13 + "/design.md":             "Round trip [in](../0013-secret-field-attributes/proposal.md) is the same entry.\n[gone](missing.md)\n",
		live13 + "/tasks.md":              "- [ ] 1.1 core: x\n",
		live13 + "/specs/secrets/spec.md": "[up](../../proposal.md)\n[other](../../../0014-export-lines/proposal.md)\n",
		// Not published: only the cross-entry rule applies.
		live13 + "/evidence/note.md":    "[broken](nowhere.md)\n[cross](../../0014-export-lines/README.md)\n",
		live14 + "/README.md":           "ok\n",
		live14 + "/proposal.md":         "ok\n",
		arch12 + "/README.md":           "[self](proposal.md)\n",
		arch12 + "/proposal.md":         "[live](../../0013-secret-field-attributes/README.md)\n",
		"archive/0016/README.md":        "[to 0014](../../0014/)\n[own](02-design.md)\n",
		"archive/0016/02-design.md":     "[to 0014](../../0014/README.md#x)\n",
		"0014/README.md":                "[x](../archive/0016/README.md)\n",
		"0000/README.md":                "[template](nothing.md)\n",
		"0000/03-decisions.md":          "x\n",
		"archive/0016/experiments/a.md": "[loose](missing.md)\n",
	})
}

func TestCheck(t *testing.T) {
	root := fixture(t)
	res, err := Check(root)
	if err != nil {
		t.Fatal(err)
	}
	expect(t, res.Findings,
		// generated files may link to entries; only broken targets count
		"INDEX.md:4 broken",
		"GRAPH.md:1 absolute",
		"GRAPH.md:2 outside-repo",
		// V28
		live13+"/proposal.md:2 cross-entry",
		live13+"/proposal.md:3 cross-entry",
		live13+"/proposal.md:4 cross-entry",
		live13+"/specs/secrets/spec.md:2 cross-entry",
		live13+"/evidence/note.md:2 cross-entry",
		arch12+"/proposal.md:1 cross-entry",
		"archive/0016/README.md:1 cross-entry",
		"archive/0016/02-design.md:1 cross-entry",
		"0014/README.md:1 cross-entry",
		// resolution on the published set
		live13+"/design.md:2 broken",
	)
}

func TestCheckFilesResolvesEveryFile(t *testing.T) {
	root := fixture(t)
	res, err := CheckFiles(root, []string{live13 + "/evidence/note.md"})
	if err != nil {
		t.Fatal(err)
	}
	expect(t, res.Findings, live13+"/evidence/note.md:1 broken", live13+"/evidence/note.md:2 cross-entry")
	if _, err := CheckFiles(root, []string{"nope.md"}); err == nil {
		t.Fatal("want an error for a file that does not exist")
	}
}

func TestPublished(t *testing.T) {
	root := fixture(t)
	got, err := Published(root)
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"INDEX.md", "GRAPH.md", live13 + "/README.md", live13 + "/specs/secrets/spec.md",
		"archive/0016/README.md", "archive/0016/02-design.md", arch12 + "/proposal.md", "0014/README.md",
	} {
		if !contains(got, want) {
			t.Errorf("published set lacks %s", want)
		}
	}
	for _, not := range []string{live13 + "/evidence/note.md", "archive/0016/experiments/a.md", "0000/README.md"} {
		if contains(got, not) {
			t.Errorf("published set holds %s", not)
		}
	}
}

func contains(l []string, s string) bool {
	for _, x := range l {
		if x == s {
			return true
		}
	}
	return false
}

func TestExtract(t *testing.T) {
	src := "[a](one.md) and ![img](two.png \"title\") and [c](<three four.md>)\n" +
		"`[code](skip.md)` outside [d](four.md#frag)\n" +
		"```\n[fenced](skip2.md)\n```\n" +
		"~~~~\n```\n[still fenced](skip3.md)\n```\n~~~~\n" +
		"<!-- [hidden](skip4.md) -->\n" +
		"<!--\n[hidden2](skip5.md)\n-->\n" +
		"[ref]: five.md\n" +
		"[after](six.md)\n"
	var got []string
	for _, l := range extract(src) {
		got = append(got, l.target)
	}
	want := []string{"one.md", "two.png", "three four.md", "four.md#frag", "five.md", "six.md"}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Errorf("targets\n got: %q\nwant: %q", got, want)
	}
}

func TestExternalAnchorAndEscapes(t *testing.T) {
	root := tree(t, map[string]string{
		"INDEX.md": "[w](https://example.test/a) [m](mailto:a@b.test) [h](#top) [s](with%20space.md#x) [q](with%20space.md?x=1)\n" +
			"[colon](dir/a:b.md)\n",
		"with space.md": "x\n",
	})
	res, err := Check(root)
	if err != nil {
		t.Fatal(err)
	}
	expect(t, res.Findings, "INDEX.md:2 broken")
}

func TestLocate(t *testing.T) {
	for p, want := range map[string]place{
		"openspec/changes/0013-x/a.md":                 {entry: "openspec/changes/0013-x"},
		"openspec/changes/archive/2026-01-01-0012-x/a": {entry: "openspec/changes/archive/2026-01-01-0012-x"},
		"openspec/changes/archive":                     {archive: true},
		"archive":                                      {archive: true},
		"archive/0016/a.md":                            {entry: "archive/0016"},
		"0014/README.md":                               {entry: "0014"},
		"openspec/specs/x/spec.md":                     {},
		"schema.cue":                                   {},
		"tools/enh/go.mod":                             {},
	} {
		if got := locate(p); got != want {
			t.Errorf("locate(%q) = %+v, want %+v", p, got, want)
		}
	}
}
