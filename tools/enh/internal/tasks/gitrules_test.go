package tasks

import (
	"regexp"
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
)

const skippedGitRules = "no base ref"

var regexpAccepted = regexp.MustCompile(`accepted: "[^"]*"`)

// editClosedFolder edits an archived entry on the current branch, which V31
// reports against the base.
func (f *fx) editClosedFolder() {
	f.t.Helper()
	f.write("archive/0001/config.yaml", "id: \"0001\"\nslug: old-entry\ntitle: Old Entry Edited\nstatus: delivered\ncategory: tooling\ncreated: 2026-01-01\nupdated: 2026-02-01\n")
	f.commit("docs: edit a closed entry")
}

// A task checks the entry it names, so V31 (which reads the archived folders
// that the keys select) has nothing to say about another entry's closed
// folder. The vet call of the tasks still carries the base, so the same call
// without a key shows V31 at work.
func TestTaskVetCarriesTheBase(t *testing.T) {
	f := newFx(t)
	f.addedDelta(4, "")
	f.commit("docs: entry")
	f.git("checkout", "-q", "-b", "work")
	f.editClosedFolder()

	res, err := f.env.vet(vet.Accept)
	f.mustNil(err)
	var v31 bool
	for _, fd := range res.Findings {
		v31 = v31 || (fd.Rule == "V31" && strings.Contains(fd.Path, "archive/0001"))
	}
	if !v31 {
		t.Errorf("V31 did not run: %v", res.Findings)
	}
	for _, s := range res.Skipped {
		if strings.Contains(s, skippedGitRules) {
			t.Errorf("skipped line %q", s)
		}
	}

	// the base is the one the task was given
	f.env.Base = "work"
	res, err = f.env.vet(vet.Accept)
	f.mustNil(err)
	for _, fd := range res.Findings {
		if fd.Rule == "V31" {
			t.Errorf("V31 with the work branch as base: %v", fd)
		}
	}
}

func TestAcceptPrintsNoSkippedLineForTheGitRules(t *testing.T) {
	f := newFx(t)
	f.addedDelta(4, "")
	f.commit("docs: entry")
	f.git("checkout", "-q", "-b", "work")
	f.env.Base = "main"
	f.env.Seed = seedPtr(2)
	f.mustNil(f.env.Accept("0100"))
	if out := f.out.String(); strings.Contains(out, skippedGitRules) {
		t.Errorf("accept prints a skipped line for the git rules\n%s", out)
	}
}

func TestAcceptWithACleanBranchSkipsNothing(t *testing.T) {
	f := newFx(t)
	f.addedDelta(4, "")
	f.commit("docs: entry")
	f.env.Seed = seedPtr(2)
	f.mustNil(f.env.Accept("0100"))
	if out := f.out.String(); strings.Contains(out, skippedGitRules) || !strings.Contains(out, "0 errors") {
		t.Errorf("clean accept:\n%s", out)
	}
}

func TestAcceptNamesAMissingBase(t *testing.T) {
	f := newFx(t)
	f.addedDelta(4, "")
	f.commit("docs: entry")
	f.env.Base = "no-such-branch"
	err := f.env.Accept("0100")
	if err == nil || !strings.Contains(err.Error(), "no-such-branch") {
		t.Fatalf("missing base: %v", err)
	}
}

func TestDeliverRunsV7(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.tickAll()
	f.git("checkout", "-q", "-b", "work")
	f.write("notes.txt", "x")
	off := f.commit("docs: a commit that main does not have")
	cfg := f.read(demo + "/config.yaml")
	f.write(demo+"/config.yaml", regexpAccepted.ReplaceAllString(cfg, `accepted: "2026-10-11 `+off+`"`))
	f.commit("docs: point accepted at the branch")
	f.env.Base = "main"

	err := f.env.Deliver("0100")
	out := f.out.String()
	if !IsRefusal(err) || !strings.Contains(out, "V7") || !strings.Contains(out, "is not an ancestor of main") {
		t.Fatalf("V7 did not refuse at deliver: %v\n%s", err, out)
	}
	if strings.Contains(out, skippedGitRules) {
		t.Errorf("deliver still prints a skipped line\n%s", out)
	}
}

func TestDeliverRunsV27(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.tickAll()
	f.git("checkout", "-q", "-b", "work")
	p := demo + "/specs/demo-cap/spec.md"
	f.write(p, strings.Replace(f.read(p), "report the held versions", "report the versions it held", 1))
	f.commit("docs: edit an accepted requirement")
	f.env.Base = "main"

	err := f.env.Deliver("0100")
	out := f.out.String()
	if !IsRefusal(err) || !strings.Contains(out, "V27") {
		t.Fatalf("V27 did not refuse at deliver: %v\n%s", err, out)
	}
}

func TestDeliverWithACleanBranchSkipsNothing(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.tickAll()
	f.mustNil(f.env.Deliver("0100"))
	if strings.Contains(f.out.String(), skippedGitRules) {
		t.Errorf("deliver printed a skipped line\n%s", f.out)
	}
}
