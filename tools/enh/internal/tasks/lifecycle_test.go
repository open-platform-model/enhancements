package tasks

import (
	"strings"
	"testing"
)

const demo = "openspec/changes/0100-demo-entry"

// accepted brings the demo entry to status accepted and commits it.
func (f *fx) accepted() {
	f.t.Helper()
	f.addedDelta(4, modifiedAndRemoved)
	f.commit("docs: entry")
	f.env.Seed = seedPtr(1)
	f.mustNil(f.env.Accept("0100"))
	f.env.Confirm = true
	f.mustNil(f.env.Accept("0100"))
	f.env.Confirm = false
	f.commit("docs: accept 0100")
	f.reset()
}

func (f *fx) tickAll() {
	f.t.Helper()
	f.mustNil(f.env.Tick("0100", "1.1", "add-fixture"))
	f.mustNil(f.env.Tick("0100", "1.2", "PR 12"))
	f.commit("docs: tick")
	f.reset()
}

// changeMain edits a requirement of the main spec and commits it.
func (f *fx) changeMain() {
	f.t.Helper()
	s := f.read("openspec/specs/existing-cap/spec.md")
	f.write("openspec/specs/existing-cap/spec.md", strings.Replace(s, "it held.", "it held, by path.", 1))
	f.commit("docs: another delivery changed the spec")
}

func TestResampleFlagsAndConfirm(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.changeMain()

	// edit the entry after the accept commit
	d := f.read(demo + "/specs/demo-cap/spec.md")
	f.write(demo+"/specs/demo-cap/spec.md", strings.Replace(d, "report the held versions of the catalog.\n\n#### Scenario: Held 2", "report the held versions of the catalog and the path.\n\n#### Scenario: Held 2", 1))

	f.mustNil(f.env.Resample("0100"))
	out := f.out.String()
	for _, want := range []string{
		"stale base (against the accepted commit", "1 flags",
		"existing-cap / Render records the held versions   MODIFIED  (text changed)",
		"every catalog path it held.", "every catalog path it held, by path.",
		"[ADDED EDITED] demo-cap/Thing number 2 is held", "nearest in specs/ (3):",
		"Then `CONFIRM=1 enh resample 0100-demo-entry`",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("output lacks %q\n%s", want, out)
		}
	}
	if strings.Contains(out, "Thing number 3 is held") {
		t.Errorf("an unedited requirement is listed\n%s", out)
	}
	if strings.Contains(out, "refused: ") {
		t.Error("resample must never refuse on a flag")
	}

	// CONFIRM rewrites accepted: and the flag clears because the base moved
	f.reset()
	f.env.Confirm = true
	f.mustNil(f.env.Resample("0100"))
	head := strings.TrimSpace(f.git("rev-parse", "--short", "HEAD"))
	if !strings.Contains(f.read(demo+"/config.yaml"), `accepted: "2026-10-11 `+head+`"`) {
		t.Errorf("config:\n%s", f.read(demo+"/config.yaml"))
	}
	if !strings.Contains(f.out.String(), "stale base against "+head+": 0 flags") {
		t.Errorf("output:\n%s", f.out)
	}
}

func TestResampleConfirmNeedsAPlainRun(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.env.Confirm = true
	if err := f.env.Resample("0100"); !IsRefusal(err) || !strings.Contains(err.Error(), "CONFIRM before a plain run") {
		t.Errorf("err = %v", err)
	}
}

func TestResampleNeedsAnAcceptedEntryAndNotASeed(t *testing.T) {
	f := newFx(t)
	if err := f.env.Resample("0100"); !IsRefusal(err) {
		t.Errorf("draft: %v", err)
	}
	f.seed(3)
	if err := f.env.Resample("seed-new-cap"); !IsUsage(err) {
		t.Errorf("seed: %v", err)
	}
	if err := f.env.Resample("9999"); !IsUsage(err) {
		t.Errorf("unknown: %v", err)
	}
}

func TestResampleWithNoEditsListsNothing(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.mustNil(f.env.Resample("0100"))
	if !strings.Contains(f.out.String(), "no requirement differs") || !strings.Contains(f.out.String(), "0 flags") {
		t.Errorf("output:\n%s", f.out)
	}
}

func TestDeliver(t *testing.T) {
	f := newFx(t)
	f.accepted()

	// unticked lines refuse and change nothing
	if err := f.env.Deliver("0100"); !IsRefusal(err) || !strings.Contains(f.out.String(), "V24") {
		t.Fatalf("unticked: %v\n%s", err, f.out)
	}
	for _, c := range f.calls {
		if strings.HasPrefix(c, "archive") {
			t.Fatal("archive ran on a refused delivery")
		}
	}
	f.tickAll()

	// a stale base refuses
	f.changeMain()
	if err := f.env.Deliver("0100"); !IsRefusal(err) || !strings.Contains(f.out.String(), "V26") || !strings.Contains(f.out.String(), "enh resample 0100") {
		t.Fatalf("stale: %v\n%s", err, f.out)
	}
	f.reset()
	f.env.Confirm = false
	f.mustNil(f.env.Resample("0100"))
	f.env.Confirm = true
	f.mustNil(f.env.Resample("0100"))
	f.env.Confirm = false
	f.commit("docs: resample")
	f.reset()

	// a dirty tree refuses
	f.write("stray.txt", "x")
	if err := f.env.Deliver("0100"); !IsRefusal(err) || !strings.Contains(err.Error(), "working tree has changes") {
		t.Fatalf("dirty: %v", err)
	}
	f.git("rm", "-q", "--cached", "--ignore-unmatch", "stray.txt")
	if err := removeFile(f.root, "stray.txt"); err != nil {
		t.Fatal(err)
	}

	// an archive that fails puts the config back
	f.failOn = "archive"
	if err := f.env.Deliver("0100"); err == nil || !strings.Contains(err.Error(), "config.yaml was restored") {
		t.Fatalf("failing archive: %v", err)
	}
	if !strings.Contains(f.read(demo+"/config.yaml"), "status: accepted") {
		t.Error("status was not restored")
	}
	f.failOn = ""
	f.reset()

	f.mustNil(f.env.Deliver("0100"))
	if !contains(f.calls, "archive 0100-demo-entry --yes") {
		t.Errorf("calls = %v", f.calls)
	}
	arch := "openspec/changes/archive/2026-10-11-0100-demo-entry"
	if !strings.Contains(f.read(arch+"/config.yaml"), "status: delivered") || f.exists(demo) {
		t.Error("the entry was not archived as delivered")
	}
	if !strings.Contains(f.read(arch+"/README.md"), "Delivered") {
		t.Errorf("README:\n%s", f.read(arch+"/README.md"))
	}
	if subj := strings.TrimSpace(f.git("log", "-1", "--format=%s")); subj != "docs: deliver enhancement 0100 demo-entry" {
		t.Errorf("subject = %q", subj)
	}
	if st := f.git("status", "--porcelain"); st != "" {
		t.Errorf("tree not clean after the delivery commit:\n%s", st)
	}
	if n := strings.Count(f.git("log", "--format=%H", "-3"), "\n"); n != 3 {
		t.Errorf("log: %d", n)
	}
}

func TestDeliverNoCommitLeavesTheChange(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.tickAll()
	f.env.NoCommit = true
	f.mustNil(f.env.Deliver("0100"))
	if st := f.git("status", "--porcelain"); st == "" {
		t.Error("--no-commit committed")
	}
	if !strings.Contains(f.out.String(), "not committed (--no-commit)") {
		t.Errorf("output:\n%s", f.out)
	}
}

func TestDeliverRefusesADraftAndMissingEntry(t *testing.T) {
	f := newFx(t)
	if err := f.env.Deliver("0100"); !IsRefusal(err) {
		t.Errorf("draft: %v", err)
	}
	if err := f.env.Deliver("0999"); !IsUsage(err) {
		t.Errorf("unknown: %v", err)
	}
}

func TestDeliverSeedNeedsSampled(t *testing.T) {
	f := newFx(t)
	f.seed(3)
	if err := f.env.Deliver("seed-new-cap"); !IsRefusal(err) || !strings.Contains(f.out.String(), `no "sampled:`) {
		t.Fatalf("no sampled: %v\n%s", err, f.out)
	}
	f.reset()
	f.mustNil(f.env.Accept("seed-new-cap"))
	f.env.Confirm = true
	f.mustNil(f.env.Accept("seed-new-cap"))
	f.env.Confirm = false
	f.commit("docs: sampled")
	f.reset()
	f.mustNil(f.env.Deliver("seed-new-cap"))
	if !contains(f.calls, "archive seed-new-cap --yes") || !f.exists("openspec/changes/archive/2026-10-11-seed-new-cap/source.md") {
		t.Errorf("calls = %v", f.calls)
	}
	if subj := strings.TrimSpace(f.git("log", "-1", "--format=%s")); subj != "docs: deliver seed new-cap" {
		t.Errorf("subject = %q", subj)
	}
}

func contains(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func TestEnd(t *testing.T) {
	t.Run("reject a draft", func(t *testing.T) {
		f := newFx(t)
		f.mustNil(f.env.End(Reject, "0100", "not needed", nil))
		arch := "openspec/changes/archive/2026-10-11-0100-demo-entry/config.yaml"
		cfg := f.read(arch)
		if !strings.Contains(cfg, "status: rejected\n") || !strings.Contains(cfg, "rejected:\n  date: \"2026-10-11\"\n  reason: \"not needed\"\n") {
			t.Errorf("config:\n%s", cfg)
		}
		if !contains(f.calls, "archive 0100-demo-entry --skip-specs --yes") {
			t.Errorf("calls = %v", f.calls)
		}
		if subj := strings.TrimSpace(f.git("log", "-1", "--format=%s")); subj != "docs: reject enhancement 0100 demo-entry" {
			t.Errorf("subject %q", subj)
		}
		if strings.Contains(f.git("log", "-1", "--format=%B"), "not needed") {
			t.Error("the reason must stay out of the commit message")
		}
	})
	t.Run("no-validate only when asked", func(t *testing.T) {
		f := newFx(t)
		f.env.NoValidate = true
		f.mustNil(f.env.End(Withdraw, "0100", "dropped", nil))
		if !contains(f.calls, "archive 0100-demo-entry --skip-specs --yes --no-validate") {
			t.Errorf("calls = %v", f.calls)
		}
		if !strings.Contains(f.read("openspec/changes/archive/2026-10-11-0100-demo-entry/config.yaml"), "withdrawn:\n  date") {
			t.Error("no withdrawn record")
		}
	})
	t.Run("reject of an accepted entry is refused, withdraw is not", func(t *testing.T) {
		f := newFx(t)
		f.accepted()
		if err := f.env.End(Reject, "0100", "no", nil); !IsRefusal(err) {
			t.Errorf("reject accepted: %v", err)
		}
		f.mustNil(f.env.End(Withdraw, "0100", "no longer wanted", nil))
	})
	t.Run("a reason is needed", func(t *testing.T) {
		f := newFx(t)
		if err := f.env.End(Reject, "0100", "  ", nil); !IsUsage(err) {
			t.Errorf("err = %v", err)
		}
		if f.exists("openspec/changes/archive") {
			t.Error("archived without a reason")
		}
	})
	t.Run("supersede needs a successor that exists", func(t *testing.T) {
		f := newFx(t)
		if err := f.env.End(Supersede, "0100", "replaced", []string{"0555"}); !IsRefusal(err) {
			t.Errorf("missing successor: %v", err)
		}
		if err := f.env.End(Supersede, "0100", "replaced", []string{"0100"}); !IsRefusal(err) {
			t.Errorf("self: %v", err)
		}
		if err := f.env.End(Supersede, "0100", "replaced", nil); !IsUsage(err) {
			t.Errorf("none: %v", err)
		}
		f.mustNil(f.env.End(Supersede, "0100", "replaced by the older design", []string{"0001"}))
		cfg := f.read("openspec/changes/archive/2026-10-11-0100-demo-entry/config.yaml")
		if !strings.Contains(cfg, "status: superseded\n") || !strings.Contains(cfg, "superseded_by:\n  date: \"2026-10-11\"\n  ids:\n    - \"0001\"\n  reason: \"replaced by the older design\"") {
			t.Errorf("config:\n%s", cfg)
		}
	})
	t.Run("a failing archive restores the config", func(t *testing.T) {
		f := newFx(t)
		f.failOn = "archive"
		if err := f.End0(); err == nil || !strings.Contains(err.Error(), "restored") {
			t.Errorf("err = %v", err)
		}
		if strings.Contains(f.read(demo+"/config.yaml"), "rejected") {
			t.Error("config kept the record")
		}
	})
	t.Run("a dirty tree is refused", func(t *testing.T) {
		f := newFx(t)
		f.write("stray.txt", "x")
		if err := f.env.End(Reject, "0100", "no", nil); !IsRefusal(err) {
			t.Errorf("err = %v", err)
		}
	})
}

func (f *fx) End0() error { return f.env.End(Reject, "0100", "no", nil) }

func TestTick(t *testing.T) {
	f := newFx(t)
	f.mustNil(f.env.Tick("0100", "1.1", "add-fixture"))
	if !strings.Contains(f.read(demo+"/tasks.md"), "- [x] 1.1 enhancements: add the fixture (add-fixture)\n") {
		t.Errorf("tasks.md:\n%s", f.read(demo+"/tasks.md"))
	}
	if !f.exists(demo + "/README.md") {
		t.Error("index did not run")
	}
	if err := f.env.Tick("0100", "1.1", "again"); !IsRefusal(err) {
		t.Errorf("already ticked: %v", err)
	}
	if err := f.env.Tick("0100", "7.7", "x-y"); !IsRefusal(err) {
		t.Errorf("unknown line: %v", err)
	}
	for _, bad := range []string{"Bad Ref", "PR", "PR x", "-x", "commit abc12", "commit XYZ1234", "commit 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1"} {
		if err := f.env.Tick("0100", "1.2", bad); !IsUsage(err) {
			t.Errorf("ref %q: %v", bad, err)
		}
	}
	if err := f.env.Tick("0100", "1.2", "PR 12"); err != nil {
		t.Errorf("PR ref: %v", err)
	}
	g := newFx(t)
	if err := g.env.Tick("0100", "1.1", "commit 1a2b3c4"); err != nil {
		t.Errorf("commit ref: %v", err)
	}
	if !strings.Contains(g.read(demo+"/tasks.md"), "(commit 1a2b3c4)\n") {
		t.Errorf("tasks.md:\n%s", g.read(demo+"/tasks.md"))
	}
	f.seed(2)
	if err := f.env.Tick("seed-new-cap", "1.1", "x"); !IsUsage(err) {
		t.Errorf("seed: %v", err)
	}
}

func TestListShowQuestions(t *testing.T) {
	f := newFx(t)
	f.seed(2)
	f.mustNil(f.env.List(false))
	out := f.out.String()
	if !strings.Contains(out, "0100   draft") || !strings.Contains(out, "0/2") || !strings.Contains(out, "Demo Entry") || !strings.Contains(out, "seed-new-cap") {
		t.Errorf("list:\n%s", out)
	}
	f.reset()
	f.mustNil(f.env.List(true))
	if strings.Contains(f.out.String(), "Demo Entry") {
		t.Errorf("archived list shows a live entry:\n%s", f.out)
	}
	f.reset()
	f.mustNil(f.env.Show("0100"))
	for _, want := range []string{"id:       0100", "status:   draft", "affects:  enhancements, cli", "tasks:    0 of 2 ticked", "breaking: false"} {
		if !strings.Contains(f.out.String(), want) {
			t.Errorf("show lacks %q\n%s", want, f.out)
		}
	}
	f.reset()
	f.mustNil(f.env.Questions("0100"))
	if !strings.Contains(f.out.String(), "proposal.md:") || !strings.Contains(f.out.String(), "not blocking: Is the demo big enough?") {
		t.Errorf("questions:\n%s", f.out)
	}
	if err := f.env.Show("9999"); !IsUsage(err) {
		t.Errorf("unknown: %v", err)
	}
}

func TestShowOldLayout(t *testing.T) {
	f := newFx(t)
	f.write("archive/0010/config.yaml", "id: \"0010\"\nslug: artifact-identity\ntitle: Module and Catalog Identity\nsummary: >-\n  Make the path the whole\n  identity.\nstatus: delivered\ncategory: distribution\naffects: [core, cli]\ncreated: 2026-07-26\n")
	f.write("0012/config.yaml", "id: \"0012\"\nslug: k8s-tier\ntitle: A Live Old Entry\nsummary: s\nstatus: draft\ncategory: runtime\naffects: [library]\ncreated: \"2026-07-27\"\ndepends_on: [\"0006\"]\n")
	for key, wants := range map[string][]string{
		"0010": {"folder:   archive/0010 (old layout)", "title:    Module and Catalog Identity", "summary:  Make the path the whole identity.", "status:   delivered", "affects:  core, cli", "created:  2026-07-26"},
		"0012": {"folder:   0012 (old layout)", "status:   draft", "depends_on: 0006"},
	} {
		f.reset()
		f.mustNil(f.env.Show(key))
		for _, want := range wants {
			if !strings.Contains(f.out.String(), want) {
				t.Errorf("show %s lacks %q\n%s", key, want, f.out)
			}
		}
	}
	// A new-layout entry of the same id wins over its old folder.
	f.write("0100/config.yaml", "id: \"0100\"\ntitle: The old folder\n")
	f.reset()
	f.mustNil(f.env.Show("0100"))
	if strings.Contains(f.out.String(), "old layout") || !strings.Contains(f.out.String(), "Demo Entry") {
		t.Errorf("show 0100 did not prefer the new layout:\n%s", f.out)
	}
	if err := f.env.Show("0777"); !IsUsage(err) {
		t.Errorf("unknown old id: %v", err)
	}
}

func TestStaleFindingsOnlyForAcceptedEntries(t *testing.T) {
	f := newFx(t)
	st, _ := f.env.load()
	if got, err := f.env.StaleFindings(st, nil); err != nil || len(got) != 0 {
		t.Errorf("draft: %v %v", got, err)
	}
	f.accepted()
	f.changeMain()
	st, _ = f.env.load()
	got, err := f.env.StaleFindings(st, []string{"0100"})
	if err != nil || len(got) != 1 || got[0].Rule != "V26" || !strings.Contains(got[0].Msg, "Render records the held versions") {
		t.Fatalf("got %+v, %v", got, err)
	}
	if got, _ := f.env.StaleFindings(st, []string{"0200"}); len(got) != 0 {
		t.Errorf("other key: %v", got)
	}
}

func TestResampleConfirmRefusesAnEditAfterThePlainRun(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.changeMain()
	f.mustNil(f.env.Resample("0100"))
	d := f.read(demo + "/specs/demo-cap/spec.md")
	f.write(demo+"/specs/demo-cap/spec.md", strings.Replace(d, "report the held versions", "report all held versions", 1))
	f.env.Confirm = true
	err := f.env.Resample("0100")
	if !IsRefusal(err) || !strings.Contains(err.Error(), "changed since the plain run") {
		t.Fatalf("resample confirm after an edit: %v", err)
	}
	if strings.Contains(f.read(demo+"/config.yaml"), "2026-10-11 "+strings.TrimSpace(f.git("rev-parse", "--short", "HEAD"))) {
		t.Error("accepted: was rewritten")
	}
}
