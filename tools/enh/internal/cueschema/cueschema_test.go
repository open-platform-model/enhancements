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
	if strings.Join(s.Blocked, ",") != "0030,0031" {
		t.Errorf("blocked = %v", s.Blocked)
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
