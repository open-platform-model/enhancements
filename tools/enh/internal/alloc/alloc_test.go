package alloc

import (
	"fmt"
	"os"
	"reflect"
	"slices"
	"testing"
	"testing/fstest"
)

func readFile(t *testing.T, path string) []byte {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return b
}

func TestNext_todaysTreeReturns0032(t *testing.T) {
	in := Inputs{FS: os.DirFS("testdata/today"), Schema: readFile(t, "testdata/schema.cue")}
	got, err := Next(in)
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if got.ID != "0032" {
		t.Errorf("Next() = %s, want 0032", got.ID)
	}
	for _, id := range []string{"0001", "0013", "0027"} {
		if len(got.Taken[id]) == 0 {
			t.Errorf("id %s is not taken, want taken", id)
		}
	}
	if !slices.Contains(got.Taken["0028"], "reserved in schema.cue") {
		t.Errorf("0028 reasons = %v, want reserved", got.Taken["0028"])
	}
	if !slices.Contains(got.Taken["0030"], "blocked in schema.cue") {
		t.Errorf("0030 reasons = %v, want blocked", got.Taken["0030"])
	}
	if len(got.Warnings) != 1 || got.Warnings[0] != FetchNote {
		t.Errorf("Warnings = %v, want the fetch note, since no refs were given", got.Warnings)
	}
}

func TestNext_withRefsDoesNotWarn(t *testing.T) {
	in := Inputs{FS: os.DirFS("testdata/today"), Schema: readFile(t, "testdata/schema.cue"), Refs: []string{"main"}}
	got, err := Next(in)
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if len(got.Warnings) != 0 {
		t.Errorf("Warnings = %v, want none", got.Warnings)
	}
}

func TestNext_table(t *testing.T) {
	schema := readFile(t, "testdata/schema.cue")
	keep := fstest.MapFile{}
	tests := []struct {
		name string
		fs   fstest.MapFS
		refs []string
		sch  []byte
		want string
	}{
		{name: "empty repo starts at 0001", fs: fstest.MapFS{}, sch: schema, want: "0001"},
		{
			name: "live entry folder",
			fs:   fstest.MapFS{"openspec/changes/0001-a/config.yaml": &keep},
			sch:  schema, want: "0002",
		},
		{
			name: "archived entry folder by its date prefix",
			fs: fstest.MapFS{
				"openspec/changes/0001-a/x":                           &keep,
				"openspec/changes/archive/2026-10-16-0002-b/x":        &keep,
				"openspec/changes/archive/2026-10-16-seed-thing/x":    &keep,
				"openspec/changes/archive/2026-10-16-0004-skip-gap/x": &keep,
			},
			sch: schema, want: "0003",
		},
		{
			name: "seed folders carry no id",
			fs:   fstest.MapFS{"openspec/changes/seed-registration/x": &keep},
			sch:  schema, want: "0001",
		},
		{
			name: "correction folders carry no id",
			fs: fstest.MapFS{
				"openspec/changes/correction-owner-value/x":                &keep,
				"openspec/changes/archive/2026-10-16-correction-old-fix/x": &keep,
			},
			sch: schema, want: "0001",
		},
		{
			name: "old archive and old live folders",
			fs:   fstest.MapFS{"archive/0001/x": &keep, "0002/x": &keep, "archive/notes/x": &keep},
			sch:  schema, want: "0003",
		},
		{
			name: "a file named like an id does not count",
			fs:   fstest.MapFS{"0001": &fstest.MapFile{Data: []byte("x")}},
			sch:  schema, want: "0001",
		},
		{
			name: "branch of an open pull request",
			fs:   fstest.MapFS{"archive/0001/x": &keep},
			refs: []string{"docs/0002-new-idea"},
			sch:  schema, want: "0003",
		},
		{
			name: "remote branch and refs form",
			fs:   fstest.MapFS{},
			refs: []string{"origin/docs/0001-a", "remotes/origin/docs/0002-b", "refs/heads/docs/0003-c", "refs/remotes/origin/docs/0004-d", "* docs/0005-e", "+ docs/0006-f"},
			sch:  schema, want: "0007",
		},
		{
			name: "a branch that is not an id branch does not count",
			fs:   fstest.MapFS{},
			refs: []string{"feat/0001-a", "docs/readme-2026", "docs/12345-x", "release/2026-10-10", "docs/0001"},
			sch:  schema, want: "0001",
		},
		{
			name: "reserved ids are skipped",
			fs:   fstest.MapFS{"archive/0027/x": &keep},
			sch:  []byte(`reservedIds: ["0000", "0001", "0002"]` + "\n" + `blockedIds: []` + "\n"),
			want: "0003",
		},
		{
			name: "blocked ids are skipped and a gap after them is filled",
			fs:   fstest.MapFS{"archive/0001/x": &keep, "archive/0002/x": &keep, "archive/0004/x": &keep},
			sch:  []byte(`reservedIds: ["0000"]` + "\n" + `blockedIds: ["0003"]` + "\n"),
			want: "0005",
		},
		{
			name: "emptied blocked list: a lower gap still comes first",
			fs: fstest.MapFS{
				"archive/0027/x": &keep, "archive/0026/x": &keep, "archive/0001/x": &keep,
			},
			sch:  []byte(`reservedIds: ["0000", "0028", "0029"]` + "\n" + `blockedIds: []` + "\n"),
			want: "0002",
		},
		{
			name: "a lower gap is filled before the highest id",
			fs:   fstest.MapFS{"openspec/changes/0001-a/x": &keep, "openspec/changes/0003-c/x": &keep},
			sch:  schema, want: "0002",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := Next(Inputs{FS: tt.fs, Schema: tt.sch, Refs: tt.refs})
			if err != nil {
				t.Fatalf("Next: %v", err)
			}
			if got.ID != tt.want {
				t.Errorf("Next() = %s, want %s (taken: %v)", got.ID, tt.want, got.Taken)
			}
		})
	}
}

func TestNext_after0030StripFillsTheGap(t *testing.T) {
	fsys := fstest.MapFS{}
	for n := 1; n <= 27; n++ {
		fsys["archive/"+fmt.Sprintf("%04d", n)+"/x"] = &fstest.MapFile{}
	}
	sch := []byte(`reservedIds: ["0000", "0028", "0029"]` + "\n" + `blockedIds: []` + "\n")
	got, err := Next(Inputs{FS: fsys, Schema: sch})
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if got.ID != "0030" {
		t.Errorf("Next() = %s, want 0030", got.ID)
	}
	fsys["openspec/changes/0030-first/x"] = &fstest.MapFile{}
	got, err = Next(Inputs{FS: fsys, Schema: sch})
	if err != nil {
		t.Fatalf("Next: %v", err)
	}
	if got.ID != "0031" {
		t.Errorf("Next() = %s, want 0031", got.ID)
	}
}

func TestNext_exhausted(t *testing.T) {
	fsys := fstest.MapFS{}
	for n := 1; n <= 9999; n++ {
		fsys["archive/"+fmt.Sprintf("%04d", n)+"/x"] = &fstest.MapFile{}
	}
	_, err := Next(Inputs{FS: fsys, Schema: []byte(`reservedIds: []` + "\n" + `blockedIds: []` + "\n")})
	if err == nil {
		t.Fatal("Next() with every id taken returned no error")
	}
}

func TestReadLists(t *testing.T) {
	tests := []struct {
		name         string
		schema       string
		wantReserved []string
		wantBlocked  []string
		wantErr      bool
	}{
		{name: "one line", schema: "reservedIds: [\"0000\", \"0028\"]\nblockedIds: [\"0030\"]\n", wantReserved: []string{"0000", "0028"}, wantBlocked: []string{"0030"}},
		{name: "empty blocked", schema: "reservedIds: [\"0000\"]\nblockedIds: []\n", wantReserved: []string{"0000"}, wantBlocked: nil},
		{name: "reserved missing", schema: "blockedIds: []\n", wantErr: true},
		{name: "blocked missing", schema: "reservedIds: [\"0000\"]\n", wantErr: true},
		{name: "not four digits", schema: "reservedIds: [\"28\"]\nblockedIds: []\n", wantErr: true},
		{name: "unquoted id", schema: "reservedIds: [0028]\nblockedIds: []\n", wantErr: true},
		{name: "unclosed", schema: "reservedIds: [\"0000\"\nblockedIds: []\n", wantErr: true},
		{name: "defined twice", schema: "reservedIds: [\"0000\"]\nreservedIds: [\"0001\"]\nblockedIds: []\n", wantErr: true},
		{name: "indented field is not a list start", schema: "x: {\n\treservedIds: [\"0001\"]\n}\nreservedIds: [\"0000\"]\nblockedIds: []\n", wantReserved: []string{"0000"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r, b, err := ReadLists([]byte(tt.schema))
			if (err != nil) != tt.wantErr {
				t.Fatalf("ReadLists error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr {
				return
			}
			if !reflect.DeepEqual(r, tt.wantReserved) || !reflect.DeepEqual(b, tt.wantBlocked) {
				t.Errorf("ReadLists = %v, %v; want %v, %v", r, b, tt.wantReserved, tt.wantBlocked)
			}
		})
	}
}

func TestReadLists_multilineWithComments(t *testing.T) {
	r, b, err := ReadLists(readFile(t, "testdata/schema-multiline.cue"))
	if err != nil {
		t.Fatalf("ReadLists: %v", err)
	}
	if want := []string{"0000", "0028", "0029"}; !reflect.DeepEqual(r, want) {
		t.Errorf("reserved = %v, want %v", r, want)
	}
	if len(b) != 0 {
		t.Errorf("blocked = %v, want none", b)
	}
}

// The real schema.cue must stay readable by this package. The values are not
// pinned here: the lists change at the end of the last phase.
func TestReadLists_realSchema(t *testing.T) {
	r, _, err := ReadLists(readFile(t, "../../../../schema.cue"))
	if err != nil {
		t.Fatalf("ReadLists on the repo schema.cue: %v", err)
	}
	if !slices.Contains(r, "0000") {
		t.Errorf("reservedIds = %v, want it to hold 0000", r)
	}
}

func TestBranchID(t *testing.T) {
	tests := []struct {
		ref  string
		want string
		ok   bool
	}{
		{"docs/0033-title", "0033", true},
		{"+ docs/0033-title", "0033", true},
		{"* docs/0033-title", "0033", true},
		{"origin/docs/0033-title", "0033", true},
		{"upstream/docs/0033-title", "0033", true},
		{"remotes/origin/docs/0033-title", "0033", true},
		{"refs/heads/docs/0033-title", "0033", true},
		{"refs/remotes/origin/docs/0033-title", "0033", true},
		{"  docs/0033-title  ", "0033", true},
		{"docs/0033", "", false},
		{"docs/033-title", "", false},
		{"main", "", false},
		{"", "", false},
	}
	for _, tt := range tests {
		got, ok := BranchID(tt.ref)
		if got != tt.want || ok != tt.ok {
			t.Errorf("BranchID(%q) = %q, %v; want %q, %v", tt.ref, got, ok, tt.want, tt.ok)
		}
	}
}
