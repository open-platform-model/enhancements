// Package specsrule is the CI rule for openspec/specs/ (design part two,
// section 4.3): a change that touches specs/ must be one delivery, one seed or
// a Purpose correction, and its specs/ must equal what OpenSpec produces.
//
// The rule reads git history and replays the archive with the pinned OpenSpec
// CLI in a scratch copy. It never writes in the repository.
package specsrule

import (
	"fmt"
	"os"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"

	"github.com/open-platform-model/enhancements/tools/enh/internal/sys"
)

// PinnedOpenSpec is the OpenSpec CLI version the replay needs (N20, DECISIONS.md
// 2026-10-10 19:50). The replay refuses another version, since a different
// archive would give different specs.
const PinnedOpenSpec = "1.14.1"

const (
	specsDir   = "openspec/specs"
	changesDir = "openspec/changes"
	archiveDir = "openspec/changes/archive"
)

var (
	zeroRe      = regexp.MustCompile(`^0+$`)
	datedRe     = regexp.MustCompile(`^(\d{4}-\d{2}-\d{2})-(.+)$`)
	undatedRe   = regexp.MustCompile(`^(\d{4}-[a-z0-9][a-z0-9-]*|seed-[a-z0-9][a-z0-9-]*)$`)
	specFileRe  = regexp.MustCompile(`^openspec/specs/[^/]+/spec\.md$`)
	refRe       = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._/@{}~^-]*$`)
	maxDiffRows = 10
)

// Options configure one check.
type Options struct {
	// Root is the top level of the repository.
	Root string
	// Base is the base ref of the pull request. An all-zero object name (the
	// "before" of a first push) means the first parent of Head.
	Base string
	// Head is the commit to check; default HEAD.
	Head string
	// OpenSpec runs the openspec CLI; default sys.Exec.
	OpenSpec sys.Runner
	// OpenSpecVersion is the version the replay needs; default PinnedOpenSpec.
	OpenSpecVersion string
	// TempDir is where the scratch copy goes; default the system temp folder.
	TempDir string
}

// Result is the outcome of a check: a log of the steps and the failures.
type Result struct {
	Lines    []string
	Failures []string
}

// OK reports whether no step failed.
func (r *Result) OK() bool { return len(r.Failures) == 0 }

func (r *Result) logf(format string, args ...any) {
	r.Lines = append(r.Lines, fmt.Sprintf(format, args...))
}

func (r *Result) failf(format string, args ...any) {
	r.Failures = append(r.Failures, fmt.Sprintf(format, args...))
}

type checker struct {
	opts Options
	res  *Result
}

func (o *Options) defaults() {
	if o.Head == "" {
		o.Head = "HEAD"
	}
	if o.OpenSpec == nil {
		o.OpenSpec = sys.Exec
	}
	if o.OpenSpecVersion == "" {
		o.OpenSpecVersion = PinnedOpenSpec
	}
}

func checkRef(kind, ref string) error {
	if !refRe.MatchString(ref) {
		return fmt.Errorf("%s ref %q is not a plain ref name", kind, ref)
	}
	return nil
}

// Check runs the four steps for one pull request: the changes between the
// merge base of Base and Head, and Head.
func Check(opts Options) (*Result, error) {
	opts.defaults()
	if opts.Base == "" {
		return nil, fmt.Errorf("specs-rule needs a base ref (--base)")
	}
	if err := checkRef("base", opts.Base); err != nil {
		return nil, err
	}
	if err := checkRef("head", opts.Head); err != nil {
		return nil, err
	}
	c := &checker{opts: opts, res: &Result{}}
	if err := c.requireTopLevel(); err != nil {
		return nil, err
	}
	head, err := c.gitString("rev-parse", "--verify", opts.Head+"^{commit}")
	if err != nil {
		return nil, fmt.Errorf("cannot resolve head %s: %w", opts.Head, err)
	}
	base := opts.Base
	if zeroRe.MatchString(base) {
		base = head + "^"
	}
	mb, err := c.gitString("merge-base", base, head)
	if err != nil {
		return nil, fmt.Errorf("no merge base of %s and %s (a shallow clone lacks it; check out the full history): %w", opts.Base, opts.Head, err)
	}
	c.res.logf("specs-rule: merge base %s, head %s", short(mb), short(head))
	if err := c.run(mb, head); err != nil {
		return nil, err
	}
	return c.res, nil
}

// requireTopLevel refuses a Root below the top level of its repository: the
// paths of the rule are relative to the top level.
func (c *checker) requireTopLevel() error {
	prefix, err := c.gitString("rev-parse", "--show-prefix")
	if err != nil {
		return fmt.Errorf("%s is not inside a git repository: %w", c.opts.Root, err)
	}
	if prefix != "" {
		return fmt.Errorf("%s is %q below the top level of its repository: run specs-rule at the top level", c.opts.Root, prefix)
	}
	return nil
}

func short(s string) string {
	if len(s) > 10 {
		return s[:10]
	}
	return s
}

// run is steps 1 to 4 between two commits.
func (c *checker) run(mb, head string) error {
	changes, err := c.diff(mb, head, specsDir)
	if err != nil {
		return err
	}
	if len(changes) == 0 {
		c.res.logf("step 1: no path under %s changed: pass", specsDir)
		return nil
	}
	pure, err := c.purposeOnly(mb, head, changes)
	if err != nil {
		return err
	}
	if pure {
		c.res.logf("step 1: %d spec file(s) changed in their ## Purpose text only: pass (the Purpose exception)", len(changes))
		return nil
	}
	c.res.logf("step 1: %d path(s) under %s changed", len(changes), specsDir)

	name, dated, err := c.oneDelivery(mb, head)
	if err != nil {
		return err
	}
	if name == "" {
		return nil // the failure is recorded
	}
	c.res.logf("step 2: one archived folder %s, delivered or seed, undated folder %s present at the base and gone at head", dated, name)
	return c.replay(mb, head, name, dated)
}

// purposeOnly reports whether every changed path is a modified spec.md whose
// text differs only inside ## Purpose.
func (c *checker) purposeOnly(mb, head string, changes []change) (bool, error) {
	for _, ch := range changes {
		if ch.Status != 'M' || !specFileRe.MatchString(ch.Path) {
			return false, nil
		}
		old, err := c.show(mb, ch.Path)
		if err != nil {
			return false, err
		}
		now, err := c.show(head, ch.Path)
		if err != nil {
			return false, err
		}
		if withoutPurpose(string(old)) != withoutPurpose(string(now)) {
			return false, nil
		}
	}
	return true, nil
}

// oneDelivery is step 2. It returns the undated and dated folder names, or an
// empty name after it recorded a failure.
func (c *checker) oneDelivery(mb, head string) (name, dated string, err error) {
	changes, err := c.diff(mb, head, archiveDir)
	if err != nil {
		return "", "", err
	}
	added := map[string]bool{}
	var order []string
	for _, ch := range changes {
		if ch.Status != 'A' {
			continue
		}
		rest := strings.TrimPrefix(ch.Path, archiveDir+"/")
		folder, inside, _ := strings.Cut(rest, "/")
		if inside == "" {
			continue // a file beside the folders, such as .gitkeep, is no delivery
		}
		if !added[folder] {
			added[folder] = true
			order = append(order, folder)
		}
	}
	if len(order) != 1 {
		c.res.failf("step 2: a change to %s must add exactly one folder under %s; found %d (%s)", specsDir, archiveDir, len(order), strings.Join(order, ", "))
		return "", "", nil
	}
	dated = order[0]
	m := datedRe.FindStringSubmatch(dated)
	if m == nil || !undatedRe.MatchString(m[2]) {
		c.res.failf("step 2: archived folder %q must be <date>-<id>-<slug> or <date>-seed-<capability>", dated)
		return "", "", nil
	}
	name = m[2]
	atBase, err := c.exists(mb, changesDir+"/"+name)
	if err != nil {
		return "", "", err
	}
	if !atBase {
		c.res.failf("step 2: %s/%s does not exist at the merge base: the delivery did not start from a change in changes/", changesDir, name)
		return "", "", nil
	}
	atHead, err := c.exists(head, changesDir+"/"+name)
	if err != nil {
		return "", "", err
	}
	if atHead {
		c.res.failf("step 2: %s/%s still exists at head: archiving moves the folder", changesDir, name)
		return "", "", nil
	}
	kind, err := c.deliveredOrSeed(head, archiveDir+"/"+dated)
	if err != nil {
		return "", "", err
	}
	if kind != "" {
		c.res.failf("step 2: %s: %s", dated, kind)
		return "", "", nil
	}
	return name, dated, nil
}

// deliveredOrSeed returns "" when the archived folder is a seed or an entry
// with status delivered, else the reason it is neither.
func (c *checker) deliveredOrSeed(head, folder string) (string, error) {
	if b, err := c.show(head, folder+"/.openspec.yaml"); err == nil {
		var meta struct {
			Schema string `yaml:"schema"`
		}
		if yaml.Unmarshal(b, &meta) == nil && meta.Schema == "seed" {
			return "", nil
		}
	}
	b, err := c.show(head, folder+"/config.yaml")
	if err != nil {
		return "neither a seed (.openspec.yaml schema: seed) nor an entry with a config.yaml", nil
	}
	var cfg struct {
		Status string `yaml:"status"`
	}
	if err := yaml.Unmarshal(b, &cfg); err != nil {
		return "", fmt.Errorf("%s/config.yaml: %w", folder, err)
	}
	if cfg.Status != "delivered" {
		return fmt.Sprintf("status is %q, not delivered: only a delivery or a seed changes specs/", cfg.Status), nil
	}
	return "", nil
}

// replay is step 3 and step 4.
func (c *checker) replay(mb, head, name, dated string) error {
	scratch, err := os.MkdirTemp(c.opts.TempDir, "specs-rule-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(scratch) // a scratch copy; nothing to report if removal fails

	if err := c.checkVersion(scratch); err != nil {
		return err
	}
	base, err := c.archiveTree(mb, "openspec")
	if err != nil {
		return err
	}
	if err := writeTree(base, scratch, func(n string) (string, bool) {
		return n, !strings.HasPrefix(n, changesDir+"/"+name+"/")
	}); err != nil {
		return err
	}
	folder, err := c.archiveTree(head, archiveDir+"/"+dated)
	if err != nil {
		return err
	}
	prefix := archiveDir + "/" + dated + "/"
	if err := writeTree(folder, scratch, func(n string) (string, bool) {
		rest, ok := strings.CutPrefix(n, prefix)
		return changesDir + "/" + name + "/" + rest, ok
	}); err != nil {
		return err
	}
	out, err := c.opts.OpenSpec(scratch, "openspec", "archive", name, "--yes")
	if err != nil {
		c.res.failf("step 3: openspec archive %s --yes failed in the scratch copy: %v: %s", name, err, firstLines(string(out), 3))
		return nil
	}
	c.res.logf("step 3: replayed `openspec archive %s --yes` (OpenSpec %s) on the merge base in a scratch copy", name, c.opts.OpenSpecVersion)

	diffs, err := c.compareSpecs(scratch, head)
	if err != nil {
		return err
	}
	if len(diffs) == 0 {
		c.res.logf("step 4: %s equals the replay byte for byte: pass", specsDir)
		return nil
	}
	for i, d := range diffs {
		if i == maxDiffRows {
			c.res.failf("step 4: %d more difference(s) not listed", len(diffs)-maxDiffRows)
			break
		}
		c.res.failf("step 4: %s", d)
	}
	return nil
}

func (c *checker) checkVersion(scratch string) error {
	out, err := c.opts.OpenSpec(scratch, "openspec", "--version")
	if err != nil {
		return fmt.Errorf("openspec --version: %w: %s", err, firstLines(string(out), 1))
	}
	got := strings.TrimSpace(string(out))
	if got != c.opts.OpenSpecVersion {
		return fmt.Errorf("the replay needs OpenSpec %s, found %q: install the pinned version", c.opts.OpenSpecVersion, got)
	}
	return nil
}

func firstLines(s string, n int) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	if len(lines) > n {
		lines = lines[:n]
	}
	return strings.Join(lines, " | ")
}
