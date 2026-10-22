package cueschema

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const schemaPath = "../../../../schema.cue"

func load(t *testing.T) *Schema {
	t.Helper()
	s, err := Load(schemaPath)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func TestLists(t *testing.T) {
	s := load(t)
	if strings.Join(s.Reserved, ",") != "0000,0028,0029" {
		t.Errorf("reserved = %v", s.Reserved)
	}
	if len(s.Blocked) != 0 {
		t.Errorf("blocked = %v", s.Blocked)
	}
}

func TestIsRepo(t *testing.T) {
	s := load(t)
	for name, want := range map[string]bool{"core": true, "opm-controller": true, ".github": true, "nope": false, "": false, "Core": false} {
		if got := s.IsRepo(name); got != want {
			t.Errorf("IsRepo(%q) = %v, want %v", name, got, want)
		}
	}
}

// The fixtures of tests/schema are the ground truth of the schema; this test
// proves the Go path agrees with the cue command line on all of them.
func TestSchemaFixtures(t *testing.T) {
	s := load(t)
	valid, _ := filepath.Glob("../../../../tests/schema/valid/*.yaml")
	invalid, _ := filepath.Glob("../../../../tests/schema/invalid/*.yaml")
	if len(valid) == 0 || len(invalid) == 0 {
		t.Fatalf("no fixtures found: %d valid, %d invalid", len(valid), len(invalid))
	}
	for _, f := range valid {
		b, _ := os.ReadFile(f)
		if is := s.CheckConfig(b); len(is) != 0 {
			t.Errorf("%s: valid fixture refused: %+v", f, is)
		}
	}
	for _, f := range invalid {
		b, _ := os.ReadFile(f)
		if is := s.CheckConfig(b); len(is) == 0 {
			t.Errorf("%s: invalid fixture accepted", f)
		}
	}
}

func TestIssueField(t *testing.T) {
	s := load(t)
	is := s.CheckConfig([]byte("id: \"0100\"\nslug: demo\nstatus: draft\nsemver: major\n"))
	var fields []string
	for _, i := range is {
		fields = append(fields, i.Field)
	}
	if !strings.Contains(strings.Join(fields, ","), "semver") {
		t.Errorf("fields = %v issues = %+v", fields, is)
	}
}

func TestBadYAML(t *testing.T) {
	s := load(t)
	if is := s.CheckConfig([]byte("a: [1\n")); len(is) != 1 {
		t.Errorf("issues = %+v", is)
	}
}

// A type error on a plain field is an issue, not the arm of a disjunction.
func TestTypeErrorsOnPlainFields(t *testing.T) {
	s := load(t)
	base := "id: \"0100\"\nslug: demo\ntitle: T\nsummary: S\nstatus: draft\ncategory: tooling\naffects: [core]\nauthors: [a]\ncreated: \"2026-10-10\"\n"
	for name, change := range map[string][2]string{
		"breaking yes":    {"breaking: yes\n", "breaking"},
		"breaking string": {"breaking: \"yes\"\n", "breaking"},
		"title number":    {"title: 12345\n", "title"},
		"authors number":  {"authors: [42]\n", "authors"},
	} {
		src := base + change[0]
		if change[1] != "breaking" {
			src = strings.Replace(base, change[1]+": "+map[string]string{"title": "T", "authors": "[a]"}[change[1]], change[0], 1)
		}
		found := false
		for _, is := range s.CheckConfig([]byte(src)) {
			if is.Field == change[1] {
				found = true
			}
		}
		if !found {
			t.Errorf("%s: no issue on %s", name, change[1])
		}
	}
	// the refused value of a disjunction is named
	got := s.CheckConfig([]byte(strings.Replace(base, "category: tooling", "category: nope", 1)))
	if len(got) == 0 || !strings.Contains(got[0].Msg, `"nope"`) {
		t.Errorf("category issue = %+v", got)
	}
}
