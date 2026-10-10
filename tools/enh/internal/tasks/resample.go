package tasks

import (
	"fmt"
	"path"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/record"
	"github.com/open-platform-model/enhancements/tools/enh/internal/stale"
)

// accepted splits the accepted field into its date and commit.
func accepted(en *entry.Entry) (date, commit string, ok bool) {
	f := strings.Fields(en.Config.Accepted)
	if len(f) != 2 {
		return "", "", false
	}
	return f[0], f[1], true
}

// Resample is the re-sample task for an accepted entry (design part one,
// "Edits while accepted"). A plain run prints the stale-base flags with both
// texts, then every requirement that differs from the entry text on the main
// commit that last wrote accepted:, each with its three nearest requirements.
// It never refuses on a flag. With Env.Confirm it rewrites accepted:, which is
// the reconciliation.
func (e *Env) Resample(key string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en, err := live(st, key)
	if err != nil {
		return err
	}
	if en.Kind == entry.Seed {
		return usage("%s is a seed: a seed is sampled again with `enh accept %s`", en.Base, en.Base)
	}
	if en.Config.Status != "accepted" {
		return refuse("%s has status %q; resample takes an accepted entry", en.Base, en.Config.Status)
	}
	_, old, ok := accepted(en)
	if !ok {
		return refuse("%s: accepted %q must read \"<date> <commit>\"", en.Base, en.Config.Accepted)
	}
	g := e.git()
	if !g.HasCommit(old) {
		return fmt.Errorf("the accepted commit %s of %s is not in this repository", old, en.Base)
	}
	commit, err := g.MergeBase(e.base())
	if err != nil {
		return err
	}
	if e.Confirm {
		return e.confirmResample(st, en, commit)
	}

	e.printf("resample %s  (accepted %q; base: %s %s)\n", en.Folder, en.Config.Accepted, e.base(), commit)
	flags, err := stale.Check(en.Specs, stale.Then(g, old), stale.Now(st.Specs))
	if err != nil {
		return err
	}
	e.printStale(old, flags)

	if err := e.printEdited(st, en); err != nil {
		return err
	}
	if err := e.writeMarker("resample", en, commit, nil); err != nil {
		return err
	}
	e.printf("\nThe human reviews these requirements and edits the entry where it no longer fits specs/.\n")
	e.printf("Then `CONFIRM=1 enh resample %s` (or --confirm) rewrites accepted:. It does not refuse on a flag.\n", en.Base)
	return nil
}

// printStale prints each flag with both texts.
func (e *Env) printStale(commit string, flags []stale.Flag) {
	if len(flags) == 0 {
		e.printf("\nstale base (against the accepted commit %s): 0 flags\n", commit)
		return
	}
	e.printf("\nstale base (against the accepted commit %s): %d flags\n", commit, len(flags))
	for _, f := range flags {
		e.printf("  %s / %s   %s  (%s)\n", f.Capability, f.Name, strings.ToUpper(f.Op), f.Reason())
		e.printf("    at %s:\n%s\n", commit, indent(textOrNone(f.Then, f.ThenMissing), "      "))
		e.printf("    now:\n%s\n", indent(textOrNone(f.Now, f.NowMissing), "      "))
	}
}

func textOrNone(s string, missing bool) string {
	if missing {
		return "(not present)"
	}
	return s
}

func indent(s, pad string) string {
	lines := strings.Split(strings.TrimRight(s, "\n"), "\n")
	for i, l := range lines {
		lines[i] = pad + l
	}
	return strings.Join(lines, "\n")
}

// printEdited lists the requirements that differ from the entry on the main
// commit that last wrote accepted:, each with its nearest requirements.
func (e *Env) printEdited(st *entry.Store, en *entry.Entry) error {
	g := e.git()
	cfg := e.rel(en) + "/config.yaml"
	writer, err := g.LastWriter(e.base(), `^accepted:`, cfg)
	if err != nil {
		return err
	}
	if writer == "" {
		e.printf("\nNo commit on %s wrote accepted: for %s, so there is no earlier entry text to compare with.\n", e.base(), en.Base)
		return nil
	}
	before, err := e.entryAt(writer, e.rel(en))
	if err != nil {
		return err
	}
	old := map[string]string{}
	for _, sp := range before {
		for _, r := range sp.Requirements {
			old[sp.Capability+"/"+delta.NormalizeName(r.Name)] = stale.Normalize(r.Raw)
		}
	}
	e.printf("\nedited since the main commit that last wrote accepted: (%s)\n", writer)
	uni, skip := universe(st), skipTargets(en)
	n := 0
	seen := map[string]bool{}
	for _, sp := range en.Specs {
		for _, r := range sp.Requirements {
			id := sp.Capability + "/" + delta.NormalizeName(r.Name)
			seen[id] = true
			prev, had := old[id]
			if had && prev == stale.Normalize(r.Raw) {
				continue
			}
			n++
			tag := "EDITED"
			if !had {
				tag = "NEW"
			}
			c := capReq{sp.Capability, r}
			e.showReq(string(r.Op)+" "+tag, c)
			if r.Op != delta.Removed {
				e.printf("nearest in specs/ (3):\n")
				e.printNearest(c.req(), uni, skip, false)
			}
		}
	}
	for id := range old {
		if !seen[id] {
			n++
			e.printf("\n[DROPPED] %s  (in the entry at %s, not in the entry now)\n", id, writer)
		}
	}
	if n == 0 {
		e.printf("  no requirement differs\n")
	}
	return nil
}

// entryAt reads the delta specs of the entry folder at a commit.
func (e *Env) entryAt(commit, folder string) ([]*delta.Spec, error) {
	g := e.git()
	files, err := g.Files(commit, folder+"/specs")
	if err != nil {
		return nil, err
	}
	var out []*delta.Spec
	for _, f := range files {
		if path.Base(f) != "spec.md" {
			continue
		}
		b, err := g.Show(commit, f)
		if err != nil {
			return nil, err
		}
		out = append(out, delta.Parse(f, path.Base(path.Dir(f)), b))
	}
	return out, nil
}

func (e *Env) confirmResample(st *entry.Store, en *entry.Entry, commit string) error {
	if err := e.needMarker("resample", en, commit); err != nil {
		return err
	}
	value := fmt.Sprintf("%s %s", e.today(), commit)
	if _, err := e.editConfig(en, record.Edit{Key: "accepted", Block: "accepted: " + record.Quote(value)}); err != nil {
		return err
	}
	e.printf("wrote to %s/config.yaml:  accepted: %q\n", e.rel(en), value)
	flags, err := stale.Check(en.Specs, stale.Then(e.git(), commit), stale.Now(st.Specs))
	if err != nil {
		return err
	}
	e.printf("stale base against %s: %d flags\n", commit, len(flags))
	return e.indexAfter()
}
