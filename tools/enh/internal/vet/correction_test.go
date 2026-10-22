package vet

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const corrDir = "openspec/changes/correction-fix-owner"

const shipAMain = `## Purpose

Hold the shipped owner behaviour for the fixtures of the correction rules.

## Requirements

### Requirement: Owner is recorded

The CLI SHALL record the owner as operator.

#### Scenario: Recorded

- **WHEN** an instance is created
- **THEN** the owner is operator

### Requirement: Hand over is adopted

The operator SHALL adopt a hand-over.

#### Scenario: Adopted

- **WHEN** a hand-over arrives
- **THEN** the operator adopts it

### Requirement: Old thing stays

The system SHALL keep the old thing.

#### Scenario: Kept

- **WHEN** a user asks
- **THEN** the old thing is kept
`

const shipBMain = `## Purpose

Hold the shipped re-enqueue behaviour for the fixtures of the correction rules.

## Requirements

### Requirement: Re-enqueue is limited

The operator SHALL re-enqueue only operator-managed instances.

#### Scenario: Limited

- **WHEN** an instance changes
- **THEN** only operator-managed ones are queued

### Requirement: Second thing

The system SHALL hold the second thing.

#### Scenario: Held

- **WHEN** a user asks
- **THEN** the second thing is held
`

const corrOpenSpec = "schema: correction\ncreated: 2026-10-10\n"

const corrDeltaA = `## MODIFIED Requirements

### Requirement: Owner is recorded

The CLI SHALL record the owner as cli.

#### Scenario: Recorded

- **WHEN** an instance is created
- **THEN** the owner is cli

## REMOVED Requirements

### Requirement: Hand over is adopted

**Reason**: The value is now controller.

**Migration**: Replaced by "Hand over to the controller is adopted"

## ADDED Requirements

### Requirement: Hand over to the controller is adopted

The controller SHALL adopt a hand-over.

#### Scenario: Adopted

- **WHEN** a hand-over arrives
- **THEN** the controller adopts it
`

const corrDeltaB = `## RENAMED Requirements

- FROM: ` + "`### Requirement: Second thing`" + `
- TO: ` + "`### Requirement: Second thing is kept`" + `

## MODIFIED Requirements

### Requirement: Re-enqueue is limited

The controller SHALL re-enqueue only controller-managed instances.

#### Scenario: Limited

- **WHEN** an instance changes
- **THEN** only controller-managed ones are queued

## ADDED Requirements

### Requirement: Status is shown

The controller SHALL show the status of every instance.

#### Scenario: Shown

- **WHEN** a user lists instances
- **THEN** the status is shown
`

const corrSource = `# Source note: correction-fix-owner

Corrects: ` + "`ship-a`, `ship-b`" + `. The owner value is controller now.

## Shipped by

<!-- a comment row: | ` + "`x`" + ` | nothing | MODIFIED | no | no | -->

| Capability | Requirement | Change | Shipped by | Code read |
| --- | --- | --- | --- | --- |
| ` + "`ship-a`" + ` | Owner is recorded | MODIFIED | ` + "`cli`" + ` PR 12 | ` + "`cmd/owner.go:10`" + ` |
| ` + "`ship-a`" + ` | Hand over is adopted | REMOVED | ` + "`opm-controller`" + ` PR 30 | |
| ` + "`ship-a`" + ` | Hand over to the controller is adopted | ADDED | ` + "`opm-controller`" + ` PR 30 | |
| ` + "`ship-b`" + ` | Second thing is kept | RENAMED | ` + "`cli`" + ` commit abcdef1 | |
| ` + "`ship-b`" + ` | Re-enqueue is limited | MODIFIED | ` + "`opm-controller`" + ` PR 31, ` + "`cli`" + ` PR 12 | ` + "`pkg/queue.go:5`" + ` |
| ` + "`ship-b`" + ` | Status is shown | ADDED | ` + "`opm-controller`" + ` PR 32 | ` + "`pkg/status.go:9`" + ` |

## Left out

- Nothing.

sampled: 2026-10-10 abcdef1
`

// correctionRoot builds the base tree plus two delivered capabilities and a
// valid correction over both.
func correctionRoot(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	copyTree(t, "testdata/base", root)
	put := func(rel, text string) {
		p := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(text), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	put("openspec/specs/ship-a/spec.md", shipAMain)
	put("openspec/specs/ship-b/spec.md", shipBMain)
	put(corrDir+"/.openspec.yaml", corrOpenSpec)
	put(corrDir+"/specs/ship-a/spec.md", corrDeltaA)
	put(corrDir+"/specs/ship-b/spec.md", corrDeltaB)
	put(corrDir+"/source.md", corrSource)
	return root
}

func editFile(t *testing.T, root, rel, old, new string) {
	t.Helper()
	p := filepath.Join(root, rel)
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), old) {
		t.Fatalf("%s does not contain %q", rel, old)
	}
	if err := os.WriteFile(p, []byte(strings.Replace(string(b), old, new, 1)), 0o644); err != nil {
		t.Fatal(err)
	}
}

// corrFindings runs the checker and returns the findings about the correction.
func corrFindings(t *testing.T, root string, mode Mode) []Finding {
	t.Helper()
	res, err := Run(Options{Root: root, Mode: mode, Today: "2026-10-11", SchemaPath: schemaPath})
	if err != nil {
		t.Fatal(err)
	}
	var out []Finding
	for _, f := range res.Findings {
		if f.Entry == "correction-fix-owner" {
			out = append(out, f)
		}
	}
	return out
}

func hasFinding(fs []Finding, rule string, lv Level, frag string) bool {
	for _, f := range fs {
		if f.Rule == rule && f.Level == lv && strings.Contains(f.Msg, frag) {
			return true
		}
	}
	return false
}

func dumpFindings(fs []Finding) string {
	var b strings.Builder
	for _, f := range fs {
		b.WriteString(f.String() + "\n")
	}
	return b.String()
}

// A correction over two delivered capabilities, with MODIFIED, REMOVED, RENAMED
// and ADDED blocks, passes every rule in every mode.
func TestCorrectionValid(t *testing.T) {
	for _, m := range []Mode{Draft, Accept, Deliver} {
		if fs := corrFindings(t, correctionRoot(t), m); len(fs) != 0 {
			t.Errorf("mode %s:\n%s", m, dumpFindings(fs))
		}
	}
}

// Without the sampled line a correction fails at deliver and nowhere before.
func TestCorrectionNeedsSampleToDeliver(t *testing.T) {
	root := correctionRoot(t)
	editFile(t, root, corrDir+"/source.md", "sampled: 2026-10-10 abcdef1\n", "")
	if fs := corrFindings(t, root, Accept); len(fs) != 0 {
		t.Errorf("accept:\n%s", dumpFindings(fs))
	}
	if fs := corrFindings(t, root, Deliver); !hasFinding(fs, "V33", Error, "no \"sampled:") {
		t.Errorf("deliver:\n%s", dumpFindings(fs))
	}
}

func TestCorrectionV36(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(t *testing.T, root string)
		rule   string
		lv     Level
		frag   string
	}{
		{"unknown capability", func(t *testing.T, root string) {
			os.RemoveAll(filepath.Join(root, "openspec/specs/ship-b"))
		}, "V36", Error, "is not in openspec/specs/"},
		{"extra file", func(t *testing.T, root string) {
			os.WriteFile(filepath.Join(root, corrDir, "proposal.md"), []byte("x"), 0o644)
		}, "V36", Error, "\"proposal.md\" is not allowed"},
		{"config.yaml", func(t *testing.T, root string) {
			os.WriteFile(filepath.Join(root, corrDir, "config.yaml"), []byte("id: \"0001\"\n"), 0o644)
		}, "V36", Error, "\"config.yaml\" is not allowed"},
		{"extra spec file", func(t *testing.T, root string) {
			os.WriteFile(filepath.Join(root, corrDir, "specs/ship-a/notes.md"), []byte("x"), 0o644)
		}, "V36", Error, "spec.md files only"},
		{"purpose in a delta", func(t *testing.T, root string) {
			editFile(t, root, corrDir+"/specs/ship-a/spec.md", "## MODIFIED Requirements", "## Purpose\n\nThis text is longer than fifty characters to be a real purpose.\n\n## MODIFIED Requirements")
		}, "V36", Error, "no ## Purpose"},
		{"wrong schema", func(t *testing.T, root string) {
			editFile(t, root, corrDir+"/.openspec.yaml", "schema: correction", "schema: seed")
		}, "V36", Error, "uses schema: correction"},
		{"skip_specs key", func(t *testing.T, root string) {
			editFile(t, root, corrDir+"/.openspec.yaml", "created", "skip_specs: false\ncreated")
		}, "V11", Error, "unknown key \"skip_specs\""},
		{"retire key", func(t *testing.T, root string) {
			editFile(t, root, corrDir+"/.openspec.yaml", "created", "retire_capabilities: true\ncreated")
		}, "V11", Error, "unknown key \"retire_capabilities\""},
		{"no-op MODIFIED", func(t *testing.T, root string) {
			editFile(t, root, corrDir+"/specs/ship-a/spec.md", "The CLI SHALL record the owner as cli.", "The CLI SHALL record the owner as operator.")
			editFile(t, root, corrDir+"/specs/ship-a/spec.md", "- **THEN** the owner is cli", "- **THEN** the owner is operator")
		}, "V36", Error, "equals the main requirement"},
		{"retire a capability", func(t *testing.T, root string) {
			rm := "## REMOVED Requirements\n\n### Requirement: Re-enqueue is limited\n\n**Reason**: Gone.\n\n**Migration**: None.\n\n### Requirement: Second thing\n\n**Reason**: Gone.\n\n**Migration**: None.\n"
			os.WriteFile(filepath.Join(root, corrDir, "specs/ship-b/spec.md"), []byte(rm), 0o644)
		}, "V36", Error, "retiring a capability is not a correction"},
		{"no specs folder", func(t *testing.T, root string) {
			os.RemoveAll(filepath.Join(root, corrDir, "specs"))
		}, "V36", Error, "needs at least one"},
		{"empty delta", func(t *testing.T, root string) {
			os.WriteFile(filepath.Join(root, corrDir, "specs/ship-b/spec.md"), []byte("nothing here\n"), 0o644)
		}, "V36", Error, "holds no requirement block"},
		{"MODIFIED target missing from main", func(t *testing.T, root string) {
			editFile(t, root, corrDir+"/specs/ship-a/spec.md", "### Requirement: Owner is recorded", "### Requirement: Owner is noted")
		}, "V20", Error, "is not in openspec/specs/ship-a"},
		{"ADDED name already in main", func(t *testing.T, root string) {
			editFile(t, root, corrDir+"/specs/ship-b/spec.md", "### Requirement: Status is shown", "### Requirement: Re-enqueue is limited")
		}, "V20", Error, "already in openspec/specs/ship-b"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			root := correctionRoot(t)
			tc.mutate(t, root)
			// Draft mode: the correction rules hold from the first run.
			if fs := corrFindings(t, root, Draft); !hasFinding(fs, tc.rule, tc.lv, tc.frag) {
				t.Errorf("no %s %s finding containing %q:\n%s", tc.lv, tc.rule, tc.frag, dumpFindings(fs))
			}
		})
	}
}

func TestCorrectionBadFolderName(t *testing.T) {
	root := correctionRoot(t)
	if err := os.Rename(filepath.Join(root, corrDir), filepath.Join(root, "openspec/changes/correction-Bad_Name")); err != nil {
		t.Fatal(err)
	}
	res, err := Run(Options{Root: root, Today: "2026-10-11", SchemaPath: schemaPath})
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range res.Findings {
		if f.Rule == "V36" && strings.Contains(f.Msg, "kebab-case slug") {
			return
		}
	}
	t.Errorf("no V36 folder-name finding: %v", res.Findings)
}

func TestCorrectionV37(t *testing.T) {
	const table = corrDir + "/source.md"
	tests := []struct {
		name     string
		old, new string
		frag     string
	}{
		{"no table", "## Shipped by", "## Elsewhere", "no \"## Shipped by\" table"},
		{"missing row", "| `ship-a` | Hand over is adopted | REMOVED | `opm-controller` PR 30 | |\n", "", "no row in the Shipped by table for REMOVED \"Hand over is adopted\" in ship-a"},
		{"row names nothing", "| `ship-a` | Hand over is adopted |", "| `ship-a` | Invented thing |", "names no requirement of the deltas"},
		{"two rows", "| `ship-a` | Hand over is adopted | REMOVED | `opm-controller` PR 30 | |\n", "| `ship-a` | Hand over is adopted | REMOVED | `opm-controller` PR 30 | |\n| `ship-a` | Hand over is adopted | REMOVED | `cli` PR 1 | |\n", "two rows for REMOVED"},
		{"unknown repo", "`cli` PR 12 |", "`clii` PR 12 |", "does not list"},
		{"no reference", "`cli` PR 12 |", "PR 12 |", "has no reference"},
		{"no reference at all", "`cli` PR 12 |", "soon |", "has no reference"},
		{"text beside a reference", "`cli` PR 12 |", "`cli` PR 12 and more |", "not a reference"},
		{"MODIFIED without code", " `cmd/owner.go:10` |", " |", "needs the code read"},
		{"new behaviour without code", " `pkg/status.go:9` |", " |", "needs the code read"},
		{"operation disagrees", "| Status is shown | ADDED |", "| Status is shown | MODIFIED |", "says MODIFIED, but the delta says ADDED"},
		{"short row", "| `ship-a` | Hand over is adopted | REMOVED | `opm-controller` PR 30 | |\n", "| `ship-a` | Hand over is adopted | REMOVED | `opm-controller` PR 30 |\n", "has 4 cells"},
		{"commit too short", "commit abcdef1", "commit abc", "has no reference"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			root := correctionRoot(t)
			editFile(t, root, table, tc.old, tc.new)
			if fs := corrFindings(t, root, Draft); !hasFinding(fs, "V37", Error, tc.frag) {
				t.Errorf("no error V37 finding containing %q:\n%s", tc.frag, dumpFindings(fs))
			}
		})
	}
}

// An ADDED block that replaces a REMOVED one needs no code read; the same
// block with no REMOVED does.
func TestCorrectionReplacementNeedsNoCode(t *testing.T) {
	root := correctionRoot(t)
	editFile(t, root, corrDir+"/specs/ship-a/spec.md", `**Migration**: Replaced by "Hand over to the controller is adopted"`, "**Migration**: None.")
	fs := corrFindings(t, root, Draft)
	if !hasFinding(fs, "V37", Error, "needs the code read") {
		t.Errorf("want a code-read finding once nothing is replaced:\n%s", dumpFindings(fs))
	}
}

// A live entry that names the same requirement draws a warning, never an error.
func TestCorrectionOverlapIsAWarning(t *testing.T) {
	root := correctionRoot(t)
	p := filepath.Join(root, "openspec/changes/0100-demo-entry/specs/ship-a")
	if err := os.MkdirAll(p, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(p, "spec.md"), []byte(corrDeltaA), 0o644); err != nil {
		t.Fatal(err)
	}
	fs := corrFindings(t, root, Draft)
	if !hasFinding(fs, "V36", Warning, "live entry 0100-demo-entry names the same requirement") {
		t.Fatalf("no overlap warning:\n%s", dumpFindings(fs))
	}
	for _, f := range fs {
		if f.Level == Error {
			t.Errorf("the overlap must not fail: %s", f)
		}
	}
}

// A correction nobody else names has no overlap warning.
func TestCorrectionNoOverlapNoWarning(t *testing.T) {
	for _, f := range corrFindings(t, correctionRoot(t), Draft) {
		if f.Level == Warning {
			t.Errorf("unexpected warning: %s", f)
		}
	}
}

// A link into a seed or a correction folder is a link into another change.
func TestCorrectionLinkTargetAccepted(t *testing.T) {
	if !otherEntryRe.MatchString("correction-fix-owner") || !otherEntryRe.MatchString("seed-x") || otherEntryRe.MatchString("fix-owner") {
		t.Error("otherEntryRe must name the seed and correction prefixes")
	}
}

// V27 holds for a correction after its sampled line, as it does for a seed.
func TestCorrectionV27EditAfterSample(t *testing.T) {
	build := func(t *testing.T) (*gitRepo, string) {
		g, _, _ := newGitRepo(t)
		g.write("openspec/specs/ship-a/spec.md", shipAMain)
		g.write("openspec/specs/ship-b/spec.md", shipBMain)
		g.write(corrDir+"/.openspec.yaml", corrOpenSpec)
		g.write(corrDir+"/specs/ship-a/spec.md", corrDeltaA)
		g.write(corrDir+"/specs/ship-b/spec.md", corrDeltaB)
		g.write(corrDir+"/source.md", corrSource)
		return g, g.commit("three: a sampled correction")
	}
	const spec = corrDir + "/specs/ship-a/spec.md"
	const src = corrDir + "/source.md"
	t.Run("changed text, sampled unchanged", func(t *testing.T) {
		g, _ := build(t)
		g.replace(spec, "The CLI SHALL record the owner as cli.", "The CLI SHALL record the owner as the cli.")
		if res := g.vet(nil); !has(res, "V27", "while sampled is unchanged") {
			t.Errorf("want V27 for a correction:\n%s", dump(res))
		}
	})
	t.Run("changed text, sampled again", func(t *testing.T) {
		g, three := build(t)
		g.replace(spec, "The CLI SHALL record the owner as cli.", "The CLI SHALL record the owner as the cli.")
		g.replace(src, "sampled: 2026-10-10 abcdef1", "sampled: 2026-10-11 "+three[:12])
		if res := g.vet(nil); count(res, "V27") != 0 {
			t.Errorf("a new sampled line is the re-sample:\n%s", dump(res))
		}
	})
	t.Run("an edit before the first sample is free", func(t *testing.T) {
		g, _ := build(t)
		g.replace(src, "sampled: 2026-10-10 abcdef1\n", "")
		g.commit("four: the correction loses its sampled line")
		g.replace(spec, "The CLI SHALL record the owner as cli.", "The CLI SHALL record the owner as the cli.")
		if res := g.vet(nil); count(res, "V27") != 0 {
			t.Errorf("an edit before sampling is free:\n%s", dump(res))
		}
	})
}
