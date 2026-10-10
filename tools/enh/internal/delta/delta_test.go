package delta

import "testing"

const sample = `## Purpose

A real purpose that is long enough to pass the fifty character floor.

## ADDED Requirements

### Requirement: First one

The system SHALL do the first thing.

#### Scenario: It works

- **WHEN** x
- **THEN** y

#### Scenario: Empty one

### Requirement: Second one ###

**ID**: R2

The system MUST do the second thing.
` + "```" + `
#### Scenario: inside a fence
` + "```" + `

#### Scenario: Real

- **WHEN** a
- **THEN** b

## MODIFIED Requirements

### Requirement: Old one

Changed text SHALL hold.

#### Scenario: S

- **WHEN** a

## REMOVED Requirements

### Requirement: Gone one

**Reason**: It no longer holds
and wraps.

**Migration**: Replaced by "First one"

## RENAMED Requirements

- FROM: ` + "`### Requirement: Before`" + `
- TO: ` + "`### Requirement: After`" + `
- FROM: ` + "`### Requirement: Lonely`" + `
`

func TestParseDelta(t *testing.T) {
	sp := Parse("specs/cap/spec.md", "cap", []byte(sample))
	if !sp.HasPurpose || len(sp.Purpose) < 50 {
		t.Fatalf("purpose = %q", sp.Purpose)
	}
	if got := len(sp.Requirements); got != 4 {
		t.Fatalf("requirements = %d, want 4", got)
	}
	a := sp.By(Added)
	if len(a) != 2 || a[0].Name != "First one" || a[1].Name != "Second one" {
		t.Fatalf("added = %+v", a)
	}
	if a[0].Text != "The system SHALL do the first thing." {
		t.Errorf("text = %q", a[0].Text)
	}
	if a[0].RealScenarios() != 1 || len(a[0].Scenarios) != 2 || !a[0].Scenarios[1].Empty {
		t.Errorf("scenarios = %+v", a[0].Scenarios)
	}
	// metadata line is skipped when other text exists; the fenced header is not a scenario
	if a[1].Text != "The system MUST do the second thing." {
		t.Errorf("text 2 = %q", a[1].Text)
	}
	if len(a[1].Scenarios) != 1 || a[1].Scenarios[0].Name != "Real" {
		t.Errorf("scenarios 2 = %+v", a[1].Scenarios)
	}
	rm := sp.By(Removed)[0]
	if rm.Reason != "It no longer holds and wraps." || rm.Migration != `Replaced by "First one"` {
		t.Errorf("reason=%q migration=%q", rm.Reason, rm.Migration)
	}
	if len(sp.Renames) != 1 || sp.Renames[0].From != "Before" || sp.Renames[0].To != "After" {
		t.Errorf("renames = %+v", sp.Renames)
	}
	if len(sp.UnpairedRenames) != 1 {
		t.Errorf("unpaired = %v", sp.UnpairedRenames)
	}
}

func TestParseMain(t *testing.T) {
	src := "# cap Specification\n\n## Purpose\n\nx\n\n## Requirements\n\n### Requirement: One\n\nIt SHALL.\n\n#### Scenario: a\n\n- **WHEN** x\n"
	sp := Parse("p", "cap", []byte(src))
	m := sp.By(Main)
	if len(m) != 1 || m[0].Name != "One" || m[0].RealScenarios() != 1 {
		t.Fatalf("main = %+v", m)
	}
}

func TestNormalizeName(t *testing.T) {
	if got := NormalizeName("  Foo ## "); got != "Foo" {
		t.Errorf("got %q", got)
	}
	if got := NormalizeName("C#"); got != "C#" {
		t.Errorf("got %q", got)
	}
}
