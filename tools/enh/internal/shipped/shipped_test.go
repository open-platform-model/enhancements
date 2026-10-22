package shipped

import "testing"

func TestParse(t *testing.T) {
	src := "# Source\n\n## Shipped by\n\n<!-- | `x` | hidden | MODIFIED | no | no | -->\n\n" +
		"| Capability | Requirement | Change | Shipped by | Code read |\n| --- | --- | --- | --- | --- |\n" +
		"| `cap` | A name | modified | `cli` PR 1 | `a.go:2` |\n| `cap` | short |\n\n" +
		"```\n| `cap` | fenced | ADDED | `cli` PR 2 | |\n```\n\n## Left out\n\n| `cap` | after | ADDED | `cli` PR 3 | |\n"
	rows, found := Parse(src)
	if !found || len(rows) != 2 {
		t.Fatalf("found=%v rows=%+v", found, rows)
	}
	if r := rows[0]; r.Capability != "cap" || r.Name != "A name" || r.Op != "MODIFIED" || r.By != "`cli` PR 1" || r.Code != "`a.go:2`" || r.Line != 9 || r.Cells != 5 {
		t.Errorf("row 0 = %+v", r)
	}
	if rows[1].Cells != 2 {
		t.Errorf("row 1 = %+v", rows[1])
	}
	if _, found := Parse("# Source\n"); found {
		t.Error("a note with no table must report found = false")
	}
}
