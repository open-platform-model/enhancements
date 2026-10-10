package specsrule

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/testrepo"
)

// The replay tests run the real OpenSpec CLI at the pinned version. They skip
// when it is not installed, so the other tests still run everywhere; CI
// installs the pinned version, so there they run.
func needOpenSpec(t *testing.T) {
	t.Helper()
	out, err := exec.Command("openspec", "--version").Output()
	if err != nil {
		t.Skip("openspec is not installed")
	}
	if got := strings.TrimSpace(string(out)); got != PinnedOpenSpec {
		t.Skipf("openspec %s is installed, the rule pins %s", got, PinnedOpenSpec)
	}
}

const draftConfig = "id: \"0100\"\nslug: demo\ntitle: Demo\nstatus: %s\ncategory: tooling\n"

func spec(purpose, body string) string {
	return "## Purpose\n\n" + purpose + "\n\n## ADDED Requirements\n\n" + body
}

const thing = "### Requirement: Thing is held\n\nThe system SHALL hold thing.\n\n#### Scenario: Held\n\n- **WHEN** a user asks\n- **THEN** thing is held\n"

const otherThing = "### Requirement: Other is held\n\nThe system SHALL hold other.\n\n#### Scenario: Held\n\n- **WHEN** a user asks\n- **THEN** other is held\n"

const purposeText = "Show the replay at work on one small capability so that every rule has a fixture."

// rig is a temporary repository with an OpenSpec store: a config, one
// capability already in specs/ and two changes in changes/.
type rig struct {
	t    *testing.T
	root string
	base string
}

func newRig(t *testing.T) *rig {
	t.Helper()
	r := &rig{t: t, root: testrepo.New(t)}
	r.write("openspec/config.yaml", "schema: spec-driven\n")
	r.write("openspec/specs/existing/spec.md", "# existing Specification\n\n## Purpose\nThe first purpose of the capability that exists already.\n\n## Requirements\n\n### Requirement: It exists\n\nThe system SHALL exist.\n\n#### Scenario: Exists\n\n- **WHEN** a\n- **THEN** b\n")
	r.change("0100-demo", "demo-cap", thing, "draft")
	r.change("0101-more", "more-cap", otherThing, "draft")
	r.write("openspec/changes/seed-shipped/.openspec.yaml", "schema: seed\ncreated: 2026-10-10\n")
	r.write("openspec/schemas/seed/schema.yaml", "name: seed\nversion: 1\ndescription: test seed\nartifacts:\n  - id: specs\n    generates: \"specs/**/*.md\"\n    description: specs\n    template: spec.md\n    instruction: write\n    requires: []\n")
	r.write("openspec/schemas/seed/templates/spec.md", "## Purpose\n")
	r.write("openspec/changes/seed-shipped/specs/shipped/spec.md", spec(purposeText, thing))
	r.base = testrepo.Commit(t, r.root, "docs: base")
	testrepo.Git(t, r.root, "checkout", "-q", "-b", "work")
	return r
}

func (r *rig) write(rel, text string) { testrepo.Write(r.t, r.root, rel, text) }

func (r *rig) read(rel string) string {
	r.t.Helper()
	b, err := os.ReadFile(filepath.Join(r.root, filepath.FromSlash(rel)))
	if err != nil {
		r.t.Fatal(err)
	}
	return string(b)
}

func (r *rig) change(name, capability, body, status string) {
	r.write("openspec/changes/"+name+"/.openspec.yaml", "schema: spec-driven\ncreated: 2026-10-10\n")
	r.write("openspec/changes/"+name+"/config.yaml", strings.Replace(draftConfig, "%s", status, 1))
	r.write("openspec/changes/"+name+"/specs/"+capability+"/spec.md", spec(purposeText, body))
}

// deliver does what `enh deliver` does to the tree: set the status and run the
// real archive.
func (r *rig) deliver(name string) {
	r.t.Helper()
	cfg := "openspec/changes/" + name + "/config.yaml"
	if _, err := os.Stat(filepath.Join(r.root, cfg)); err == nil {
		r.write(cfg, strings.Replace(r.read(cfg), "status: draft", "status: delivered", 1))
	}
	cmd := exec.Command("openspec", "archive", name, "--yes")
	cmd.Dir = r.root
	cmd.Env = append(os.Environ(), "OPENSPEC_TELEMETRY=0", "NO_COLOR=1")
	if out, err := cmd.CombinedOutput(); err != nil {
		r.t.Fatalf("openspec archive %s: %v\n%s", name, err, out)
	}
}

func (r *rig) commit(msg string) string { return testrepo.Commit(r.t, r.root, msg) }

func (r *rig) check(base string) *Result {
	r.t.Helper()
	res, err := Check(Options{Root: r.root, Base: base})
	if err != nil {
		r.t.Fatal(err)
	}
	return res
}

func (res *Result) failureWith(want string) bool {
	for _, f := range res.Failures {
		if strings.Contains(f, want) {
			return true
		}
	}
	return false
}

func wantFail(t *testing.T, res *Result, want string) {
	t.Helper()
	if res.OK() || !res.failureWith(want) {
		t.Errorf("want a failure containing %q, got ok=%v\nfailures: %q\nlines: %q", want, res.OK(), res.Failures, res.Lines)
	}
}

func wantOK(t *testing.T, res *Result) {
	t.Helper()
	if !res.OK() {
		t.Errorf("want a pass, got failures %q\nlines: %q", res.Failures, res.Lines)
	}
}

func TestNoChangeToSpecsPasses(t *testing.T) {
	r := newRig(t)
	r.write("openspec/changes/0100-demo/proposal.md", "x\n")
	r.commit("docs: touch a draft")
	res := r.check(r.base)
	wantOK(t, res)
	if !strings.Contains(strings.Join(res.Lines, "\n"), "step 1: no path") {
		t.Errorf("lines: %q", res.Lines)
	}
}

func TestADeliveryThatEqualsTheReplayPasses(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.deliver("0100-demo")
	r.commit("feat: deliver 0100")
	res := r.check(r.base)
	wantOK(t, res)
	log := strings.Join(res.Lines, "\n")
	for _, want := range []string{"step 2: one archived folder", "step 3: replayed `openspec archive 0100-demo --yes` (OpenSpec 1.14.1)", "step 4: openspec/specs equals the replay byte for byte"} {
		if !strings.Contains(log, want) {
			t.Errorf("log lacks %q:\n%s", want, log)
		}
	}
}

func TestASeedDeliveryPasses(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.deliver("seed-shipped")
	r.commit("feat: deliver the seed")
	wantOK(t, r.check(r.base))
}

// The replay is the point: specs/ that differs from what archive produces by
// one word fails, though the archive folder is there.
func TestAHandEditedSpecAfterTheArchiveFails(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.deliver("0100-demo")
	p := "openspec/specs/demo-cap/spec.md"
	r.write(p, strings.Replace(r.read(p), "SHALL hold thing", "SHALL hold things", 1))
	r.commit("feat: deliver 0100, with a hand edit")
	res := r.check(r.base)
	wantFail(t, res, "openspec/specs/demo-cap/spec.md: head differs from the replay")
	wantFail(t, res, `replay "The system SHALL hold thing."`)
}

func TestASpecFileWrittenWithoutAnArchiveFails(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.write("openspec/specs/sneaky/spec.md", "# sneaky Specification\n\n## Purpose\nA capability that arrived without a delivery or a seed.\n\n## Requirements\n")
	r.commit("docs: add a spec by hand")
	wantFail(t, r.check(r.base), "exactly one folder")
}

func TestAnExtraSpecFileBesideADeliveryFails(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.deliver("0100-demo")
	r.write("openspec/specs/extra/spec.md", "# extra Specification\n\n## Purpose\nAn extra capability that the archive did not write.\n\n## Requirements\n")
	r.commit("feat: deliver with an extra file")
	wantFail(t, r.check(r.base), "openspec/specs/extra/spec.md: head has it, the replay does not write it")
}

func TestTwoDeliveriesInOnePullRequestFail(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.deliver("0100-demo")
	r.deliver("0101-more")
	r.commit("feat: deliver two")
	wantFail(t, r.check(r.base), "found 2")
}

func TestAnArchiveOfAnEntryThatIsNotDeliveredFails(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.write("openspec/changes/0100-demo/config.yaml", strings.Replace(draftConfig, "%s", "rejected", 1))
	cmd := exec.Command("openspec", "archive", "0100-demo", "--yes")
	cmd.Dir = r.root
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("%v\n%s", err, out)
	}
	r.commit("feat: archive a rejected entry with its specs")
	wantFail(t, r.check(r.base), `status is "rejected", not delivered`)
}

func TestTheUndatedFolderMustHaveExistedAtTheBase(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.change("0102-new", "new-cap", thing, "draft")
	r.deliver("0102-new")
	r.commit("feat: make and deliver in one pull request")
	wantFail(t, r.check(r.base), "does not exist at the merge base")
}

func TestAPurposeOnlyChangePasses(t *testing.T) {
	r := newRig(t)
	p := "openspec/specs/existing/spec.md"
	r.write(p, strings.Replace(r.read(p), "The first purpose of the capability that exists already.", "A corrected purpose that names what the capability holds for a reader.", 1))
	r.commit("docs: correct a purpose")
	res := r.check(r.base)
	wantOK(t, res)
	if !strings.Contains(strings.Join(res.Lines, "\n"), "Purpose exception") {
		t.Errorf("lines: %q", res.Lines)
	}
}

func TestAPurposeChangeWithAnotherEditFails(t *testing.T) {
	r := newRig(t)
	p := "openspec/specs/existing/spec.md"
	r.write(p, strings.Replace(strings.Replace(r.read(p), "The first purpose of the capability that exists already.", "A corrected purpose that names what the capability holds for a reader.", 1), "SHALL exist", "SHALL exist always", 1))
	r.commit("docs: correct a purpose and a requirement")
	wantFail(t, r.check(r.base), "exactly one folder")
}

func TestAPurposeChangeOfANewFileIsNotThePurposeException(t *testing.T) {
	r := newRig(t)
	r.write("openspec/specs/brand-new/spec.md", "# brand-new Specification\n\n## Purpose\nA capability that arrived by hand with a long enough purpose.\n\n## Requirements\n")
	r.commit("docs: add a capability")
	wantFail(t, r.check(r.base), "exactly one folder")
}

func TestTheReplayNeedsThePinnedVersion(t *testing.T) {
	r := newRig(t)
	r.write("openspec/specs/existing/spec.md", r.read("openspec/specs/existing/spec.md")+"\nchanged\n")
	r.write("openspec/changes/archive/2026-10-10-0100-demo/config.yaml", "status: delivered\n")
	_ = os.RemoveAll(filepath.Join(r.root, "openspec/changes/0100-demo"))
	r.commit("feat: pretend delivery")
	_, err := Check(Options{Root: r.root, Base: r.base, OpenSpec: func(dir, name string, args ...string) ([]byte, error) {
		return []byte("1.12.0\n"), nil
	}})
	if err == nil || !strings.Contains(err.Error(), "needs OpenSpec 1.14.1, found \"1.12.0\"") {
		t.Errorf("err = %v", err)
	}
}

func TestAFailedArchiveIsAFailureWithTheOutput(t *testing.T) {
	r := newRig(t)
	r.write("openspec/specs/existing/spec.md", r.read("openspec/specs/existing/spec.md")+"\nchanged\n")
	r.write("openspec/changes/archive/2026-10-10-0100-demo/config.yaml", "status: delivered\n")
	_ = os.RemoveAll(filepath.Join(r.root, "openspec/changes/0100-demo"))
	r.commit("feat: pretend delivery")
	res, err := Check(Options{Root: r.root, Base: r.base, OpenSpec: func(dir, name string, args ...string) ([]byte, error) {
		if args[0] == "--version" {
			return []byte(PinnedOpenSpec + "\n"), nil
		}
		return []byte("boom: cannot archive"), errors.New("exit status 1")
	}})
	if err != nil {
		t.Fatal(err)
	}
	wantFail(t, res, "boom: cannot archive")
}

func TestAnAllZeroBaseMeansTheParentOfHead(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.deliver("0100-demo")
	r.commit("feat: deliver 0100")
	wantOK(t, r.check(strings.Repeat("0", 40)))
}

func TestBadRefsAreRefused(t *testing.T) {
	r := newRig(t)
	for _, base := range []string{"", "--output=x", "a b", "no-such-branch"} {
		if _, err := Check(Options{Root: r.root, Base: base}); err == nil {
			t.Errorf("base %q was accepted", base)
		}
	}
	if _, err := Check(Options{Root: r.root, Base: "main", Head: "-x"}); err == nil {
		t.Error("a head that starts with a dash was accepted")
	}
}

func TestWithoutPurpose(t *testing.T) {
	a := "# x\n\n## Purpose\nOne.\n\nMore of it.\n\n## Requirements\n\nbody\n"
	b := "# x\n\n## Purpose\nTwo, longer.\n\n## Requirements\n\nbody\n"
	if withoutPurpose(a) != withoutPurpose(b) {
		t.Error("two purposes differ outside the Purpose")
	}
	if withoutPurpose(a) == withoutPurpose(strings.Replace(b, "body", "bod", 1)) {
		t.Error("a body difference was hidden")
	}
}
