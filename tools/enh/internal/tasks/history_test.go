package tasks

import (
	"strings"
	"testing"
)

func TestHistoryFollowsArchivedDeltas(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.tickAll()
	f.mustNil(f.env.Deliver("0100"))
	f.reset()

	f.mustNil(f.env.History("Render records the held versions", ""))
	out := f.out.String()
	if !strings.Contains(out, "existing-cap / Render records the held versions") || !strings.Contains(out, "2026-10-11  0100") || !strings.Contains(out, "MODIFIED") {
		t.Errorf("history:\n%s", out)
	}
	f.reset()
	f.mustNil(f.env.History("Readiness is reported", "existing-cap"))
	if !strings.Contains(f.out.String(), "Reason: Readiness moves to the conditions.") {
		t.Errorf("removed:\n%s", f.out)
	}
	if err := f.env.History("Nothing like this", ""); !IsUsage(err) {
		t.Errorf("unknown: %v", err)
	}
}

func TestHistorySkipsRejectedEntries(t *testing.T) {
	f := newFx(t)
	f.addedDelta(2, "")
	f.commit("docs: entry")
	f.mustNil(f.env.End(Reject, "0100", "no", nil))
	f.reset()
	if err := f.env.History("Thing number 1 is held", ""); !IsUsage(err) {
		t.Errorf("a rejected entry is in the history: %v\n%s", err, f.out)
	}
}

func TestStaleCommand(t *testing.T) {
	f := newFx(t)
	f.accepted()
	f.mustNil(f.env.Stale("0100"))
	if !strings.Contains(f.out.String(), "0 flags") {
		t.Errorf("fresh:\n%s", f.out)
	}
	f.changeMain()
	f.reset()
	if err := f.env.Stale("0100"); !IsRefusal(err) {
		t.Fatalf("stale: %v", err)
	}
	if !strings.Contains(f.out.String(), "every catalog path it held, by path.") {
		t.Errorf("both texts are printed:\n%s", f.out)
	}
	g := newFx(t)
	if err := g.env.Stale("0100"); !IsRefusal(err) {
		t.Errorf("draft: %v", err)
	}
}
