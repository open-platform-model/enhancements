package tasks

import (
	"os"
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
)

const (
	corr       = "openspec/changes/correction-fix-values"
	corrSecond = `## Purpose

Hold the second capability of the correction fixtures, with one requirement to rename.

## Requirements

### Requirement: Alpha is held

The system SHALL hold alpha.

#### Scenario: Held

- **WHEN** a user asks
- **THEN** alpha is held
`
	corrDeltaExisting = `## MODIFIED Requirements

### Requirement: Render records the held versions

A render SHALL record the version of every catalog path it held and expose it on the instance.

#### Scenario: Recorded

- **WHEN** a module renders
- **THEN** the versions are recorded and exposed

## REMOVED Requirements

### Requirement: Readiness is reported

**Reason**: Readiness is shown now.

**Migration**: Replaced by "Readiness is shown"

## ADDED Requirements

### Requirement: Readiness is shown

The controller SHALL show readiness of every platform.

#### Scenario: Shown

- **WHEN** a platform is ready
- **THEN** the status says so

### Requirement: Mutation stays visible

The controller SHALL keep a visible record of each change it applies.

#### Scenario: Visible

- **WHEN** a change is applied
- **THEN** the record shows it
`
	corrDeltaSecond = `## RENAMED Requirements

- FROM: ` + "`### Requirement: Alpha is held`" + `
- TO: ` + "`### Requirement: Alpha is kept`" + `
`
	corrSourceText = `# Source note: correction-fix-values

Corrects: ` + "`existing-cap`, `second-cap`" + `. The values moved.

## Shipped by

| Capability | Requirement | Change | Shipped by | Code read |
| --- | --- | --- | --- | --- |
| ` + "`existing-cap`" + ` | Render records the held versions | MODIFIED | ` + "`library`" + ` PR 5 | ` + "`render/held.go:42`" + ` |
| ` + "`existing-cap`" + ` | Readiness is reported | REMOVED | ` + "`opm-controller`" + ` PR 9 | |
| ` + "`existing-cap`" + ` | Readiness is shown | ADDED | ` + "`opm-controller`" + ` PR 9 | |
| ` + "`existing-cap`" + ` | Mutation stays visible | ADDED | ` + "`cli`" + ` PR 11 | ` + "`cmd/apply.go:7`" + ` |
| ` + "`second-cap`" + ` | Alpha is kept | RENAMED | ` + "`core`" + ` commit abcdef1 | |

## Left out

- Nothing.
`
)

// correction writes a valid correction over two delivered capabilities and
// commits it. The main spec of second-cap is added in the same commit.
func (f *fx) correction() {
	f.write("openspec/specs/second-cap/spec.md", corrSecond)
	f.write(corr+"/.openspec.yaml", "schema: correction\ncreated: 2026-10-10\n")
	f.write(corr+"/specs/existing-cap/spec.md", corrDeltaExisting)
	f.write(corr+"/specs/second-cap/spec.md", corrDeltaSecond)
	f.write(corr+"/source.md", corrSourceText)
	f.commit("docs: correction")
}

// A valid correction over two capabilities passes vet, accept and deliver.
func TestCorrectionLifecycle(t *testing.T) {
	f := newFx(t)
	f.correction()
	res, err := f.env.vet(vet.Accept, "correction-fix-values")
	f.mustNil(err)
	if res.HasErrors() {
		t.Fatalf("vet:\n%s", res.Findings)
	}

	// Deliver before the sample is refused.
	if err := f.env.Deliver("correction-fix-values"); !IsRefusal(err) || !strings.Contains(f.out.String(), `no "sampled:`) {
		t.Fatalf("deliver without a sample: %v\n%s", err, f.out)
	}

	f.reset()
	f.mustNil(f.env.Accept("correction-fix-values"))
	out := f.out.String()
	for _, want := range []string{
		"Every requirement block is shown (5: 1 MODIFIED, 1 REMOVED, 1 RENAMED, 2 ADDED)",
		"[MODIFIED] existing-cap/Render records the held versions", "main requirement now:", "shipped by: `library` PR 5", "code read:  `render/held.go:42`",
		"[REMOVED] existing-cap/Readiness is reported", "[RENAMED] second-cap: \"Alpha is held\" to \"Alpha is kept\"",
		"[ADDED] existing-cap/Mutation stays visible", "NEW REQUIREMENT, NOT A RENAME",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("sample lacks %q\n%s", want, out)
		}
	}
	if strings.Count(out, "NEW REQUIREMENT, NOT A RENAME") != 1 {
		t.Errorf("only the ADDED block that replaces nothing is flagged:\n%s", out)
	}
	if strings.Contains(out, "Random seed") {
		t.Error("a correction sample is not a draw")
	}

	before := f.read(corr + "/specs/existing-cap/spec.md")
	f.env.Confirm = true
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = false
	src := f.read(corr + "/source.md")
	head := strings.TrimSpace(f.git("rev-parse", "--short", "HEAD"))
	if !strings.HasSuffix(src, "\n\nsampled: 2026-10-11 "+head+"\n") || strings.Count(src, "sampled:") != 1 {
		t.Errorf("source.md:\n%s", src)
	}
	if f.read(corr+"/specs/existing-cap/spec.md") != before || f.exists(corr+"/config.yaml") {
		t.Error("accept of a correction wrote more than the sampled line")
	}
	f.commit("docs: sampled")

	f.reset()
	f.mustNil(f.env.Deliver("correction-fix-values"))
	if !contains(f.calls, "archive correction-fix-values --yes") || !f.exists("openspec/changes/archive/2026-10-11-correction-fix-values/source.md") {
		t.Errorf("calls = %v", f.calls)
	}
	if subj := strings.TrimSpace(f.git("log", "-1", "--format=%s")); subj != "docs: deliver correction fix-values" {
		t.Errorf("subject = %q", subj)
	}
}

// A correction takes no number, shows in no generated file and is listed.
func TestCorrectionTakesNoNumber(t *testing.T) {
	f := newFx(t)
	f.correction()
	f.mustNil(f.env.RunIndex())
	for _, p := range []string{"INDEX.md", "GRAPH.md", "openspec/changes/0100-demo-entry/README.md"} {
		if strings.Contains(f.read(p), "correction-fix-values") {
			t.Errorf("%s names the correction", p)
		}
	}
	if f.exists(corr + "/README.md") {
		t.Error("index wrote a README for a correction")
	}
	f.reset()
	f.mustNil(f.env.List(false))
	if !strings.Contains(f.out.String(), "correction-fix-values correction") {
		t.Errorf("list:\n%s", f.out)
	}
	f.reset()
	f.mustNil(f.env.Show("correction-fix-values"))
	if !strings.Contains(f.out.String(), "kind:     correction (existing-cap, second-cap)") {
		t.Errorf("show:\n%s", f.out)
	}
	// The next entry id is not taken by the correction.
	id, err := f.env.New(NewArgs{Slug: "next", Title: "Next", Summary: "OPM gains X.", Category: "tooling", Affects: []string{"cli"}})
	if err != nil {
		t.Fatal(err)
	}
	if !f.exists("openspec/changes/" + id + "-next/config.yaml") {
		t.Error("the new entry has no folder")
	}
}

// A correction names a capability that is delivered. The task refuses one that is not,
// and a hand-made folder fails the check.
func TestCorrectionNeedsADeliveredCapability(t *testing.T) {
	f := newFx(t)
	if err := f.env.CorrectionNew("x", []string{"missing-cap"}); !IsRefusal(err) {
		t.Errorf("task: %v", err)
	}
	f.correction()
	f.mustNil(os.RemoveAll(f.root + "/openspec/specs/second-cap"))
	res, err := f.env.vet(vet.Draft, "correction-fix-values")
	f.mustNil(err)
	found := false
	for _, fi := range res.Findings {
		if fi.Rule == "V36" && strings.Contains(fi.Msg, "is not in openspec/specs/") {
			found = true
		}
	}
	if !found {
		t.Errorf("no V36 for a missing capability: %v", res.Findings)
	}
}

// A correction with a missing evidence row is refused by accept.
func TestCorrectionMissingEvidenceIsRefused(t *testing.T) {
	f := newFx(t)
	f.correction()
	f.write(corr+"/source.md", strings.Replace(corrSourceText, "| `existing-cap` | Mutation stays visible | ADDED | `cli` PR 11 | `cmd/apply.go:7` |\n", "", 1))
	f.commit("docs: row removed")
	f.reset()
	if err := f.env.Accept("correction-fix-values"); !IsRefusal(err) {
		t.Fatalf("accept: %v", err)
	}
	if !strings.Contains(f.out.String(), "V37") || !strings.Contains(f.out.String(), "Mutation stays visible") {
		t.Errorf("output:\n%s", f.out)
	}
	f.env.Confirm = true
	if err := f.env.Accept("correction-fix-values"); !IsRefusal(err) {
		t.Errorf("confirm: %v", err)
	}
}

// The delivery is refused when a main requirement the correction touches changed after the sample.
func TestCorrectionStaleBaseBlocksDelivery(t *testing.T) {
	f := newFx(t)
	f.correction()
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = true
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = false
	f.commit("docs: sampled")
	// a main requirement the correction touches changes
	p := "openspec/specs/existing-cap/spec.md"
	f.write(p, strings.Replace(f.read(p), "A render SHALL record the version of every catalog path it held.", "A render SHALL record the version of every catalog path it held, by path.", 1))
	f.commit("docs: main changed")
	f.reset()
	if err := f.env.Deliver("correction-fix-values"); !IsRefusal(err) {
		t.Fatalf("deliver: %v\n%s", err, f.out)
	}
	if !strings.Contains(f.out.String(), "V26") || !strings.Contains(f.out.String(), "stale base: existing-cap / Render records the held versions") || !strings.Contains(f.out.String(), "enh accept correction-fix-values") {
		t.Errorf("output:\n%s", f.out)
	}
	f.reset()
	if err := f.env.Stale("correction-fix-values"); !IsRefusal(err) {
		t.Errorf("stale: %v", err)
	}
	// a new sample clears it
	f.reset()
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = true
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = false
	f.commit("docs: sampled again")
	f.reset()
	f.mustNil(f.env.Deliver("correction-fix-values"))
}

func TestCorrectionRefusedByEntryOnlyCommands(t *testing.T) {
	f := newFx(t)
	f.correction()
	if err := f.env.Tick("correction-fix-values", "1.1", "x"); !IsUsage(err) {
		t.Errorf("tick: %v", err)
	}
	if err := f.env.Resample("correction-fix-values"); !IsUsage(err) {
		t.Errorf("resample: %v", err)
	}
	for _, kind := range []string{Reject, Withdraw} {
		if err := f.env.End(kind, "correction-fix-values", "no", nil); !IsRefusal(err) || !strings.Contains(err.Error(), "correction") {
			t.Errorf("%s: %v", kind, err)
		}
	}
	if err := f.env.End(Supersede, "correction-fix-values", "no", []string{"0100"}); !IsRefusal(err) {
		t.Errorf("supersede: %v", err)
	}
}

// task history follows a RENAMED heading of a correction, and labels the row with its folder.
func TestCorrectionRenameIsFollowedByHistory(t *testing.T) {
	f := newFx(t)
	f.correction()
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = true
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = false
	f.commit("docs: sampled")
	f.mustNil(f.env.Deliver("correction-fix-values"))
	for _, name := range []string{"Alpha is held", "Alpha is kept"} {
		f.reset()
		f.mustNil(f.env.History(name, ""))
		out := f.out.String()
		if !strings.Contains(out, "second-cap / Alpha is kept") || !strings.Contains(out, "2026-10-11  correction-fix-values") ||
			!strings.Contains(out, "RENAMED") || !strings.Contains(out, `from "Alpha is held" to "Alpha is kept"`) {
			t.Errorf("history of %q:\n%s", name, out)
		}
	}
	// the replaced requirement is followed too
	f.reset()
	f.mustNil(f.env.History("Readiness is reported", "existing-cap"))
	if !strings.Contains(f.out.String(), "Readiness is shown") || !strings.Contains(f.out.String(), "correction-fix-values") {
		t.Errorf("history of a replaced requirement:\n%s", f.out)
	}
}

// Another folder of the same name, a later correction, is a different change.
func TestCorrectionNameMayReturnAfterTheArchive(t *testing.T) {
	f := newFx(t)
	f.correction()
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = true
	f.mustNil(f.env.Accept("correction-fix-values"))
	f.env.Confirm = false
	f.commit("docs: sampled")
	f.mustNil(f.env.Deliver("correction-fix-values"))
	f.reset()
	f.mustNil(f.env.CorrectionNew("fix-values", []string{"existing-cap"}))
}

// The shipped templates, left unfilled, are refused: their placeholders name nothing real.
func TestUnfilledCorrectionTemplatesAreRefused(t *testing.T) {
	f := newFx(t)
	f.mustNil(f.env.CorrectionNew("from-template", []string{"existing-cap"}))
	src, err := os.ReadFile("../../../../openspec/schemas/correction/templates/source.md")
	if err != nil {
		t.Fatal(err)
	}
	spec, err := os.ReadFile("../../../../openspec/schemas/correction/templates/spec.md")
	if err != nil {
		t.Fatal(err)
	}
	// Unfilled, the templates are refused: the placeholders name nothing real.
	f.write("openspec/changes/correction-from-template/specs/existing-cap/spec.md", string(spec))
	f.write("openspec/changes/correction-from-template/source.md", string(src))
	res, err := f.env.vet(vet.Draft, "correction-from-template")
	f.mustNil(err)
	found := false
	for _, fi := range res.Findings {
		if fi.Rule == "V37" || fi.Rule == "V20" {
			found = true
		}
	}
	if !found {
		t.Errorf("the unfilled templates draw no V20 or V37 finding: %v", res.Findings)
	}
	// The template of source.md holds no sample line of its own.
	if strings.Contains(strings.ReplaceAll(string(src), "`sampled:", ""), "\nsampled:") {
		t.Error("the source template carries a sampled: line")
	}
}
