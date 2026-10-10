package specsrule

import (
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/testrepo"
)

func TestChainChecksEachCommitAfterSince(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	// before since: a hand edit of specs/ that the chain must not look at
	p := "openspec/specs/existing/spec.md"
	r.write(p, r.read(p)+"\nbefore since\n")
	since := r.commit("docs: before the chain starts")

	r.deliver("0100-demo")
	r.commit("feat: deliver 0100")
	r.deliver("0101-more")
	r.commit("feat: deliver 0101")
	r.deliver("seed-shipped")
	r.commit("feat: deliver the seed")

	// the whole branch is not one delivery, but the chain passes
	if res := r.check(r.base); res.OK() {
		t.Fatal("three deliveries and an edit passed as one pull request")
	}
	res, err := Chain(Options{Root: r.root}, since)
	if err != nil {
		t.Fatal(err)
	}
	wantOK(t, res)
	if !strings.Contains(res.Lines[0], "3 commit(s) after") {
		t.Errorf("lines: %q", res.Lines)
	}
}

func TestChainFailsOnACommitThatIsNotOneArchive(t *testing.T) {
	needOpenSpec(t)
	r := newRig(t)
	r.deliver("0100-demo")
	good := r.commit("feat: deliver 0100")
	p := "openspec/specs/demo-cap/spec.md"
	r.write(p, strings.Replace(r.read(p), "SHALL hold thing", "SHALL hold things", 1))
	bad := r.commit("docs: edit a delivered spec by hand")
	r.deliver("0101-more")
	r.commit("feat: deliver 0101")

	res, err := Chain(Options{Root: r.root}, r.base)
	if err != nil {
		t.Fatal(err)
	}
	wantFail(t, res, short(fullSHA(t, r, bad))+": step 2")
	if res.failureWith(short(fullSHA(t, r, good))) {
		t.Errorf("the good commit failed: %q", res.Failures)
	}
	if res.failureWith("step 3") || res.failureWith("step 4") {
		t.Errorf("a later delivery failed: %q", res.Failures)
	}
}

func TestChainNeedsAnAncestorAndPlainRefs(t *testing.T) {
	r := newRig(t)
	testrepo.Git(t, r.root, "checkout", "-q", "main")
	r.write("other.txt", "x")
	other := r.commit("docs: a commit off the work branch")
	testrepo.Git(t, r.root, "checkout", "-q", "work")
	if _, err := Chain(Options{Root: r.root}, other); err == nil || !strings.Contains(err.Error(), "not an ancestor") {
		t.Errorf("err = %v", err)
	}
	for _, since := range []string{"", "--all", "no-such-commit"} {
		if _, err := Chain(Options{Root: r.root}, since); err == nil {
			t.Errorf("since %q was accepted", since)
		}
	}
}

func fullSHA(t *testing.T, r *rig, short string) string {
	t.Helper()
	return strings.TrimSpace(testrepo.Git(t, r.root, "rev-parse", short))
}
