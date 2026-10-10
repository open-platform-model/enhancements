package tasks

import (
	"fmt"
	"os"
	"regexp"
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
)

func seedPtr(n uint64) *uint64 { return &n }

func TestAcceptPlainPrintsSampleAndCollisions(t *testing.T) {
	f := newFx(t)
	f.addedDelta(31, modifiedAndRemoved)
	f.env.Seed = seedPtr(7)
	f.mustNil(f.env.Accept("0100"))
	out := f.out.String()

	for _, want := range []string{
		"accept 0100-demo-entry", "vet (accept mode): 0 errors", "Blocking questions: none",
		"Of 31 ADDED requirements, 4 are drawn at random", "Random seed: 7 (repeat the draw with --seed 7)",
		"[MODIFIED] existing-cap/Render records the held versions", "[REMOVED] existing-cap/Readiness is reported",
		"**Reason**: Readiness moves to the conditions.", "Collision review.", "Jaccard",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("output lacks %q\n%s", want, out)
		}
	}
	if n := strings.Count(out, "[ADDED] "); n != 4 {
		t.Errorf("%d ADDED requirements drawn, want 4", n)
	}
	if strings.Contains(out, "refused:") {
		t.Errorf("a clean entry printed a refusal\n%s", out)
	}
	// 31 collision blocks; the fixture holds 4 requirements and the entry removes or modifies 2
	nearRe := regexp.MustCompile(`(?m)^    \d\.\d\d \(\d+ shared\) \| (\S.*)$`)
	hits := nearRe.FindAllStringSubmatch(out, -1)
	if len(hits) != 31*2 {
		t.Errorf("%d neighbours listed, want %d", len(hits), 31*2)
	}
	for _, h := range hits {
		if strings.Contains(h[1], "Render records the held versions") || strings.Contains(h[1], "Readiness is reported") {
			t.Errorf("a modified or removed requirement is in the collision list: %s", h[1])
		}
	}
	if !strings.Contains(out, "CONFIRM=1 enh accept 0100-demo-entry") && !strings.Contains(out, "CONFIRM=1 enh accept 0100") {
		t.Errorf("no next step\n%s", out)
	}

	// the same seed gives the same draw
	first := drawn(out)
	f.reset()
	f.mustNil(f.env.Accept("0100"))
	if got := drawn(f.out.String()); strings.Join(got, "|") != strings.Join(first, "|") {
		t.Errorf("the draw changed with the same seed:\n%v\n%v", first, got)
	}
	// another seed draws something else
	f.reset()
	f.env.Seed = seedPtr(8)
	f.mustNil(f.env.Accept("0100"))
	if got := drawn(f.out.String()); strings.Join(got, "|") == strings.Join(first, "|") {
		t.Error("two seeds gave one draw")
	}
}

func drawn(out string) []string {
	var d []string
	for _, l := range strings.Split(out, "\n") {
		if strings.HasPrefix(l, "[ADDED] ") {
			d = append(d, l)
		}
	}
	return d
}

func TestAcceptWithoutRequirementsHasNoSample(t *testing.T) {
	f := newFx(t)
	f.write("openspec/changes/0100-demo-entry/.openspec.yaml", "schema: enhancement\ncreated: 2026-10-10\nskip_specs: true\n")
	f.git("rm", "-rq", "--", "openspec/changes/0100-demo-entry/specs")
	f.mustNil(f.env.Accept("0100"))
	if !strings.Contains(f.out.String(), "has no sample") {
		t.Errorf("output:\n%s", f.out)
	}
}

func TestAcceptRefusedStillPrintsSampleAndList(t *testing.T) {
	f := newFx(t)
	f.addedDelta(5, "")
	cfg := f.read("openspec/changes/0100-demo-entry/config.yaml")
	f.write("openspec/changes/0100-demo-entry/config.yaml", strings.Replace(cfg, "breaking: false\n", "", 1))
	f.env.Seed = seedPtr(1)
	err := f.env.Accept("0100")
	if !IsRefusal(err) {
		t.Fatalf("err = %v, want a refusal", err)
	}
	out := f.out.String()
	i := strings.Index(out, "refused: fix the errors first")
	if i < 0 || !strings.Contains(out, "V5") {
		t.Fatalf("no refusal header or V5\n%s", out)
	}
	if !strings.Contains(out[i:], "Random seed: 1") || !strings.Contains(out[i:], "Collision review.") {
		t.Errorf("the sample and the list must follow the refusal header\n%s", out[i:])
	}
	if strings.Contains(out, "CONFIRM=1") {
		t.Error("a refused run suggested CONFIRM")
	}
}

func TestAcceptBlockingQuestionsArePrinted(t *testing.T) {
	f := newFx(t)
	p := f.read("openspec/changes/0100-demo-entry/proposal.md")
	f.write("openspec/changes/0100-demo-entry/proposal.md", strings.Replace(p, "- Not blocking: Is the demo big enough?", "- Blocking: Which registry holds it?\n- Not blocking: Is the demo big enough?", 1))
	err := f.env.Accept("0100")
	if !IsRefusal(err) || !strings.Contains(f.out.String(), "Blocking questions (1):\n  - Which registry holds it?") {
		t.Errorf("err %v\n%s", err, f.out)
	}
}

func TestAcceptConfirmNeedsAPlainRunOnTheSameCommit(t *testing.T) {
	f := newFx(t)
	f.addedDelta(4, "")
	f.env.Seed = seedPtr(3)
	f.env.Confirm = true
	if err := f.env.Accept("0100"); !IsRefusal(err) || !strings.Contains(err.Error(), "CONFIRM before a plain run") {
		t.Fatalf("confirm with no plain run: %v", err)
	}
	if strings.Contains(f.read("openspec/changes/0100-demo-entry/config.yaml"), "accepted") {
		t.Fatal("the config was written")
	}

	f.env.Confirm = false
	f.mustNil(f.env.Accept("0100"))

	// a new commit on main moves the base: the plain run no longer counts
	f.write("notes.txt", "x")
	f.commit("docs: move main")
	f.env.Confirm = true
	if err := f.env.Accept("0100"); !IsRefusal(err) || !strings.Contains(err.Error(), "run it again") {
		t.Fatalf("confirm on another commit: %v", err)
	}

	f.env.Confirm = false
	f.mustNil(f.env.Accept("0100"))
	f.reset()
	f.env.Confirm = true
	f.mustNil(f.env.Accept("0100"))
	head := strings.TrimSpace(f.git("rev-parse", "--short", "HEAD"))
	cfg := f.read("openspec/changes/0100-demo-entry/config.yaml")
	if !strings.Contains(cfg, "status: accepted\n") || !strings.Contains(cfg, `accepted: "2026-10-11 `+head+`"`) {
		t.Errorf("config:\n%s", cfg)
	}
	if !f.exists("openspec/changes/0100-demo-entry/README.md") || !strings.Contains(f.out.String(), "index: wrote") {
		t.Errorf("index did not run\n%s", f.out)
	}
	// an accepted entry is not accepted again
	f.env.Confirm = false
	if err := f.env.Accept("0100"); !IsRefusal(err) {
		t.Errorf("accept of an accepted entry: %v", err)
	}
}

func TestAcceptConfirmRefusesWhenTheCheckerFails(t *testing.T) {
	f := newFx(t)
	f.addedDelta(4, "")
	f.mustNil(f.env.Accept("0100"))
	f.reset()
	cfg := f.read("openspec/changes/0100-demo-entry/config.yaml")
	f.write("openspec/changes/0100-demo-entry/config.yaml", strings.Replace(cfg, "breaking: false\n", "", 1))
	f.env.Confirm = true
	if err := f.env.Accept("0100"); !IsRefusal(err) {
		t.Fatalf("err = %v", err)
	}
	if strings.Contains(f.read("openspec/changes/0100-demo-entry/config.yaml"), "status: accepted") {
		t.Error("an entry with errors was accepted")
	}
}

const seedSource = "# Source note: seed-new-cap\n\nCapability: `new-cap`.\n\n## Sources\n\n| a | b | c |\n| - | - | - |\n| R | `core` spec | |\n\n<!-- the sample line is written by the accept command -->\n"

func (f *fx) seed(n int) {
	var b strings.Builder
	b.WriteString("## Purpose\n\nRecord the shipped behaviour of the new capability for the fixture seed.\n\n## ADDED Requirements\n\n")
	for i := 1; i <= n; i++ {
		fmt.Fprintf(&b, "### Requirement: Shipped thing %d\n\nThe system SHALL do shipped%d.\n\n#### Scenario: Done %d\n\n- **WHEN** a\n- **THEN** b\n\n", i, i, i)
	}
	f.write("openspec/changes/seed-new-cap/.openspec.yaml", "schema: seed\ncreated: 2026-10-10\n")
	f.write("openspec/changes/seed-new-cap/specs/new-cap/spec.md", b.String())
	f.write("openspec/changes/seed-new-cap/source.md", seedSource)
	f.commit("docs: seed")
}

func TestAcceptSeedWritesOnlyTheSampledLine(t *testing.T) {
	f := newFx(t)
	f.seed(8)
	f.env.Seed = seedPtr(5)
	f.mustNil(f.env.Accept("seed-new-cap"))
	out := f.out.String()
	if !strings.Contains(out, "Sample: 3 of 8 ADDED requirements") || strings.Count(out, "[ADDED] ") != 3 {
		t.Errorf("seed sample:\n%s", out)
	}
	if strings.Contains(out, "Collision review") {
		t.Error("a seed prints no collision list")
	}
	before := f.read("openspec/changes/seed-new-cap/specs/new-cap/spec.md")
	f.env.Confirm = true
	f.mustNil(f.env.Accept("seed-new-cap"))
	src := f.read("openspec/changes/seed-new-cap/source.md")
	head := strings.TrimSpace(f.git("rev-parse", "--short", "HEAD"))
	if !strings.HasSuffix(src, "\n\nsampled: 2026-10-11 "+head+"\n") || strings.Count(src, "sampled:") != 1 {
		t.Errorf("source.md:\n%s", src)
	}
	if f.read("openspec/changes/seed-new-cap/specs/new-cap/spec.md") != before {
		t.Error("the seed's requirements changed")
	}
	if f.exists("openspec/changes/seed-new-cap/config.yaml") || f.exists("README.md") {
		t.Error("accept of a seed wrote another file")
	}
}

func TestCollisionListKeepsARenamedRequirement(t *testing.T) {
	f := newFx(t)
	f.addedDelta(1, "")
	d := f.read(demo + "/specs/demo-cap/spec.md")
	f.write(demo+"/specs/demo-cap/spec.md", d+"### Requirement: Readiness of every platform is reported\n\nThe operator SHALL report readiness of every platform.\n\n#### Scenario: S\n\n- **WHEN** a\n- **THEN** b\n\n")
	f.write(demo+"/specs/existing-cap/spec.md", "## RENAMED Requirements\n\n- FROM: `### Requirement: Readiness is reported`\n- TO: `### Requirement: Readiness is shown`\n")
	f.mustNil(f.env.Accept("0100"))
	out := f.out.String()
	i := strings.Index(out, "demo-cap/Readiness of every platform is reported\n    ")
	if i < 0 || !strings.Contains(out[i:], "| existing-cap/Readiness is reported") {
		t.Errorf("a renamed requirement must stay in the collision list\n%s", out[i:])
	}
}

// A seed made by seed:new and filled from the shipped template must pass
// accept, plain and CONFIRM. The template is the file the schema ships; the
// test does not copy it.
func TestAcceptSeedMadeFromTheShippedTemplate(t *testing.T) {
	f := newFx(t)
	f.mustNil(f.env.SeedNew("tmpl-cap"))
	template, err := os.ReadFile("../../../../openspec/schemas/seed/templates/source.md")
	if err != nil {
		t.Fatal(err)
	}
	var b strings.Builder
	b.WriteString("## Purpose\n\nRecord the shipped behaviour of the template capability for the fixture seed.\n\n## ADDED Requirements\n\n")
	for i := 1; i <= 4; i++ {
		fmt.Fprintf(&b, "### Requirement: Shipped thing %d\n\nThe system SHALL do shipped%d.\n\n#### Scenario: Done %d\n\n- **WHEN** a\n- **THEN** b\n\n", i, i, i)
	}
	f.write("openspec/changes/seed-tmpl-cap/specs/tmpl-cap/spec.md", b.String())
	f.write("openspec/changes/seed-tmpl-cap/source.md", string(template))
	f.commit("docs: seed from the template")
	f.reset()

	f.env.Seed = seedPtr(2)
	f.mustNil(f.env.Accept("seed-tmpl-cap"))
	if strings.Contains(f.out.String(), "refused") || strings.Contains(f.out.String(), "V33") {
		t.Errorf("the plain run of a template seed was refused:\n%s", f.out)
	}
	f.env.Confirm = true
	f.mustNil(f.env.Accept("seed-tmpl-cap"))
	src := f.read("openspec/changes/seed-tmpl-cap/source.md")
	if !strings.HasSuffix(src, "\n\nsampled: 2026-10-11 "+strings.TrimSpace(f.git("rev-parse", "--short", "HEAD"))+"\n") {
		t.Errorf("CONFIRM wrote no sampled line:\n%s", src[len(src)-200:])
	}
	// The written line is the one V33 reads: deliver mode accepts it.
	res, err := f.env.vet(vet.Deliver, "seed-tmpl-cap")
	f.mustNil(err)
	for _, fi := range res.Findings {
		if fi.Rule == "V33" {
			t.Errorf("deliver mode: %s", fi)
		}
	}
}
