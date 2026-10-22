package entry

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

func write(t *testing.T, root, rel, text string) {
	t.Helper()
	p := filepath.Join(root, rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestLoadStore(t *testing.T) {
	root := t.TempDir()
	c := "openspec/changes/0100-demo/"
	write(t, root, c+"config.yaml", "id: \"0100\"\nslug: demo\ncreated: 2026-10-07\nbreaking: false\nstatus: draft\n")
	write(t, root, c+".openspec.yaml", "schema: enhancement\ncreated: 2026-10-07\nskip_specs: true\n")
	write(t, root, c+"proposal.md", "# 0100: Demo\n\n## Why\n\nx\n\n## Open questions\n\n- Blocking: why?\n- Answered: yes\n- Not blocking: when?\n- stray\n  continued here\n")
	write(t, root, c+"tasks.md", "<!-- c\n- [ ] 9.9 x: y -->\n## 1. A\n\n- [ ] 1.1 core: do it\n- [x] 1.2 cli: done (my-change)\n- [x] 1.3 cli: quoted (`quoted-change`)\n- [x] bad line\n")
	write(t, root, c+"specs/cap/spec.md", "## ADDED Requirements\n\n### Requirement: A\n\nIt SHALL.\n\n#### Scenario: s\n\n- **WHEN** a\n")
	write(t, root, c+"evidence/README.md", "x")
	write(t, root, c+"evidence/sub/a.md", "x")
	write(t, root, "openspec/changes/seed-cap/source.md", "x")
	write(t, root, "openspec/changes/archive/2026-10-14-seed-other/source.md", "x")
	write(t, root, "openspec/changes/correction-fix-cap/source.md", "x")
	write(t, root, "openspec/changes/archive/2026-10-15-correction-older/source.md", "x")
	write(t, root, "openspec/specs/cap/spec.md", "## Requirements\n\n### Requirement: M\n\nIt SHALL.\n")
	write(t, root, "archive/0001/config.yaml", "id: \"0001\"\n")
	write(t, root, "0005/config.yaml", "id: \"0005\"\n")

	st, err := LoadStore(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(st.Live) != 3 || len(st.Archived) != 2 || len(st.OldArchived) != 1 || len(st.LegacyLive) != 1 {
		t.Fatalf("store = live %d archived %d old %v legacy %v", len(st.Live), len(st.Archived), st.OldArchived, st.LegacyLive)
	}
	e := st.Find("0100")
	if e == nil || e.Kind != Enhancement || e.FolderSlug != "demo" {
		t.Fatalf("find = %+v", e)
	}
	if e.Config.ID != "0100" || e.Config.Created != "2026-10-07" || e.Config.Breaking == nil || *e.Config.Breaking {
		t.Errorf("config = %+v", e.Config)
	}
	if !e.SkipSpecs || len(e.OpenSpecKeys) != 3 {
		t.Errorf("openspec = %v skip=%v", e.OpenSpecKeys, e.SkipSpecs)
	}
	if len(e.Questions) != 4 || e.Questions[3].Text != "stray continued here" || e.Questions[0].Kind != "blocking" || e.Questions[1].Kind != "answered" || e.Questions[3].Kind != "" {
		t.Errorf("questions = %+v", e.Questions)
	}
	if len(e.TaskLines) != 3 || e.TaskLines[2].Ref != "quoted-change" || e.TaskLines[1].Ref != "my-change" || !e.TaskLines[1].Done || len(e.TaskLineErrors) != 1 {
		t.Errorf("tasks = %+v errs %v", e.TaskLines, e.TaskLineErrors)
	}
	if len(e.Specs) != 1 || e.Specs[0].Capability != "cap" {
		t.Errorf("specs = %+v", e.Specs)
	}
	if len(e.Evidence) != 2 || e.Evidence[1] != "sub/a.md" {
		t.Errorf("evidence = %v", e.Evidence)
	}
	seed := st.Find("seed-cap")
	if seed == nil || seed.Kind != Seed || seed.FolderSlug != "cap" {
		t.Errorf("seed = %+v", seed)
	}
	if a := st.Find("seed-other"); a == nil || !a.Archived || a.Date != "2026-10-14" {
		t.Errorf("archived seed = %+v", a)
	}
	corr := st.Find("correction-fix-cap")
	if corr == nil || corr.Kind != Correction || corr.FolderSlug != "fix-cap" || corr.FolderID != "" || !corr.Kind.Unnumbered() {
		t.Errorf("correction = %+v", corr)
	}
	if a := st.Find("correction-older"); a == nil || !a.Archived || a.Date != "2026-10-15" || a.Kind != Correction {
		t.Errorf("archived correction = %+v", a)
	}
	if st.Specs["cap"] == nil || len(st.Specs["cap"].By("MAIN")) != 1 {
		t.Errorf("main spec = %+v", st.Specs)
	}
}

func TestLoadBadConfig(t *testing.T) {
	root := t.TempDir()
	write(t, root, "openspec/changes/0100-demo/config.yaml", "id: a\nid: b\n")
	st, err := LoadStore(root)
	if err != nil {
		t.Fatal(err)
	}
	if st.Live[0].ConfigErr == nil {
		t.Error("duplicate key should be a config error")
	}
}

func TestLoadTypeErrorKeepsFields(t *testing.T) {
	root := t.TempDir()
	write(t, root, "openspec/changes/0100-demo/config.yaml", "id: \"0100\"\ntitle: [a, b]\nslug: demo\n")
	st, _ := LoadStore(root)
	e := st.Live[0]
	if e.ConfigErr == nil || e.Config.Slug != "demo" {
		t.Errorf("err=%v config=%+v", e.ConfigErr, e.Config)
	}
}

// A question is a list item at any depth, with a bullet or a number. A line
// with no marker continues the question above it.
func TestQuestionForms(t *testing.T) {
	root := t.TempDir()
	write(t, root, "openspec/changes/0100-demo/proposal.md", "# 0100: Demo\n\n## Open questions\n\n"+
		"- Blocking: plain\n"+
		"  - Blocking: indented\n"+
		"\t* Not blocking: tab and star\n"+
		"1. Blocking: numbered\n"+
		"  2) Answered: numbered and indented\n"+
		"+ Blocking: plus\n"+
		"- Blocking: wrapped\n  onto a second line\n")
	st, err := LoadStore(root)
	if err != nil {
		t.Fatal(err)
	}
	e := st.Find("0100")
	if e == nil {
		t.Fatal("no entry 0100")
	}
	var got []string
	for _, q := range e.Questions {
		got = append(got, q.Kind+"|"+q.Text)
	}
	want := []string{
		"blocking|plain", "blocking|indented", "not blocking|tab and star", "blocking|numbered",
		"answered|numbered and indented", "blocking|plus", "blocking|wrapped onto a second line",
	}
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Errorf("questions\n got: %q\nwant: %q", got, want)
	}
}

// The two unnumbered prefixes and the shared name pattern agree.
func TestUnnumberedPrefixes(t *testing.T) {
	re := regexp.MustCompile(UnnumberedNamePattern)
	for _, p := range []string{SeedPrefix, CorrectionPrefix, "2026-10-23-" + SeedPrefix, "2026-10-23-" + CorrectionPrefix} {
		if !re.MatchString(p + "x") {
			t.Errorf("pattern does not match %q", p+"x")
		}
	}
	if re.MatchString("0013-correction-x") || re.MatchString("fix-x") {
		t.Error("pattern matches a numbered or unknown folder")
	}
	if !Seed.Unnumbered() || !Correction.Unnumbered() || Enhancement.Unnumbered() {
		t.Error("Unnumbered is wrong")
	}
}
