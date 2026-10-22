package tasks

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
	"github.com/open-platform-model/enhancements/tools/enh/internal/record"
	"github.com/open-platform-model/enhancements/tools/enh/internal/sample"
	"github.com/open-platform-model/enhancements/tools/enh/internal/shipped"
	"github.com/open-platform-model/enhancements/tools/enh/internal/vet"
	"os"
)

// Accept is the accept task for a draft entry, a seed or a correction. A plain run checks
// the entry in accept mode and prints the sample, the collision list and the
// blocking questions; it prints the sample and the list even when the checker
// refuses. With Env.Confirm it writes the record after a plain run on the
// same commit: status and accepted for an entry, the sampled line for a seed
// or a correction.
func (e *Env) Accept(key string) error {
	st, err := e.load()
	if err != nil {
		return err
	}
	en, err := live(st, key)
	if err != nil {
		return err
	}
	unnumbered := en.Kind.Unnumbered()
	if !unnumbered && en.Config.Status != "draft" {
		return refuse("%s has status %q; accept takes a draft (an accepted entry is re-sampled with `enh resample`)", en.Base, en.Config.Status)
	}
	commit, err := e.git().MergeBase(e.base())
	if err != nil {
		return err
	}
	if e.Confirm {
		return e.confirmAccept(en, commit, unnumbered)
	}

	e.printf("accept %s  (mode accept; base: %s %s)\n", en.Folder, e.base(), commit)
	res, err := e.vet(vet.Accept, en.Folder)
	if err != nil {
		return err
	}
	refused := e.printFindings(vet.Accept, res)
	if refused {
		e.printf("\nrefused: fix the errors first\n")
	}
	e.blockingQuestions(en)

	s, err := e.seedFor()
	if err != nil {
		return err
	}
	switch en.Kind {
	case entry.Seed:
		e.seedSample(en, s)
	case entry.Correction:
		e.correctionSample(st, en)
	default:
		e.entrySample(st, en, s)
	}
	if err := e.writeMarker("accept", en, commit, &s); err != nil {
		return err
	}
	if refused {
		return refuse("accept refused: %d errors", res.Errors())
	}
	what := "writes status: accepted and accepted:"
	if unnumbered {
		what = "writes the sampled: line of source.md"
	}
	e.printf("\nThe human decides on the sample and the list. Then `CONFIRM=1 enh accept %s` (or --confirm) %s.\n", en.Base, what)
	return nil
}

func (e *Env) blockingQuestions(en *entry.Entry) {
	var blocking []entry.Question
	for _, q := range en.Questions {
		if q.Kind == "blocking" {
			blocking = append(blocking, q)
		}
	}
	if len(blocking) == 0 {
		e.printf("\nBlocking questions: none\n")
		return
	}
	e.printf("\nBlocking questions (%d):\n", len(blocking))
	for _, q := range blocking {
		e.printf("  - %s\n", q.Text)
	}
}

// entrySample prints step 6 and step 8 of the accept checklist.
func (e *Env) entrySample(st *entry.Store, en *entry.Entry, seed uint64) {
	modified, removed, added := opReqs(en, delta.Modified), opReqs(en, delta.Removed), opReqs(en, delta.Added)
	if len(modified)+len(removed)+len(added) == 0 {
		e.printf("\nSample: this entry has no requirement, so it has no sample. Read the proposal and the design instead.\n")
		return
	}
	k := sample.Count(len(added))
	e.printf("\nSample. Every MODIFIED (%d) and REMOVED (%d) requirement is shown, because it changes shipped behaviour.\n", len(modified), len(removed))
	e.printf("Of %d ADDED requirements, %d are drawn at random: max(3, 10 percent), rounded up, all if fewer than 3.\n", len(added), k)
	e.printf("Random seed: %d (repeat the draw with --seed %d)\n", seed, seed)
	e.printf("Say for each: fine, or refine (unclear, wrong, problematic).\n")
	for _, c := range modified {
		e.showReq("MODIFIED", c)
	}
	for _, c := range removed {
		e.showReq("REMOVED", c)
	}
	for _, i := range sample.Draw(len(added), k, seed) {
		e.showReq("ADDED", added[i])
	}
	if len(added) == 0 {
		return
	}
	e.printf("\nCollision review. %s\n", sample.Metric)
	e.printf("The list skips the requirements this entry removes or modifies, and the requirement itself. Nothing is recorded.\n")
	uni, skip := universe(st), skipTargets(en)
	for _, c := range added {
		e.printNearest(c.req(), uni, skip, true)
	}
}

// seedSample prints the sample of a seed: ADDED requirements only.
func (e *Env) seedSample(en *entry.Entry, seed uint64) {
	added := opReqs(en, delta.Added)
	if len(added) == 0 {
		e.printf("\nSample: this seed has no ADDED requirement.\n")
		return
	}
	k := sample.Count(len(added))
	e.printf("\nSample: %d of %d ADDED requirements, drawn at random: max(3, 10 percent), rounded up, all if fewer than 3.\n", k, len(added))
	e.printf("Random seed: %d (repeat the draw with --seed %d)\n", seed, seed)
	e.printf("Say for each: fine, or refine.\n")
	for _, i := range sample.Draw(len(added), k, seed) {
		e.showReq("ADDED", added[i])
	}
}

// correctionSample prints the sample of a correction: every requirement block,
// not a draw, because each block rewrites shipped behaviour. Each block shows
// the main text it replaces, the new text and its row of shipped evidence. An
// ADDED block that replaces nothing is flagged: it must be a recorded fact.
func (e *Env) correctionSample(st *entry.Store, en *entry.Entry) {
	rows, _ := shipped.Parse(en.Source.Text)
	byKey := map[string]shipped.Row{}
	for _, r := range rows {
		byKey[r.Key()] = r
	}
	replaced := shipped.Replacements(en.Specs)
	modified, removed, added := opReqs(en, delta.Modified), opReqs(en, delta.Removed), opReqs(en, delta.Added)
	var renames []capRename
	for _, sp := range en.Specs {
		for _, rn := range sp.Renames {
			renames = append(renames, capRename{sp.Capability, rn})
		}
	}
	n := len(modified) + len(removed) + len(added) + len(renames)
	if n == 0 {
		e.printf("\nSample: this correction has no requirement block.\n")
		return
	}
	e.printf("\nSample. Every requirement block is shown (%d: %d MODIFIED, %d REMOVED, %d RENAMED, %d ADDED), beside the text it replaces and its evidence.\n",
		n, len(modified), len(removed), len(renames), len(added))
	e.printf("A correction states behaviour that ships today and adds none. Say for each: fine, or refine (unclear, wrong, problematic, or not shipped).\n")
	evidence := func(capability, name, op string) {
		r, ok := byKey[capability+"\x00"+name+"\x00"+op]
		if !ok {
			e.printf("    shipped by: no row in source.md\n")
			return
		}
		e.printf("    shipped by: %s\n    code read:  %s\n", r.By, orNone(r.Code))
	}
	main := func(capability, name string) {
		if sp := st.Specs[capability]; sp != nil {
			for _, q := range sp.By(delta.Main) {
				if delta.NormalizeName(q.Name) == delta.NormalizeName(name) {
					e.printf("  main requirement now:\n%s\n", padBlock(block(q)))
					return
				}
			}
		}
		e.printf("  main requirement now: none\n")
	}
	for _, c := range modified {
		e.printf("\n[MODIFIED] %s/%s\n", c.Capability, delta.NormalizeName(c.Name))
		main(c.Capability, c.Name)
		e.printf("  correction:\n%s\n", padBlock(block(c.Requirement)))
		evidence(c.Capability, delta.NormalizeName(c.Name), "MODIFIED")
	}
	for _, c := range removed {
		e.printf("\n[REMOVED] %s/%s\n", c.Capability, delta.NormalizeName(c.Name))
		main(c.Capability, c.Name)
		e.printf("  correction:\n%s\n", padBlock(block(c.Requirement)))
		evidence(c.Capability, delta.NormalizeName(c.Name), "REMOVED")
	}
	for _, c := range renames {
		e.printf("\n[RENAMED] %s: %q to %q\n", c.capability, delta.NormalizeName(c.From), delta.NormalizeName(c.To))
		main(c.capability, c.From)
		evidence(c.capability, delta.NormalizeName(c.To), "RENAMED")
	}
	uni, skip := universe(st), skipTargets(en)
	for _, c := range added {
		e.printf("\n[ADDED] %s/%s\n", c.Capability, delta.NormalizeName(c.Name))
		e.printf("  correction:\n%s\n", padBlock(block(c.Requirement)))
		evidence(c.Capability, delta.NormalizeName(c.Name), "ADDED")
		if !replaced[c.Capability+"\x00"+delta.NormalizeName(c.Name)] {
			e.printf("  NEW REQUIREMENT, NOT A RENAME: confirm it states behaviour that already ships.\n  Nearest requirements:\n")
			e.printNearest(c.req(), uni, skip, false)
		}
	}
}

// padBlock puts four spaces before each non-empty line of a block.
func padBlock(s string) string {
	lines := strings.Split(s, "\n")
	for i, l := range lines {
		if strings.TrimSpace(l) != "" {
			lines[i] = "    " + l
		}
	}
	return strings.Join(lines, "\n")
}

// capRename is a RENAMED pair with its capability.
type capRename struct {
	capability string
	delta.Rename
}

func orNone(s string) string {
	if strings.TrimSpace(s) == "" {
		return "none"
	}
	return s
}

func (e *Env) confirmAccept(en *entry.Entry, commit string, unnumbered bool) error {
	if err := e.needMarker("accept", en, commit); err != nil {
		return err
	}
	res, err := e.vet(vet.Accept, en.Folder)
	if err != nil {
		return err
	}
	if res.HasErrors() {
		e.printFindings(vet.Accept, res)
		return refuse("accept refused: %d errors; fix them and run the plain command again", res.Errors())
	}
	value := fmt.Sprintf("%s %s", e.today(), commit)
	if unnumbered {
		path := filepath.Join(en.Dir, "source.md")
		old, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if err := record.WriteFile(path, []byte(record.SetSampled(string(old), value))); err != nil {
			return err
		}
		e.printf("wrote to %s/source.md:  sampled: %s\n", e.rel(en), value)
		return nil
	}
	if _, err := e.editConfig(en,
		record.Edit{Key: "status", Block: "status: accepted"},
		record.Edit{Key: "accepted", Block: "accepted: " + record.Quote(value)},
	); err != nil {
		return err
	}
	e.printf("wrote to %s/config.yaml:  status: accepted  accepted: %q\n", e.rel(en), value)
	return e.indexAfter()
}

// indexAfter runs index after a write and reports its failure without hiding
// that the write happened.
func (e *Env) indexAfter() error {
	changed, err := e.Index()
	if err != nil {
		return fmt.Errorf("the record is written, but enh index failed (fix it and run `enh index`): %w", err)
	}
	e.printIndex(changed)
	return nil
}
