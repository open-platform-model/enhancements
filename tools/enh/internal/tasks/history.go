package tasks

import (
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/history"
	"github.com/open-platform-model/enhancements/tools/enh/internal/stale"
)

// History prints the history of the requirement req, optionally limited to
// one capability, from the archived delta specs. It returns a UsageError when
// no archived delta names the requirement.
func (e *Env) History(req, capability string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	var srcs []history.Source
	for _, en := range st.Archived {
		label := en.FolderID
		if en.Kind.Unnumbered() {
			label = en.Base
		}
		srcs = append(srcs, history.Source{Folder: en.Folder, Date: en.Date, Label: label, Status: en.Config.Status, Specs: en.Specs})
	}
	order, _ := e.git().ArchiveOrder() // no git history: ties break by folder name
	chains, err := history.Query(srcs, req, capability, order)
	if err != nil {
		return usage("%v", err)
	}
	history.Format(e.Out, chains)
	return nil
}

// Stale prints the stale-base flags of an accepted entry, each with both
// texts, and returns a Refusal when there is one.
func (e *Env) Stale(key string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en, err := live(st, key)
	if err != nil {
		return err
	}
	var commit string
	var ok bool
	rerun := "resample " + en.FolderID
	switch {
	case en.Kind == entry.Correction:
		rerun = "accept " + en.Base
		if commit, ok = sampledCommit(en); !ok {
			return refuse("%s has no sampled: line; the stale base is checked once it is sampled", en.Base)
		}
	case en.Kind == entry.Seed || en.Config.Status != "accepted":
		return refuse("%s has status %q; the stale base is checked on an accepted entry", en.Base, en.Config.Status)
	default:
		if _, commit, ok = accepted(en); !ok {
			return refuse("%s: accepted %q must read \"<date> <commit>\"", en.Base, en.Config.Accepted)
		}
	}
	g := e.git()
	if !g.HasCommit(commit) {
		return refuse("the accepted commit %s of %s is not in this repository", commit, en.Base)
	}
	flags, err := stale.Check(en.Specs, stale.Then(g, commit), stale.Now(st.Specs))
	if err != nil {
		return err
	}
	e.printStale(commit, flags)
	if len(flags) > 0 {
		return refuse("%d stale flags: run `enh %s`", len(flags), rerun)
	}
	return nil
}
