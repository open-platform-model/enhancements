package reconcile

import (
	"os"
	"path/filepath"
	"reflect"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"testing"
)

func tree(t *testing.T, root string, files map[string]string) {
	t.Helper()
	for rel, body := range files {
		p := filepath.Join(root, filepath.FromSlash(rel))
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

// TestEntryReposMatchSchema keeps the Go list equal to #EntryRepo in schema.cue.
func TestEntryReposMatchSchema(t *testing.T) {
	src, err := os.ReadFile(filepath.Join("..", "..", "..", "..", "schema.cue"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(src)
	i := strings.Index(text, "#EntryRepo:")
	if i < 0 {
		t.Fatal("schema.cue has no #EntryRepo")
	}
	block := text[i:]
	if end := strings.Index(block, "\n\n"); end >= 0 {
		block = block[:end]
	}
	var want []string
	for _, m := range regexp.MustCompile(`"([^"]+)"`).FindAllStringSubmatch(block, -1) {
		want = append(want, m[1])
	}
	got := append([]string{}, EntryRepos...)
	sort.Strings(got)
	sort.Strings(want)
	if !reflect.DeepEqual(got, want) {
		t.Errorf("EntryRepos differs from #EntryRepo\n go:  %q\ncue: %q", got, want)
	}
}

func TestParseDeclarations(t *testing.T) {
	src := "# Change\n\n## Enhancement\n\nDelivers 0013, task 2.1.\n- Delivers 0013, task 2.10\n" +
		"<!-- Delivers 0099, task 9.9. -->\n```\nDelivers 0098, task 1.1.\n```\nNone.\nDelivers 13, task 1.1.\n"
	got, bad := ParseDeclarations(src)
	want := []Declaration{{Entry: "0013", Task: "2.1", Line: 5}, {Entry: "0013", Task: "2.10", Line: 6}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("got %+v\nwant %+v", got, want)
	}
	// "Delivers 13, task 1.1." opens like a Delivers line and is malformed.
	if !reflect.DeepEqual(bad, []int{12}) {
		t.Errorf("malformed lines: %v", bad)
	}
}

func TestParseDeclarationsMalformed(t *testing.T) {
	src := "Delivers 0013, task 1.1 and 1.2.\nDelivers 0013 task 1.1.\nDelivers 0013, tasks 1.1.\n" +
		"`Delivers 0013, task 1.1.`\nDelivers task 1.1.\nDelivers a better build for everyone.\n"
	got, bad := ParseDeclarations(src)
	if len(got) != 0 || !reflect.DeepEqual(bad, []int{1, 2, 3, 4, 5}) {
		t.Errorf("got %+v, malformed %v", got, bad)
	}
}

func TestParseTasks(t *testing.T) {
	src := "<!--\n- [x] 1.1 <repo>: example (a-change)\n-->\n## 1. Theme\n\n" +
		"- [ ] 1.1 core: open\n" +
		"- [x] 1.2 library: done (add-thing)\n" +
		"- [x] 1.3 cli: two changes (one-change, two-change)\n" +
		"- [x] 1.4 opm-controller: by pr (PR 12)\n" +
		"- [x] 1.5 catalog_opm: no ref (see below)\n" +
		"- [X] 1.6 modules: plain\n" +
		"- [x] 1.7 core: backticks (`add-field`).\n" +
		"- [x] 1.8 core: mixed (PR 3, add-field)\n"
	got := ParseTasks(src)
	type row struct {
		line int
		id   string
		done bool
		refs []string
		pr   bool
	}
	var rows []row
	for _, t := range got {
		rows = append(rows, row{t.Line, t.ID, t.Done, t.Refs, t.PR})
	}
	want := []row{
		{6, "1.1", false, nil, false},
		{7, "1.2", true, []string{"add-thing"}, false},
		{8, "1.3", true, []string{"one-change", "two-change"}, false},
		{9, "1.4", true, nil, true},
		{10, "1.5", true, nil, false},
		{11, "1.6", true, nil, false},
		{12, "1.7", true, []string{"add-field"}, false},
		{13, "1.8", true, []string{"add-field"}, true},
	}
	if !reflect.DeepEqual(rows, want) {
		t.Errorf("got %+v\nwant %+v", rows, want)
	}
}

const tasks13 = `## 1. Core

- [x] 1.1 core: add the field (add-field)
- [ ] 1.2 core: document it

## 2. Library

- [x] 2.1 library: read it (read-field)
- [x] 2.2 library: lost (renamed-away)
- [x] 2.3 cli: unverifiable repo (some-change)
- [x] 2.4 catalog_opm: by name (publish-catalog)
- [ ] 2.5 opm-controller: archived, unticked
- [ ] 2.6 library: in flight
`

func fixture(t *testing.T) (enh string, repos []Repo) {
	t.Helper()
	ws := t.TempDir()
	enh = filepath.Join(ws, "enhancements")
	tree(t, ws, map[string]string{
		"enhancements/openspec/changes/0013-secrets/tasks.md":                   tasks13,
		"enhancements/openspec/changes/archive/2026-09-01-0012-render/tasks.md": "- [x] 1.1 core: x (add-field)\n",
		"enhancements/openspec/changes/0014-draft/proposal.md":                  "x\n",

		"core/openspec/changes/add-field/proposal.md":                    "Delivers 0013, task 1.1.\n",
		"core/openspec/changes/archive/2026-09-02-doc-field/proposal.md": "## Enhancement\n\nDelivers 0013, task 1.2.\n",
		"core/openspec/changes/archive/2026-09-03-typo/proposal.md":      "Delivers 0013, task 7.7.\nDelivers 0077, task 1.1.\nDelivers 0014, task 1.1.\n",

		"library/openspec/changes/read-field/proposal.md":              "Delivers 0013, task 2.1.\n",
		"library/openspec/changes/archive/2026-09-04-more/proposal.md": "None.\n",
		"library/openspec/changes/live-one/proposal.md":                "Delivers 0013, task 2.6.\n",

		"catalog_opm/openspec/changes/archive/2026-09-05-publish-catalog/proposal.md": "Delivers 0013, task 2.4.\n",
		"opm-controller/openspec/changes/archive/2026-09-06-operate/proposal.md":        "Delivers 0013, task 2.5.\n",
		"opm/README.md": "a repo without OpenSpec\n",
	})
	for _, n := range []string{"core", "library", "catalog_opm", "opm-controller", "opm"} {
		repos = append(repos, Repo{Name: n, Root: filepath.Join(ws, n)})
	}
	return enh, repos
}

func TestRun(t *testing.T) {
	enh, repos := fixture(t)
	rep, err := Run(enh, repos)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, f := range rep.Flags {
		got = append(got, f.Kind+" "+f.Path[strings.LastIndex(f.Path, "/")+1:]+":"+strconv.Itoa(f.Line))
	}
	sort.Strings(got)
	want := []string{
		// case 1: archived change declares task 1.2, the line is open
		"unticked tasks.md:4",
		// case 1 again: the archived controller change declares 2.5
		"unticked tasks.md:12",
		// case 2: a tick names a change the repo does not have
		"missing-change tasks.md:9",
		// case 3: task 7.7 does not exist, entry 0077 does not exist, entry 0014 has no tasks.md
		"unknown-task proposal.md:1",
		"unknown-task proposal.md:2",
		"unknown-task proposal.md:3",
	}
	sort.Strings(want)
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Fatalf("flags\n got: %q\nwant: %q\n%v", got, want, rep.Flags)
	}
	if len(rep.InFlight) != 3 {
		t.Errorf("in flight: %+v, want add-field, read-field and live-one", rep.InFlight)
	}
	if rep.Declarations != 9 {
		t.Errorf("declarations: %d, want 9", rep.Declarations)
	}
	if !reflect.DeepEqual(rep.Skipped, []string{"opm: no openspec/changes"}) {
		t.Errorf("skipped: %q", rep.Skipped)
	}
	if !strings.Contains(rep.Summary(), "2 unticked, 1 missing-change, 3 unknown-task, 0 malformed, 3 in flight") {
		t.Errorf("summary: %s", rep.Summary())
	}
}

func TestRunTickedAndArchivedIsClean(t *testing.T) {
	ws := t.TempDir()
	tree(t, ws, map[string]string{
		"enhancements/openspec/changes/0013-x/tasks.md":                  "- [x] 1.1 core: a (add-field)\n- [x] 1.2 core: b (PR 4)\n",
		"core/openspec/changes/archive/2026-09-01-add-field/proposal.md": "Delivers 0013, task 1.1.\n",
	})
	rep, err := Run(filepath.Join(ws, "enhancements"), []Repo{{"core", filepath.Join(ws, "core")}})
	if err != nil || len(rep.Flags) != 0 || rep.Declarations != 1 {
		t.Fatalf("rep=%+v err=%v", rep, err)
	}
}

func TestRunRefusesAWrongRepoName(t *testing.T) {
	if _, err := Run(t.TempDir(), []Repo{{"catalog", t.TempDir()}}); err == nil ||
		!strings.Contains(err.Error(), "catalog_opm") {
		t.Fatalf("want an error that names catalog_opm, got %v", err)
	}
	r := Repo{"core", t.TempDir()}
	if _, err := Run(t.TempDir(), []Repo{r, r}); err == nil {
		t.Fatal("want an error for a repo listed twice")
	}
}

func TestRunRefusesADuplicateEntryID(t *testing.T) {
	ws := t.TempDir()
	tree(t, ws, map[string]string{
		"enhancements/openspec/changes/0013-x/tasks.md":                    "x\n",
		"enhancements/openspec/changes/archive/2026-01-01-0013-y/tasks.md": "x\n",
	})
	if _, err := Run(filepath.Join(ws, "enhancements"), nil); err == nil {
		t.Fatal("want an error for an id in two folders")
	}
}

func TestSiblingRepos(t *testing.T) {
	ws := t.TempDir()
	tree(t, ws, map[string]string{"core/a": "x", "docs-kit/a": "x", "enhancements/a": "x", "unrelated/a": "x"})
	repos, missing := SiblingRepos(ws)
	var names []string
	for _, r := range repos {
		names = append(names, r.Name)
	}
	if !reflect.DeepEqual(names, []string{"core", "docs-kit"}) {
		t.Errorf("repos: %q", names)
	}
	if len(missing) != len(EntryRepos)-3 {
		t.Errorf("missing: %q", missing)
	}
}

func TestRunReadsEveryFolderOfAReusedName(t *testing.T) {
	ws := t.TempDir()
	tree(t, ws, map[string]string{
		"enhancements/openspec/changes/0013-x/tasks.md":            "- [ ] 1.1 core: a\n- [ ] 1.2 core: b\n- [ ] 1.3 core: c\n",
		"core/openspec/changes/archive/2026-01-01-fix/proposal.md": "Delivers 0013, task 1.1.\n",
		"core/openspec/changes/archive/2026-02-01-fix/proposal.md": "Delivers 0013, task 1.2.\n",
		"core/openspec/changes/fix/proposal.md":                    "Delivers 0013, task 1.3.\n",
	})
	rep, err := Run(filepath.Join(ws, "enhancements"), []Repo{{"core", filepath.Join(ws, "core")}})
	if err != nil {
		t.Fatal(err)
	}
	if rep.Declarations != 3 || len(rep.Flags) != 2 || len(rep.InFlight) != 1 {
		t.Fatalf("declarations %d, flags %v, in flight %v", rep.Declarations, rep.Flags, rep.InFlight)
	}
}

func TestRunFlagsLinesItCannotRead(t *testing.T) {
	ws := t.TempDir()
	tree(t, ws, map[string]string{
		"enhancements/openspec/changes/0013-x/tasks.md": "- [x] 1.1 core: no ref\n- [x] 1.2 core: backticks (`add-field`)\n",
		"core/openspec/changes/add-field/proposal.md":   "Delivers 0013 task 1.2.\n",
	})
	rep, err := Run(filepath.Join(ws, "enhancements"), []Repo{{"core", filepath.Join(ws, "core")}})
	if err != nil {
		t.Fatal(err)
	}
	if len(rep.Flags) != 2 || rep.Flags[0].Kind != KindMalformed || rep.Flags[1].Kind != KindMalformed {
		t.Fatalf("flags: %v", rep.Flags)
	}
}
