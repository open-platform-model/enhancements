package vet

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const schemaPath = "../../../../schema.cue"

// materialize copies testdata/base into a temp dir and lays the overlay
// testdata/<rule>/<kind> over it. A file named _delete in the overlay lists
// paths to remove, one per line.
func materialize(t *testing.T, rule, kind string) string {
	t.Helper()
	root := t.TempDir()
	copyTree(t, "testdata/base", root)
	overlay := filepath.Join("testdata", rule, kind)
	if _, err := os.Stat(overlay); err != nil {
		t.Fatalf("missing fixture %s: %v", overlay, err)
	}
	copyTree(t, overlay, root)
	if b, err := os.ReadFile(filepath.Join(root, "_delete")); err == nil {
		for _, p := range strings.Fields(string(b)) {
			if err := os.RemoveAll(filepath.Join(root, p)); err != nil {
				t.Fatal(err)
			}
		}
		os.Remove(filepath.Join(root, "_delete"))
	}
	return root
}

func copyTree(t *testing.T, src, dst string) {
	t.Helper()
	err := filepath.WalkDir(src, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(target, b, 0o644)
	})
	if err != nil {
		t.Fatal(err)
	}
}

// stubOpenSpec fails when the README.md of the root says "stub fails".
func stubOpenSpec(dir, name string, args ...string) ([]byte, error) {
	b, _ := os.ReadFile(filepath.Join(dir, "README.md"))
	if strings.Contains(string(b), "stub fails") {
		return []byte("Change has issues"), errors.New("exit status 1")
	}
	return []byte("ok"), nil
}

// fixtureGit serves the old entry files of testdata/V25/old whatever the commit.
func fixtureGit(_, _, path string) ([]byte, error) {
	return os.ReadFile(filepath.Join("testdata", "V25", "old", filepath.FromSlash(path)))
}

type invalidCase struct {
	dir      string
	contains string // a substring of the message
}

type ruleCase struct {
	rule    string
	mode    Mode
	level   Level
	invalid []invalidCase
	tune    func(*Options)
	// valid names the valid fixture; the default is "valid".
	valid string
}

func TestRules(t *testing.T) {
	cases := []ruleCase{
		{rule: "V1", level: Error, invalid: []invalidCase{{"invalid", "does not equal the folder prefix"}}},
		{rule: "V2", level: Error, invalid: []invalidCase{{"invalid", "81 characters"}, {"invalid-2", "conflicting values"}}},
		{rule: "V3", level: Error, invalid: []invalidCase{{"invalid", "folder is live"}}},
		{rule: "V4", level: Error, invalid: []invalidCase{{"invalid", "after today"}, {"invalid-2", "conflicting values"}}},
		{rule: "V5", mode: Accept, level: Error, invalid: []invalidCase{{"invalid", "breaking must be"}, {"invalid-2", "conflicting values"}}},
		{rule: "V6", level: Error, invalid: []invalidCase{{"invalid", "does not exist"}, {"invalid-2", "cycle"}, {"invalid-3", "after names the entry itself"}}},
		{rule: "V7", level: Error, invalid: []invalidCase{{"invalid", "never accepted"}, {"invalid-2", "must read"}}},
		{rule: "V8", level: Error, invalid: []invalidCase{{"invalid", "does not exist"}, {"invalid-2", "superseded_by names the entry itself"}}},
		{rule: "V9", level: Error, invalid: []invalidCase{{"invalid", "semver"}, {"invalid-2", "updated"}}},
		{rule: "V10", level: Error, invalid: []invalidCase{{"invalid", "also used by"}, {"invalid-2", "reserved"}, {"invalid-3", "archive/0001"}}},
		{rule: "V11", level: Error, invalid: []invalidCase{{"invalid", "owner"}}},
		{rule: "V12", mode: Draft, level: Warning, invalid: []invalidCase{{"invalid", "skip_specs is true but specs/ exists"}}},
		{rule: "V12", mode: Accept, level: Error, invalid: []invalidCase{{"invalid", "skip_specs is true but specs/ exists"}}},
		{rule: "V13", mode: Deliver, level: Error, invalid: []invalidCase{{"invalid", "retire_capabilities"}}},
		{rule: "V14", level: Error, invalid: []invalidCase{{"invalid", "design.md is missing"}}},
		{rule: "V14", level: Warning, invalid: []invalidCase{{"invalid-2", "unresolved placeholder"}}},
		{rule: "V15", level: Warning, invalid: []invalidCase{{"invalid", "301 words"}}},
		{rule: "V16", level: Warning, invalid: []invalidCase{{"invalid", "words"}, {"invalid", "characters of text"}}},
		{rule: "V17", level: Error, invalid: []invalidCase{{"invalid", "no #### Scenario"}}},
		{rule: "V18", level: Error, invalid: []invalidCase{{"invalid", "no SHALL or MUST"}}},
		{rule: "V19", level: Error, invalid: []invalidCase{{"invalid", "file path"}, {"invalid-2", "CLI flag"}, {"invalid-3", "Go symbol"}}},
		{rule: "V20", mode: Accept, level: Error, invalid: []invalidCase{{"invalid", "is not in openspec/specs"}, {"invalid-2", "already in openspec/specs"}}},
		{rule: "V21", level: Error, invalid: []invalidCase{{"invalid", "no **Migration**"}, {"invalid-2", "exactly"}, {"invalid-3", "no ADDED requirement of that name"}, {"invalid-4", "list item"}}},
		{rule: "V22", mode: Accept, level: Error, invalid: []invalidCase{{"invalid", "blocking question"}, {"invalid-2", "must move into design.md"}, {"invalid-3", "a blocking question is still open"}, {"invalid-4", "a blocking question is still open"}}},
		{rule: "V23", mode: Accept, level: Error, invalid: []invalidCase{{"invalid", `"cli" is in affects`}, {"invalid-2", "does not match"}}},
		{rule: "V24", mode: Deliver, level: Error, invalid: []invalidCase{{"invalid", "not ticked"}, {"invalid-2", "does not end with"}}},
		{rule: "V25", level: Error, invalid: []invalidCase{{"invalid", "0100:D1:R3 has no row"}, {"invalid-2", "say proposal but proposal.md lists"}}, tune: func(o *Options) { o.GitShow = fixtureGit }},
		{rule: "V28", level: Error, invalid: []invalidCase{{"invalid", "leads into 0014-other"}}},
		{rule: "V29", level: Warning, invalid: []invalidCase{{"invalid", "lost.md"}}},
		{rule: "V30", level: Warning, invalid: []invalidCase{{"invalid", "legacy live folders"}}},
		{rule: "V30", level: Error, invalid: []invalidCase{{"invalid", "legacy live folders"}}, tune: func(o *Options) { o.Final = true }},
		{rule: "V32", mode: Accept, level: Error, invalid: []invalidCase{{"invalid", "openspec validate"}}, tune: func(o *Options) { o.OpenSpec = stubOpenSpec }},
		{rule: "V33", level: Error, invalid: []invalidCase{{"invalid", "ADDED requirements only"}, {"invalid", "source.md is missing"}}},
		{rule: "V33", mode: Deliver, level: Error, valid: "valid-deliver", invalid: []invalidCase{{"invalid-2", "no \"sampled:"}}},
		{rule: "V34", mode: Accept, level: Error, invalid: []invalidCase{{"invalid", "no ## Purpose"}, {"invalid-2", "placeholder"}}},
		{rule: "V35", level: Error, invalid: []invalidCase{{"invalid", "--strict failed"}}, tune: func(o *Options) { o.OpenSpec = stubOpenSpec; o.Strict = true }},
	}
	for _, tc := range cases {
		name := tc.rule + "/" + tc.mode.String() + "/" + string(tc.level)
		t.Run(name+"/valid", func(t *testing.T) {
			if tc.valid == "" {
				tc.valid = "valid"
			}
			res := runCase(t, tc, tc.valid)
			for _, f := range res.Findings {
				if f.Rule == tc.rule {
					t.Errorf("valid fixture drew a %s finding: %s", tc.rule, f)
				}
			}
			if res.HasErrors() {
				var b strings.Builder
				res.Format(&b)
				t.Errorf("valid fixture has errors:\n%s", b.String())
			}
		})
		for _, inv := range tc.invalid {
			t.Run(name+"/"+inv.dir+"/"+inv.contains, func(t *testing.T) {
				res := runCase(t, tc, inv.dir)
				for _, f := range res.Findings {
					if f.Rule == tc.rule && f.Level == tc.level && strings.Contains(f.Msg, inv.contains) {
						return
					}
				}
				var b strings.Builder
				res.Format(&b)
				t.Errorf("no %s %s finding containing %q:\n%s", tc.level, tc.rule, inv.contains, b.String())
			})
		}
	}
}

func runCase(t *testing.T, tc ruleCase, kind string) *Result {
	t.Helper()
	root := materialize(t, tc.rule, kind)
	opts := Options{Root: root, Mode: tc.mode, Today: "2026-10-11", SchemaPath: schemaPath}
	if tc.tune != nil {
		tc.tune(&opts)
	}
	res, err := Run(opts)
	if err != nil {
		t.Fatal(err)
	}
	return res
}

// The base tree is clean in every mode.
func TestBaseIsClean(t *testing.T) {
	for _, m := range []Mode{Draft, Accept} {
		root := t.TempDir()
		copyTree(t, "testdata/base", root)
		res, err := Run(Options{Root: root, Mode: m, Today: "2026-10-11", SchemaPath: schemaPath})
		if err != nil {
			t.Fatal(err)
		}
		if len(res.Findings) != 0 {
			var b strings.Builder
			res.Format(&b)
			t.Errorf("mode %s: base has findings:\n%s", m, b.String())
		}
	}
}

// The modes change levels as the table of T2.3 section 2 says.
func TestModesChangeLevels(t *testing.T) {
	root := materialize(t, "V12", "invalid")
	for mode, want := range map[Mode]Level{Draft: Warning, Accept: Error, Deliver: Error} {
		res, err := Run(Options{Root: root, Mode: mode, Today: "2026-10-11", SchemaPath: schemaPath})
		if err != nil {
			t.Fatal(err)
		}
		got := Level("")
		for _, f := range res.Findings {
			if f.Rule == "V12" {
				got = f.Level
			}
		}
		if got != want {
			t.Errorf("V12 in %s: level %q, want %q", mode, got, want)
		}
	}
	// V5 and V20 are silent or lenient in draft and an error from accept on.
	root = materialize(t, "V20", "invalid")
	res, _ := Run(Options{Root: root, Mode: Draft, Today: "2026-10-11", SchemaPath: schemaPath})
	for _, f := range res.Findings {
		if f.Rule == "V20" {
			t.Errorf("V20 should be silent in draft: %s", f)
		}
	}
}

// An accepted entry is checked at accept level whatever the mode.
func TestAcceptedEntryRaisesMode(t *testing.T) {
	root := materialize(t, "V3", "valid") // status accepted, breaking false
	if err := os.WriteFile(filepath.Join(root, "openspec/changes/0100-demo-entry/tasks.md"), []byte("## 1. Demo\n\n- [ ] 1.1 enhancements: add the fixture\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	res, _ := Run(Options{Root: root, Today: "2026-10-11", SchemaPath: schemaPath})
	found := false
	for _, f := range res.Findings {
		if f.Rule == "V23" && f.Level == Error {
			found = true
		}
	}
	if !found {
		t.Error("an accepted entry with a repo missing from tasks.md should draw V23 even in draft mode")
	}
}

func TestKeysSelectEntries(t *testing.T) {
	root := materialize(t, "V10", "invalid")
	res, err := Run(Options{Root: root, Keys: []string{"0100-demo-entry"}, Today: "2026-10-11", SchemaPath: schemaPath})
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Checked) != 1 || res.Checked[0] != "0100-demo-entry" {
		t.Errorf("checked = %v", res.Checked)
	}
}

func TestAdmissionHits(t *testing.T) {
	tests := []struct {
		text                  string
		paths, flags, symbols int
	}{
		{"The system SHALL keep the thing.", 0, 0, 0},
		{"Reads internal/render/render.go.", 1, 0, 0},
		{"Reads config.yaml and values.go.", 2, 0, 0},
		{"Honours --dry-run and --force.", 0, 2, 0},
		{"Calls render.Apply and Run().", 0, 0, 2},
		{"Names a #Platform.items and #ModuleRelease.", 0, 0, 0},
		{"See https://example.com/a/b.html for the page.", 0, 0, 0},
		{"A version 4.1.0 and e.g. the plan.", 0, 0, 0},
	}
	for _, tc := range tests {
		p, f, s := admissionHits(tc.text)
		if len(p) != tc.paths || len(f) != tc.flags || len(s) != tc.symbols {
			t.Errorf("%q: paths %v flags %v symbols %v", tc.text, p, f, s)
		}
	}
}

func TestForeignEntryLink(t *testing.T) {
	tests := []struct{ rel, target, want string }{
		{"design.md", "evidence/a.md", ""},
		{"design.md", "https://example.com/x", ""},
		{"design.md", "#anchor", ""},
		{"design.md", "../0014-other/README.md", "0014-other"},
		{"design.md", "../../archive/0016/README.md", "archive"},
		{"evidence/a.md", "../design.md", ""},
		{"evidence/a.md", "../../0014/", "0014"},
		{"design.md", "../seed-thing/source.md", "seed-thing"},
	}
	for _, tc := range tests {
		if got := foreignEntryLink(tc.rel, tc.target); got != tc.want {
			t.Errorf("foreignEntryLink(%q, %q) = %q, want %q", tc.rel, tc.target, got, tc.want)
		}
	}
}

func TestParseMode(t *testing.T) {
	for in, want := range map[string]Mode{"": Draft, "draft": Draft, "accept": Accept, "deliver": Deliver} {
		if got, err := ParseMode(in); err != nil || got != want {
			t.Errorf("ParseMode(%q) = %v, %v", in, got, err)
		}
	}
	if _, err := ParseMode("nope"); err == nil {
		t.Error("ParseMode should refuse an unknown mode")
	}
}

// modeCase checks the level of one rule at each mode against its invalid fixture.
// "" means the rule is silent in that mode.
func TestModeLevelTable(t *testing.T) {
	type levels [3]Level // draft, accept, deliver
	cases := []struct {
		rule, fixture string
		want          levels
		tune          func(*Options)
	}{
		{"V5", "invalid", levels{"", Error, Error}, nil},
		{"V12", "invalid", levels{Warning, Error, Error}, nil},
		{"V13", "invalid", levels{"", "", Error}, nil},
		{"V20", "invalid", levels{"", Error, Error}, nil},
		{"V22", "invalid", levels{"", Error, Error}, nil},
		{"V23", "invalid", levels{"", Error, Error}, nil},
		{"V23", "invalid-2", levels{Warning, Error, Error}, nil},
		{"V24", "invalid", levels{"", "", Error}, nil},
		{"V32", "invalid", levels{"", Error, Error}, func(o *Options) { o.OpenSpec = stubOpenSpec }},
		{"V34", "invalid", levels{"", Error, Error}, nil},
	}
	for _, tc := range cases {
		for i, mode := range []Mode{Draft, Accept, Deliver} {
			t.Run(tc.rule+"/"+tc.fixture+"/"+mode.String(), func(t *testing.T) {
				root := materialize(t, tc.rule, tc.fixture)
				opts := Options{Root: root, Mode: mode, Today: "2026-10-11", SchemaPath: schemaPath}
				if tc.tune != nil {
					tc.tune(&opts)
				}
				res, err := Run(opts)
				if err != nil {
					t.Fatal(err)
				}
				got := Level("")
				for _, f := range res.Findings {
					if f.Rule == tc.rule && (got == "" || f.Level == Error) {
						got = f.Level
					}
				}
				if got != tc.want[i] {
					var b strings.Builder
					res.Format(&b)
					t.Errorf("%s in %s: level %q, want %q\n%s", tc.rule, mode, got, tc.want[i], b.String())
				}
			})
		}
	}
}

// An old-layout entry that is still live is a valid after and superseded_by
// target, so that every commit of the migration passes whatever the order of
// the conversion. The template folder 0000 is not.
func TestOldLiveEntryIsATarget(t *testing.T) {
	for _, tc := range []struct{ rule, fixture string }{{"V6", "valid-2"}, {"V8", "valid-2"}} {
		root := materialize(t, tc.rule, tc.fixture)
		res, err := Run(Options{Root: root, Today: "2026-10-11", SchemaPath: schemaPath})
		if err != nil {
			t.Fatal(err)
		}
		if res.HasErrors() {
			var b strings.Builder
			res.Format(&b)
			t.Errorf("%s %s: an old live id is refused:\n%s", tc.rule, tc.fixture, b.String())
		}
	}
	root := materialize(t, "V6", "valid-2")
	if err := os.Rename(filepath.Join(root, "0021"), filepath.Join(root, "0000")); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(filepath.Join(root, "openspec/changes/0100-demo-entry/config.yaml"))
	if err := os.WriteFile(filepath.Join(root, "openspec/changes/0100-demo-entry/config.yaml"), []byte(strings.Replace(string(b), `"0021"`, `"0000"`, 1)), 0o644); err != nil {
		t.Fatal(err)
	}
	res, _ := Run(Options{Root: root, Today: "2026-10-11", SchemaPath: schemaPath})
	found := false
	for _, f := range res.Findings {
		found = found || (f.Rule == "V6" && strings.Contains(f.Msg, "does not exist"))
	}
	if !found {
		t.Error("the template folder 0000 must not be an after target")
	}
}
