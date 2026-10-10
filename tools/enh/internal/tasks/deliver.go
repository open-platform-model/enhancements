package tasks

import (
	"fmt"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/record"
	"github.com/open-platform-model/enhancements/tools/enh/internal/stale"
	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
)

// StaleFindings runs the stale-base check (V26) on the accepted entries that
// keys select, or on every accepted live entry when keys is empty. A flag is
// an error finding. It is the only place V26 runs: the vet package does not
// read git history.
func (e *Env) StaleFindings(st *entry.Store, keys []string) ([]vet.Finding, error) {
	var out []vet.Finding
	g := e.git()
	for _, en := range st.Live {
		if en.Kind == entry.Seed || en.Config.Status != "accepted" || !selected(en, keys) {
			continue
		}
		rel := e.rel(en) + "/config.yaml"
		_, commit, ok := accepted(en)
		if !ok {
			continue // V7 reports the shape
		}
		if !g.HasCommit(commit) {
			out = append(out, vet.Finding{Rule: "V26", Level: vet.Error, Entry: en.Folder, Path: rel,
				Msg: fmt.Sprintf("the accepted commit %s is not in this repository, so the stale base cannot be checked", commit)})
			continue
		}
		flags, err := stale.Check(en.Specs, stale.Then(g, commit), stale.Now(st.Specs))
		if err != nil {
			return nil, err
		}
		for _, f := range flags {
			out = append(out, vet.Finding{Rule: "V26", Level: vet.Error, Entry: en.Folder, Path: rel,
				Msg: fmt.Sprintf("stale base: %s / %s (%s) %s since %s; run `enh resample %s`", f.Capability, f.Name, f.Op, f.Reason(), commit, en.FolderID)})
		}
	}
	return out, nil
}

func selected(en *entry.Entry, keys []string) bool {
	if len(keys) == 0 {
		return true
	}
	for _, k := range keys {
		if k == en.Base || k == en.Folder || (en.FolderID != "" && k == en.FolderID) {
			return true
		}
	}
	return false
}

// Deliver is the deliver task: it refuses an unticked line, a stale flag and
// every error of the checker in deliver mode (V20, V21 and the rest), then
// sets status: delivered, archives the change, runs index and commits once.
// A seed skips the entry fields and needs its sampled: line.
func (e *Env) Deliver(key string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en, err := live(st, key)
	if err != nil {
		return err
	}
	seed := en.Kind == entry.Seed
	if !seed && en.Config.Status != "accepted" {
		return refuse("%s has status %q; deliver takes an accepted entry", en.Base, en.Config.Status)
	}
	if err := e.needCleanTree(); err != nil {
		return err
	}
	res, err := e.vet(vet.Deliver, en.Folder)
	if err != nil {
		return err
	}
	staleF, err := e.StaleFindings(st, []string{en.Folder})
	if err != nil {
		return err
	}
	if e.printFindings(vet.Deliver, res, staleF...) {
		return refuse("deliver refused: fix the errors above")
	}

	var undo func() error
	if !seed {
		if undo, err = e.editConfig(en, record.Edit{Key: "status", Block: "status: delivered"}); err != nil {
			return err
		}
	}
	if out, err := e.Run(e.Root, "openspec", "archive", en.Folder, "--yes"); err != nil {
		return e.failArchive(undo, "openspec archive "+en.Folder+" --yes", out, err)
	}
	e.printf("archived %s\n", en.Folder)
	if err := e.indexAfter(); err != nil {
		return err
	}
	what := "enhancement " + en.FolderID + " " + en.FolderSlug
	if seed {
		what = "seed " + en.FolderSlug
	}
	return e.commit("docs: deliver "+what, "openspec", "INDEX.md", "GRAPH.md")
}

// failArchive puts the config back after a failed archive and says what ran.
func (e *Env) failArchive(undo func() error, cmd string, out []byte, err error) error {
	msg := fmt.Errorf("%s failed: %w\n%s", cmd, err, strings.TrimSpace(string(out)))
	if undo != nil {
		if uerr := undo(); uerr != nil {
			return fmt.Errorf("%w\nand config.yaml could not be restored: %v", msg, uerr)
		}
		return fmt.Errorf("%w\nconfig.yaml was restored", msg)
	}
	return msg
}

func (e *Env) needCleanTree() error {
	if e.NoCommit {
		return nil
	}
	clean, err := e.git().Clean()
	if err != nil {
		return err
	}
	if !clean {
		return refuse("the working tree has changes: commit or stash them first, so the delivery is one commit (or pass --no-commit)")
	}
	return nil
}

// commit makes the one commit of a task, unless NoCommit is set.
func (e *Env) commit(message string, paths ...string) error {
	if e.NoCommit {
		e.printf("not committed (--no-commit): %s\n", message)
		return nil
	}
	if err := e.git().Commit(message, e.existing(paths...)...); err != nil {
		return err
	}
	e.printf("committed: %s\n", message)
	return nil
}

// Ending kinds for End.
const (
	Reject    = "reject"
	Withdraw  = "withdraw"
	Supersede = "supersede"
)

// End is reject, withdraw or supersede. It writes the record and status,
// archives with --skip-specs (and --no-validate when Env.NoValidate is set),
// runs index and commits once. by lists the successor ids of supersede.
func (e *Env) End(kind, key, reason string, by []string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en, err := live(st, key)
	if err != nil {
		return err
	}
	if en.Kind == entry.Seed {
		return refuse("%s is a seed: a seed is delivered or deleted, not %sed", en.Base, kind)
	}
	status := en.Config.Status
	if strings.TrimSpace(reason) == "" {
		return usage("%s needs a reason", kind)
	}
	if kind == Reject && status != "draft" {
		return refuse("%s has status %q; only a draft is rejected (withdraw or supersede an accepted entry)", en.Base, status)
	}
	if status != "draft" && status != "accepted" {
		return refuse("%s has status %q; only a draft or accepted entry ends this way", en.Base, status)
	}
	var edits []record.Edit
	date := e.today()
	switch kind {
	case Reject:
		edits = []record.Edit{{Key: "status", Block: "status: rejected"},
			{Key: "rejected", Block: "rejected:\n  date: " + record.Quote(date) + "\n  reason: " + record.Quote(reason)}}
	case Withdraw:
		edits = []record.Edit{{Key: "status", Block: "status: withdrawn"},
			{Key: "withdrawn", Block: "withdrawn:\n  date: " + record.Quote(date) + "\n  reason: " + record.Quote(reason)}}
	case Supersede:
		if len(by) == 0 {
			return usage("supersede needs the id of the successor")
		}
		for _, id := range by {
			if !idRe.MatchString(id) {
				return usage("successor %q must be an id of four digits", id)
			}
			if id == en.FolderID {
				return refuse("%s cannot supersede itself", en.Base)
			}
			if !successorExists(st, id) {
				return refuse("successor %s does not exist: no entry with that id", id)
			}
		}
		var b strings.Builder
		b.WriteString("superseded_by:\n  date: " + record.Quote(date) + "\n  ids:\n")
		for _, id := range by {
			b.WriteString("    - " + record.Quote(id) + "\n")
		}
		b.WriteString("  reason: " + record.Quote(reason))
		edits = []record.Edit{{Key: "status", Block: "status: superseded"}, {Key: "superseded_by", Block: b.String()}}
	default:
		return usage("unknown ending %q", kind)
	}
	if err := e.needCleanTree(); err != nil {
		return err
	}
	undo, err := e.editConfig(en, edits...)
	if err != nil {
		return err
	}
	args := []string{"archive", en.Folder, "--skip-specs", "--yes"}
	if e.NoValidate {
		args = append(args, "--no-validate")
	}
	if out, err := e.Run(e.Root, "openspec", args...); err != nil {
		return e.failArchive(undo, "openspec "+strings.Join(args, " "), out, err)
	}
	e.printf("archived %s as %s\n", en.Folder, strings.TrimSuffix(edits[0].Block[len("status: "):], "\n"))
	if err := e.indexAfter(); err != nil {
		return err
	}
	verb := map[string]string{Reject: "reject", Withdraw: "withdraw", Supersede: "supersede"}[kind]
	return e.commit("docs: "+verb+" enhancement "+en.FolderID+" "+en.FolderSlug, "openspec", "INDEX.md", "GRAPH.md")
}

// successorExists looks for an entry id in the loaded store: live, archived,
// the old archive and the old live folders.
func successorExists(st *entry.Store, id string) bool {
	for _, en := range st.All() {
		if en.Kind == entry.Enhancement && en.FolderID == id {
			return true
		}
	}
	for _, o := range st.OldArchived {
		if o == id {
			return true
		}
	}
	for _, o := range st.LegacyLive {
		if o == id {
			return true
		}
	}
	return false
}
