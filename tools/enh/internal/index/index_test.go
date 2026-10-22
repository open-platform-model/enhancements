package index

import (
	"bytes"
	"flag"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"testing"
	"testing/fstest"
)

var update = flag.Bool("update", false, "rewrite the golden files in testdata/tree.want")

const (
	fixture = "testdata/tree"
	golden  = "testdata/tree.want"
)

func loadFixture(t *testing.T) *Tree {
	t.Helper()
	tree, err := Load(os.DirFS(fixture))
	if err != nil {
		t.Fatalf("Load(%s): %v", fixture, err)
	}
	return tree
}

func TestGenerate_golden(t *testing.T) {
	files, err := Generate(loadFixture(t))
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if *update {
		if err := os.RemoveAll(golden); err != nil {
			t.Fatal(err)
		}
		for _, f := range files {
			p := filepath.Join(golden, filepath.FromSlash(f.Path))
			if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(p, f.Content, 0o644); err != nil {
				t.Fatal(err)
			}
		}
	}
	var got []string
	for _, f := range files {
		got = append(got, f.Path)
		want, err := os.ReadFile(filepath.Join(golden, filepath.FromSlash(f.Path)))
		if err != nil {
			t.Errorf("%s: no golden file: %v (run go test -update, then read the diff)", f.Path, err)
			continue
		}
		if !bytes.Equal(want, f.Content) {
			t.Errorf("%s differs from its golden file:\n%s", f.Path, lineDiff(string(want), string(f.Content)))
		}
	}
	// Every golden file must be a generated one: no stale golden.
	var want []string
	err = filepath.WalkDir(golden, func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, _ := filepath.Rel(golden, p)
		want = append(want, filepath.ToSlash(rel))
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	slices.Sort(want)
	if !slices.Equal(got, want) {
		t.Errorf("generated paths = %v, golden paths = %v", got, want)
	}
}

func TestGenerate_pathsAndScope(t *testing.T) {
	files, err := Generate(loadFixture(t))
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	for _, f := range files {
		if err := checkPath(f.Path); err != nil {
			t.Errorf("generated path %s: %v", f.Path, err)
		}
		if strings.HasSuffix(f.Path, "README.md") && strings.HasPrefix(f.Path, "archive/") {
			t.Errorf("%s: an old-layout README must not be generated", f.Path)
		}
		if bytes.Contains(f.Content, []byte("updated")) {
			t.Errorf("%s mentions `updated`; a new-layout entry has none", f.Path)
		}
		if !bytes.HasSuffix(f.Content, []byte("\n")) || bytes.HasSuffix(f.Content, []byte("\n\n")) || bytes.Contains(f.Content, []byte("\r")) {
			t.Errorf("%s must end in exactly one LF and hold no CR", f.Path)
		}
	}
}

func TestGenerate_stableBytes(t *testing.T) {
	a, err := Generate(loadFixture(t))
	if err != nil {
		t.Fatal(err)
	}
	// A second load from an in-memory copy of the tree, in a different file order.
	mem := fstest.MapFS{}
	err = fs.WalkDir(os.DirFS(fixture), ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		b, err := fs.ReadFile(os.DirFS(fixture), p)
		mem[p] = &fstest.MapFile{Data: b}
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	tree, err := Load(mem)
	if err != nil {
		t.Fatal(err)
	}
	b, err := Generate(tree)
	if err != nil {
		t.Fatal(err)
	}
	if len(a) != len(b) {
		t.Fatalf("two runs gave %d and %d files", len(a), len(b))
	}
	for i := range a {
		if a[i].Path != b[i].Path || !bytes.Equal(a[i].Content, b[i].Content) {
			t.Errorf("run 2 differs at %s", a[i].Path)
		}
	}
}

func TestGenerate_graphProperties(t *testing.T) {
	files, err := Generate(loadFixture(t))
	if err != nil {
		t.Fatal(err)
	}
	var graph string
	for _, f := range files {
		if f.Path == GraphPath {
			graph = string(f.Content)
		}
	}
	for _, want := range []string{
		"N0026 -->|after| N0010",
		"N0027 -->|after| N0026",
		"N0040 -->|after| N0033",
		"N0026 ==>|supersedes| N0036",
		"N0027 ==>|supersedes| N0036",
	} {
		if !strings.Contains(graph, want) {
			t.Errorf("GRAPH.md has no edge %q", want)
		}
	}
	// 0033 -> 0003 joins two closed entries: dropped. 0034 and 0035 have no edge: not drawn.
	for _, bad := range []string{"N0033 -->|after| N0003", "N0034[", "N0035[", "N0003[", "N0042["} {
		if strings.Contains(graph, bad) {
			t.Errorf("GRAPH.md holds %q, which is a closed entry no live edge reaches", bad)
		}
	}
	// A closed entry that a live edge reaches is drawn.
	for _, want := range []string{`N0033["0033: Delivered Thing"]:::delivered`, `N0036[`, `N0010["0010 · distribution"]:::stub`} {
		if !strings.Contains(graph, want) {
			t.Errorf("GRAPH.md has no node %q", want)
		}
	}
	if !strings.Contains(graph, "…") {
		t.Error("the long title of 0040 is not cut")
	}
}

func TestCategoriesMatchSchema(t *testing.T) {
	b, err := os.ReadFile("../../../../schema.cue")
	if err != nil {
		t.Fatal(err)
	}
	m := regexp.MustCompile(`(?m)^#Category:\s*(.+)$`).FindSubmatch(b)
	if m == nil {
		t.Fatal("no #Category line in schema.cue")
	}
	var got []string
	for _, q := range regexp.MustCompile(`"([a-z]+)"`).FindAllSubmatch(m[1], -1) {
		got = append(got, string(q[1]))
	}
	if !slices.Equal(got, Categories) {
		t.Errorf("schema.cue #Category = %v, Categories = %v", got, Categories)
	}
}

func TestReadingTime(t *testing.T) {
	tests := []struct {
		words int
		want  string
	}{{1, "1 min"}, {124, "1 min"}, {394, "2 min"}, {1617, "6 min"}, {3000, "12 min"}}
	for _, tt := range tests {
		if got := readingTime(tt.words); got != tt.want {
			t.Errorf("readingTime(%d) = %q, want %q", tt.words, got, tt.want)
		}
	}
}

func TestParseTasks(t *testing.T) {
	text := "<!-- a\n- [ ] 9.9 x: hidden -->\n## 1. First theme\n\n- [x] 1.1 core: done (c1)\n- [ ] 1.2 cli: open\nprose line\n## 2. Second\n- [X] 2.1 opm: upper (PR 4) <!-- inline -->\n- [ ] bad line\n"
	got := ParseTasks(text)
	if len(got) != 2 || got[0].Title != "1. First theme" || got[1].Title != "2. Second" {
		t.Fatalf("sections = %+v", got)
	}
	if len(got[0].Tasks) != 2 || !got[0].Tasks[0].Done || got[0].Tasks[1].Done {
		t.Errorf("section 1 tasks = %+v", got[0].Tasks)
	}
	if want := (Task{Num: "2.1", Repo: "opm", Outcome: "upper (PR 4)", Done: true}); len(got[1].Tasks) != 1 || got[1].Tasks[0] != want {
		t.Errorf("section 2 tasks = %+v, want [%+v]", got[1].Tasks, want)
	}
	if got := ParseTasks("- [ ] 1.1 core: first\n"); len(got) != 1 || got[0].Title != "Tasks" {
		t.Errorf("a task before any heading: %+v", got)
	}
	if got := ParseTasks(""); len(got) != 0 {
		t.Errorf("empty file: %+v", got)
	}
}

func TestStatusLine(t *testing.T) {
	yes, no := true, false
	task := func(done bool) []Section {
		return []Section{{Title: "1. A", Tasks: []Task{{Num: "1.1", Repo: "core", Done: done}}}}
	}
	tests := []struct {
		name string
		e    Entry
		want string
	}{
		{"draft", Entry{Status: StatusDraft, Created: "2026-09-08"}, "**Draft** 2026-09-08"},
		{"draft breaking", Entry{Status: StatusDraft, Created: "2026-09-08", Breaking: &yes}, "**Draft** 2026-09-08 · breaking"},
		{"draft not breaking", Entry{Status: StatusDraft, Created: "2026-09-08", Breaking: &no}, "**Draft** 2026-09-08"},
		{"accepted no tasks", Entry{Status: StatusAccepted, Accepted: "2026-10-16 4be19d0"}, "**Accepted** 2026-10-16 · ready to implement"},
		{"accepted none shipped", Entry{Status: StatusAccepted, Accepted: "2026-10-16 4be19d0", Tasks: task(false)}, "**Accepted** 2026-10-16 · ready to implement · 0 of 1 tasks shipped"},
		{"accepted all shipped", Entry{Status: StatusAccepted, Accepted: "2026-10-16 4be19d0", Tasks: task(true)}, "**Accepted** 2026-10-16 · ready to deliver · 1 of 1 tasks shipped"},
		{"delivered", Entry{Status: StatusDelivered, ArchiveDate: "2026-10-20", Tasks: task(true), Breaking: &yes}, "**Delivered** 2026-10-20 · 1 of 1 tasks shipped · breaking"},
		{"rejected", Entry{Status: StatusRejected, Rejected: &Ending{Date: "2026-10-01", Reason: "no"}}, "**Rejected** 2026-10-01"},
		{"withdrawn", Entry{Status: StatusWithdrawn, Withdrawn: &Ending{Date: "2026-10-02", Reason: "no"}}, "**Withdrawn** 2026-10-02"},
		{"superseded two", Entry{Status: StatusSuperseded, Superseded: &Superseded{Date: "2026-10-03", IDs: []string{"0010", "0011"}}}, "**Superseded** 2026-10-03 by 0010 and 0011"},
		{"superseded three", Entry{Status: StatusSuperseded, Superseded: &Superseded{Date: "2026-10-03", IDs: []string{"0010", "0011", "0012"}}}, "**Superseded** 2026-10-03 by 0010, 0011 and 0012"},
	}
	for _, tt := range tests {
		if got := statusLine(&tt.e); got != tt.want {
			t.Errorf("%s: statusLine = %q, want %q", tt.name, got, tt.want)
		}
	}
}

func cfg(extra string) *fstest.MapFile {
	base := "id: \"0050\"\nslug: thing\ntitle: Thing\nsummary: A thing.\nstatus: draft\ncategory: tooling\naffects: [opm]\nauthors: [a]\ncreated: \"2026-10-01\"\n"
	return &fstest.MapFile{Data: []byte(base + extra)}
}

func TestLoad_errors(t *testing.T) {
	tests := []struct {
		name string
		fs   fstest.MapFS
		want string
	}{
		{"missing config", fstest.MapFS{"openspec/changes/0050-thing/proposal.md": &fstest.MapFile{}}, "config.yaml: missing"},
		{"folder without id", fstest.MapFS{"openspec/changes/thing/config.yaml": cfg("")}, "not <id>-<slug>"},
		{"archived folder without date", fstest.MapFS{"openspec/changes/archive/0050-thing/config.yaml": cfg("")}, "not <YYYY-MM-DD>-<id>-<slug>"},
		{"id differs from folder", fstest.MapFS{"openspec/changes/0051-thing/config.yaml": cfg("")}, `id "0050" does not match`},
		{"slug differs from folder", fstest.MapFS{"openspec/changes/0050-other/config.yaml": cfg("")}, `slug "thing" does not match`},
		{"bad category", fstest.MapFS{"openspec/changes/0050-thing/config.yaml": &fstest.MapFile{Data: []byte(strings.Replace(string(cfg("").Data), "tooling", "stuff", 1))}}, `category "stuff"`},
		{"bad status", fstest.MapFS{"openspec/changes/0050-thing/config.yaml": &fstest.MapFile{Data: []byte(strings.Replace(string(cfg("").Data), "draft", "wip", 1))}}, `status "wip"`},
		{"no status", fstest.MapFS{"openspec/changes/0050-thing/config.yaml": &fstest.MapFile{Data: []byte("id: \"0050\"\nslug: thing\ntitle: T\ncategory: misc\n")}}, "status is missing"},
		{"bad after", fstest.MapFS{"openspec/changes/0050-thing/config.yaml": cfg("after: [\"12\"]\n")}, `after holds "12"`},
		{"bad yaml", fstest.MapFS{"openspec/changes/0050-thing/config.yaml": &fstest.MapFile{Data: []byte("id: [\n")}}, "config.yaml"},
		{"same id twice", fstest.MapFS{
			"openspec/changes/0050-thing/config.yaml":                    cfg(""),
			"openspec/changes/archive/2026-10-01-0050-thing/config.yaml": cfg(""),
		}, "id 0050 is in two folders"},
		{"bad superseded_by", fstest.MapFS{"openspec/changes/0050-thing/config.yaml": cfg("superseded_by: [x]\n")}, "superseded_by"},
		{"capability without spec", fstest.MapFS{"openspec/specs/cap/other.md": &fstest.MapFile{}}, "spec.md: missing"},
	}
	for _, tt := range tests {
		_, err := Load(tt.fs)
		if err == nil || !strings.Contains(err.Error(), tt.want) {
			t.Errorf("%s: Load error = %v, want it to hold %q", tt.name, err, tt.want)
		}
	}
}

func TestLoad_allErrorsAtOnce(t *testing.T) {
	_, err := Load(fstest.MapFS{
		"openspec/changes/0050-a/config.yaml": &fstest.MapFile{Data: []byte("id: \"0050\"\n")},
		"openspec/changes/0051-b/config.yaml": &fstest.MapFile{Data: []byte("id: \"0051\"\n")},
	})
	if err == nil || !strings.Contains(err.Error(), "0050-a") || !strings.Contains(err.Error(), "0051-b") {
		t.Errorf("Load error = %v, want both folders named", err)
	}
}

func TestLoad_emptyAndSeedsOnly(t *testing.T) {
	tree, err := Load(fstest.MapFS{
		"openspec/changes/seed-x/source.md":                          &fstest.MapFile{},
		"openspec/changes/archive/2026-10-14-seed-y/source.md":       &fstest.MapFile{},
		"openspec/changes/correction-z/source.md":                    &fstest.MapFile{},
		"openspec/changes/archive/2026-10-15-correction-w/source.md": &fstest.MapFile{},
	})
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(tree.Entries) != 0 {
		t.Errorf("entries = %d, want none: seeds are not entries", len(tree.Entries))
	}
	files, err := Generate(tree)
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	if len(files) != 2 {
		t.Errorf("an empty tree gives %d files, want INDEX.md and GRAPH.md", len(files))
	}
}

func TestLoad_yamlDatesStayText(t *testing.T) {
	tree := loadFixture(t)
	e := tree.Entry("0027")
	if e == nil || e.Created != "2026-10-07" {
		t.Fatalf("0027 created = %+v, want the text 2026-10-07 from an unquoted YAML date", e)
	}
	if r := tree.Entry("0034"); r == nil || r.Rejected == nil || r.Rejected.Date != "2026-10-15" {
		t.Errorf("0034 rejected = %+v, want date 2026-10-15", r)
	}
	if o := tree.Entry("0003"); o == nil || o.Superseded == nil || !slices.Equal(o.Superseded.IDs, []string{"0010"}) {
		t.Errorf("0003 superseded = %+v, want the old string form read as 0010", o)
	}
	if o := tree.Entry("0010"); o == nil || o.Superseded != nil || o.Landings != 3 || o.LandedOn != "2026-08-28" {
		t.Errorf("0010 = %+v, want no successor, 3 landings, last on 2026-08-28", o)
	}
}

func TestGenerate_unknownReference(t *testing.T) {
	tests := []struct {
		name string
		fs   fstest.MapFS
		want string
	}{
		{"after", fstest.MapFS{"openspec/changes/0050-thing/config.yaml": cfg("after: [\"0099\"]\n")}, "0099"},
		{"superseded_by", fstest.MapFS{"openspec/changes/archive/2026-10-02-0050-thing/config.yaml": &fstest.MapFile{Data: []byte(
			strings.Replace(string(cfg("superseded_by: {date: \"2026-10-01\", ids: [\"0098\"], reason: r}\n").Data), "status: draft", "status: superseded", 1))}}, "0098"},
	}
	for _, tt := range tests {
		tree, err := Load(tt.fs)
		if err != nil {
			t.Errorf("%s: Load: %v", tt.name, err)
			continue
		}
		files, err := Generate(tree)
		if err == nil || !strings.Contains(err.Error(), tt.want) || files != nil {
			t.Errorf("%s: Generate = %v, %v; want an error that names %s and no file", tt.name, files, err, tt.want)
		}
	}
}

func TestCheckPath(t *testing.T) {
	for _, p := range []string{"INDEX.md", "openspec/changes/0026-x/README.md"} {
		if err := checkPath(p); err != nil {
			t.Errorf("checkPath(%q) = %v, want ok", p, err)
		}
	}
	for _, p := range []string{"", "/INDEX.md", "../INDEX.md", "a/../b", "openspec/specs/x/spec.md", "openspec/changes/0026-x/specs/a/spec.md", "a//b", `a\b`} {
		if err := checkPath(p); err == nil {
			t.Errorf("checkPath(%q) = nil, want an error", p)
		}
	}
}

// An old-layout entry that is still live is a valid `after` and
// `superseded_by` target, so that every commit of the migration passes
// whatever the order of the conversion. It is drawn from its config.yaml.
func TestGenerate_oldLiveEntryIsATarget(t *testing.T) {
	old := strings.NewReplacer("id: \"0050\"", "id: \"0051\"", "status: draft", "status: superseded").
		Replace(string(cfg("superseded_by: {date: \"2026-10-01\", ids: [\"0021\"], reason: r}\n").Data))
	oldLive := func(id string) *fstest.MapFile {
		return &fstest.MapFile{Data: []byte(strings.Replace(string(cfg("").Data), `id: "0050"`, `id: "`+id+`"`, 1))}
	}
	mfs := fstest.MapFS{
		"openspec/changes/0050-thing/config.yaml":                    cfg("after: [\"0021\", \"0027\"]\n"),
		"openspec/changes/archive/2026-10-02-0051-thing/config.yaml": &fstest.MapFile{Data: []byte(old)},
		"0021/config.yaml": oldLive("0021"),
		"0027/config.yaml": oldLive("0027"),
		"0000/config.yaml": &fstest.MapFile{Data: []byte("id: \"0000\"\n")},
	}
	tree, err := Load(mfs)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if !slices.Equal(tree.OldLiveIDs, []string{"0021", "0027"}) {
		t.Fatalf("OldLiveIDs = %v, want 0021 and 0027 (0000 is the template)", tree.OldLiveIDs)
	}
	files, err := Generate(tree)
	if err != nil {
		t.Fatalf("Generate: %v", err)
	}
	for _, f := range files {
		if f.Path == "GRAPH.md" && !strings.Contains(string(f.Content), "N0021") {
			t.Errorf("GRAPH.md does not draw the old live entry 0021")
		}
	}
	// An id that is neither an entry nor an old live folder is still refused.
	delete(mfs, "0027/config.yaml")
	tree, err = Load(mfs)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := Generate(tree); err == nil || !strings.Contains(err.Error(), "0027") {
		t.Errorf("Generate = %v, want an error that names 0027", err)
	}
}

func TestLoad_oldLiveEntries(t *testing.T) {
	tree := loadFixture(t)
	e := tree.Entry("0044")
	if e == nil || e.Layout != LayoutLegacyLive || e.Dir != "0044" {
		t.Fatalf("0044 = %+v, want an old live entry in folder 0044", e)
	}
	if !slices.Equal(e.After, []string{"0010", "0040"}) {
		t.Errorf("0044 After = %v, want its depends_on", e.After)
	}
	// The converted 0027 stands for the old 0027/ folder.
	if c := tree.Entry("0027"); c == nil || c.Layout != LayoutOpenSpec || c.Title != "Self-Service Kinds from Published Modules" {
		t.Errorf("0027 = %+v, want the converted entry", c)
	}
	if !slices.Contains(tree.OldLiveIDs, "0027") {
		t.Errorf("OldLiveIDs = %v, want 0027 listed: the folder still exists", tree.OldLiveIDs)
	}
	files, err := Generate(tree)
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range files {
		if strings.Contains(string(f.Content), "old layout)") {
			t.Errorf("%s shows the text of the old 0027 folder", f.Path)
		}
		if strings.HasSuffix(f.Path, "README.md") && strings.HasPrefix(f.Path, "0044") {
			t.Errorf("%s: an old live entry gets no generated README", f.Path)
		}
	}
}

func TestLoad_oldLiveErrors(t *testing.T) {
	// A folder with no config.yaml is no entry and no error.
	if tree, err := Load(fstest.MapFS{"0021/proposal.md": &fstest.MapFile{}}); err != nil || len(tree.Entries) != 0 {
		t.Errorf("Load = %v, %v; want no entry and no error", tree, err)
	}
	// A config.yaml that is not the folder's entry is an error.
	_, err := Load(fstest.MapFS{"0021/config.yaml": cfg("")})
	if err == nil || !strings.Contains(err.Error(), "does not match the folder id") {
		t.Errorf("Load = %v, want an id mismatch", err)
	}
}

// A correction beside entries changes no generated byte: it is not an entry.
func TestGenerate_correctionLeavesOutputUnchanged(t *testing.T) {
	base := fstest.MapFS{
		"openspec/changes/0050-a/config.yaml": &fstest.MapFile{Data: []byte("id: \"0050\"\nslug: a\ntitle: A\nsummary: S.\nstatus: draft\ncategory: tooling\ncreated: 2026-10-01\nbreaking: false\naffects: [core]\n")},
	}
	with := fstest.MapFS{}
	for k, v := range base {
		with[k] = v
	}
	with["openspec/changes/correction-z/source.md"] = &fstest.MapFile{}
	with["openspec/changes/archive/2026-10-15-correction-w/source.md"] = &fstest.MapFile{}
	gen := func(f fstest.MapFS) map[string]string {
		tree, err := Load(f)
		if err != nil {
			t.Fatalf("Load: %v", err)
		}
		files, err := Generate(tree)
		if err != nil {
			t.Fatalf("Generate: %v", err)
		}
		out := map[string]string{}
		for _, g := range files {
			out[g.Path] = string(g.Content)
		}
		return out
	}
	a, b := gen(base), gen(with)
	if len(a) != len(b) {
		t.Fatalf("files: %d without, %d with a correction", len(a), len(b))
	}
	for p, c := range a {
		if b[p] != c {
			t.Errorf("%s differs with a correction beside the entry", p)
		}
	}
}
