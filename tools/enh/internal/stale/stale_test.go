package stale

import (
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/sys"
	"github.com/open-platform-model/enhancements/tools/enh/internal/testrepo"
)

func mainSpec(c, name, text string) string {
	return "# " + c + "\n\n## Purpose\nA long enough purpose for the fixture to read well.\n\n## Requirements\n\n### Requirement: " + name + "\n" + text + "\n\n#### Scenario: s\n- **WHEN** a\n- **THEN** b\n"
}

func entryDelta() []*delta.Spec {
	src := `## MODIFIED Requirements

### Requirement: Alpha
Alpha SHALL hold.

#### Scenario: s
- **WHEN** a
- **THEN** b

## REMOVED Requirements

### Requirement: Beta
**Reason**: gone.
**Migration**: none.

## RENAMED Requirements

- FROM: ### Requirement: Gamma
- TO: ### Requirement: Gamma two
`
	return []*delta.Spec{delta.Parse("d.md", "cap", []byte(src))}
}

func side(texts map[string]string) Side {
	specs := map[string]*delta.Spec{}
	var b strings.Builder
	b.WriteString("# cap\n\n## Requirements\n")
	for n, t := range texts {
		b.WriteString("\n### Requirement: " + n + "\n" + t + "\n\n#### Scenario: s\n- **WHEN** a\n- **THEN** b\n")
	}
	specs["cap"] = delta.Parse("m.md", "cap", []byte(b.String()))
	return Now(specs)
}

func TestTargets(t *testing.T) {
	got := Targets(entryDelta())
	want := []Target{{"cap", "Alpha", OpModified}, {"cap", "Beta", OpRemoved}, {"cap", "Gamma", OpRenamed}}
	if len(got) != len(want) {
		t.Fatalf("got %v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("target %d = %v, want %v", i, got[i], want[i])
		}
	}
}

func TestCheck(t *testing.T) {
	same := map[string]string{"Alpha": "Alpha SHALL hold.", "Beta": "Beta SHALL hold.", "Gamma": "Gamma SHALL hold."}
	flags, err := Check(entryDelta(), side(same), side(same))
	if err != nil || len(flags) != 0 {
		t.Fatalf("same: %v, %v", flags, err)
	}
	changed := map[string]string{"Alpha": "Alpha SHALL hold. More.", "Beta": "Beta SHALL hold.", "Gamma": "Gamma SHALL hold."}
	flags, err = Check(entryDelta(), side(same), side(changed))
	if err != nil || len(flags) != 1 || flags[0].Name != "Alpha" || flags[0].Reason() != "text changed" {
		t.Fatalf("changed: %+v, %v", flags, err)
	}
	if !strings.Contains(flags[0].Then, "Alpha SHALL hold.") || !strings.Contains(flags[0].Now, "More.") {
		t.Errorf("both texts are carried: %+v", flags[0])
	}
	missingNow := map[string]string{"Alpha": "Alpha SHALL hold.", "Gamma": "Gamma SHALL hold."}
	flags, _ = Check(entryDelta(), side(same), side(missingNow))
	if len(flags) != 1 || flags[0].Name != "Beta" || !flags[0].NowMissing || flags[0].Reason() != "missing in specs/ now" {
		t.Errorf("missing now: %+v", flags)
	}
	flags, _ = Check(entryDelta(), side(missingNow), side(same))
	if len(flags) != 1 || !flags[0].ThenMissing || flags[0].Reason() != "missing at the accepted commit" {
		t.Errorf("missing then: %+v", flags)
	}
	flags, _ = Check(entryDelta(), side(missingNow), side(missingNow))
	if len(flags) != 1 || flags[0].Reason() != "missing at both sides" {
		t.Errorf("missing both: %+v", flags)
	}
	// white space is not a difference
	spaced := map[string]string{"Alpha": "Alpha SHALL hold.   ", "Beta": "Beta SHALL hold.", "Gamma": "Gamma SHALL hold."}
	if flags, _ = Check(entryDelta(), side(same), side(spaced)); len(flags) != 0 {
		t.Errorf("trailing space flagged: %+v", flags)
	}
}

func TestThenFromGit(t *testing.T) {
	dir := testrepo.New(t)
	testrepo.Write(t, dir, "openspec/specs/cap/spec.md", mainSpec("cap", "Alpha", "Alpha SHALL hold."))
	old := testrepo.Commit(t, dir, "docs: seed")
	testrepo.Write(t, dir, "openspec/specs/cap/spec.md", mainSpec("cap", "Alpha", "Alpha SHALL hold. Changed."))
	testrepo.Commit(t, dir, "docs: change")
	g := sys.Git{Root: dir, Run: sys.Exec}
	then := Then(g, old)
	sp, err := then("cap")
	if err != nil || sp == nil || !strings.Contains(sp.Requirements[0].Text, "Alpha SHALL hold.") || strings.Contains(sp.Requirements[0].Text, "Changed") {
		t.Fatalf("then = %+v, %v", sp, err)
	}
	if sp, err := then("nocap"); sp != nil || err != nil {
		t.Errorf("missing capability = %v, %v", sp, err)
	}
	now := Now(map[string]*delta.Spec{"cap": delta.Parse("p", "cap", []byte(mainSpec("cap", "Alpha", "Alpha SHALL hold. Changed.")))})
	d := delta.Parse("d", "cap", []byte("## MODIFIED Requirements\n\n### Requirement: Alpha\nx SHALL y.\n\n#### Scenario: s\n- **WHEN** a\n- **THEN** b\n"))
	flags, err := Check([]*delta.Spec{d}, then, now)
	if err != nil || len(flags) != 1 {
		t.Errorf("flags = %+v, %v", flags, err)
	}
}
