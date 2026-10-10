package specsrule

import (
	"fmt"
	"strings"
)

// Chain is the mode for the migration branch, which delivers about ten seeds
// and entries in one pull request, so step 2 would fail it. Every commit
// after `since` that touches openspec/specs/ is checked on its own against its
// parent, in commit order: it must be one archive, and its specs/ must equal
// the replay of that archive. A merge commit is skipped; the commits it brings
// are checked on their own.
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
	c.res.logf("specs-rule --chain: %d commit(s) after %s touch %s", len(commits), short(start), specsDir)
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
