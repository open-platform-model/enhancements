package specsrule

import (
	"fmt"
	"strings"
)

// Chain is the mode for the migration branch, which delivers about ten seeds
// and entries in one pull request, so step 2 would fail it. Every commit
// after `since` that touches openspec/specs/ is checked on its own against its
// parent, in commit order: it must be one archive, and its specs/ must equal
// the replay of that archive. A merge commit brings no archive of its own: it
// passes when its openspec/specs/ equals the clean merge of its two parents
// (the commits it brings are checked on their own), and fails when it carries
// an edit of specs/ that no parent has, such as a hand-resolved conflict.
func Chain(opts Options, since string) (*Result, error) {
	opts.defaults()
	if since == "" {
		return nil, fmt.Errorf("chain mode needs a commit to start after (--since)")
	}
	if err := checkRef("since", since); err != nil {
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
	start, err := c.gitString("rev-parse", "--verify", since+"^{commit}")
	if err != nil {
		return nil, fmt.Errorf("cannot resolve %s (a shallow clone lacks it; check out the full history): %w", since, err)
	}
	if _, err := c.git("merge-base", "--is-ancestor", start, head); err != nil {
		return nil, fmt.Errorf("%s is not an ancestor of %s", since, opts.Head)
	}
	list, err := c.gitString("rev-list", "--reverse", "--topo-order", "--no-merges", start+".."+head, "--", specsDir)
	if err != nil {
		return nil, err
	}
	var commits []string
	if list != "" {
		commits = strings.Split(list, "\n")
	}
	merges, err := c.gitString("rev-list", "--reverse", "--topo-order", "--merges", start+".."+head)
	if err != nil {
		return nil, err
	}
	var mergeCommits []string
	if merges != "" {
		mergeCommits = strings.Split(merges, "\n")
	}
	c.res.logf("specs-rule --chain: %d commit(s) after %s touch %s; %d merge commit(s) to compare", len(commits), short(start), specsDir, len(mergeCommits))
	for _, m := range mergeCommits {
		if err := c.checkMerge(m); err != nil {
			return nil, fmt.Errorf("merge commit %s: %w", short(m), err)
		}
	}
	for _, commit := range commits {
		sub := &checker{opts: opts, res: &Result{}}
		if err := sub.run(commit+"^", commit); err != nil {
			return nil, fmt.Errorf("commit %s: %w", short(commit), err)
		}
		for _, l := range sub.res.Lines {
			c.res.logf("%s: %s", short(commit), l)
		}
		for _, f := range sub.res.Failures {
			c.res.failf("%s: %s", short(commit), f)
		}
	}
	return c.res, nil
}

// checkMerge compares openspec/specs/ of a merge commit with that of the merge
// of its parents that git computes on its own. A difference means the merge
// commit carries an edit of specs/ that came from no archive. A conflict
// outside specs/ does not matter: only the specs/ subtree is compared.
func (c *checker) checkMerge(commit string) error {
	parents, err := c.gitString("rev-list", "--parents", "-n", "1", commit)
	if err != nil {
		return err
	}
	f := strings.Fields(parents)[1:]
	if len(f) < 2 {
		return fmt.Errorf("%s has %d parents, not a merge", commit, len(f))
	}
	if len(f) > 2 {
		c.res.failf("%s: an octopus merge cannot be compared; merge two parents at a time", short(commit))
		return nil
	}
	// A conflict makes merge-tree exit 1 but still print the tree on the
	// first line, with the conflict markers in the conflicted files.
	out, err := c.gitAllowFail("merge-tree", "--write-tree", f[0], f[1])
	if err != nil {
		return err
	}
	tree := strings.TrimSpace(strings.SplitN(string(out), "\n", 2)[0])
	if tree == "" {
		return fmt.Errorf("git merge-tree printed no tree")
	}
	want, err := c.specsTree(tree)
	if err != nil {
		return err
	}
	got, err := c.specsTree(commit)
	if err != nil {
		return err
	}
	if want != got {
		c.res.failf("%s: merge commit: %s differs from the merge of its parents; a merge may not change specs/", short(commit), specsDir)
		return nil
	}
	c.res.logf("%s: merge commit: %s equals the merge of its parents: pass", short(commit), specsDir)
	return nil
}

// specsTree returns the object name of openspec/specs/ in a commit or tree, or
// "" when it has none.
func (c *checker) specsTree(rev string) (string, error) {
	out, err := c.git("ls-tree", rev, "--", specsDir)
	if err != nil {
		return "", err
	}
	f := strings.Fields(string(out))
	if len(f) < 3 {
		return "", nil
	}
	return f[2], nil
}
