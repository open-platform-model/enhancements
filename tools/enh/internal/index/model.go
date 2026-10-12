package index

import (
	"fmt"
	"strings"
)

// Entry statuses of the new layout. The old layout uses the first five.
const (
	StatusDraft      = "draft"
	StatusAccepted   = "accepted"
	StatusDelivered  = "delivered"
	StatusRejected   = "rejected"
	StatusSuperseded = "superseded"
	StatusWithdrawn  = "withdrawn"
)

// Categories is the fixed display order. It must agree with #Category in
// schema.cue; a test compares the two.
var Categories = []string{"schema", "runtime", "distribution", "tooling", "misc"}

var statuses = []string{StatusDraft, StatusAccepted, StatusDelivered, StatusRejected, StatusSuperseded, StatusWithdrawn}

// Layout says where an entry came from.
type Layout int

const (
	// LayoutOpenSpec is an entry under openspec/changes/ (live or archived).
	LayoutOpenSpec Layout = iota
	// LayoutLegacy is one of the ten old-layout entries in archive/NNNN/.
	LayoutLegacy
	// LayoutLegacyLive is an old-layout entry that is still live, in NNNN/ at
	// the root, read from its config.yaml. It is listed in INDEX.md and
	// GRAPH.md until migration step M4, and has no generated README.
	LayoutLegacyLive
)

// Ending is the record of a rejection or a withdrawal.
type Ending struct {
	Date   string
	Reason string
}

// Superseded is the record of a supersession. An old-layout entry holds one
// successor and no date or reason of its own.
type Superseded struct {
	Date   string
	IDs    []string
	Reason string
}

// Entry is one enhancement as the generators see it.
type Entry struct {
	ID       string
	Slug     string
	Title    string
	Summary  string
	Status   string
	Category string
	Affects  []string
	Created  string
	// Breaking is nil while unset (a draft may leave it unset).
	Breaking *bool
	After    []string
	// Accepted is "<date> <commit>"; empty when absent.
	Accepted   string
	Rejected   *Ending
	Withdrawn  *Ending
	Superseded *Superseded
	// RejectedReason is the old layout's single string.
	RejectedReason string

	Layout Layout
	// Dir is the folder relative to the repo root, with forward slashes and no
	// trailing slash.
	Dir string
	// ArchiveDate is the YYYY-MM-DD prefix of an archived new-layout folder.
	ArchiveDate string

	Tasks         []Section
	ProposalWords int
	DesignWords   int
	HasSpecs      bool
	HasEvidence   bool

	// LandedOn and Landings come from the delivery.yaml of an old-layout entry.
	LandedOn string
	Landings int
}

// Closed reports whether the entry has ended: delivered, rejected, superseded
// or withdrawn.
func (e *Entry) Closed() bool {
	switch e.Status {
	case StatusDelivered, StatusRejected, StatusSuperseded, StatusWithdrawn:
		return true
	}
	return false
}

// Section is one `## n. Theme` block of tasks.md.
type Section struct {
	Title string
	Tasks []Task
}

// Task is one line of tasks.md.
type Task struct {
	Num     string
	Repo    string
	Outcome string
	Done    bool
}

// Capability is one folder of openspec/specs/.
type Capability struct {
	Name         string
	Purpose      string
	Requirements int
}

// Tree is everything the generators read.
type Tree struct {
	// Entries is sorted by id.
	Entries      []*Entry
	Capabilities []Capability
	// OldLiveIDs lists the ids of old-layout entries that are still live
	// (NNNN/ at the root, 0000 excluded). An `after` or `superseded_by` id may
	// name one, so that every commit of the migration passes whatever the
	// order of the conversion. Each one that has a config.yaml and no
	// converted entry of the same id is also an Entry of LayoutLegacyLive.
	OldLiveIDs []string
}

func (t *Tree) oldLive(id string) bool {
	for _, x := range t.OldLiveIDs {
		if x == id {
			return true
		}
	}
	return false
}

func (t *Tree) hasEntry(id string) bool { return t.Entry(id) != nil }

// Entry returns the entry with the id, or nil.
func (t *Tree) Entry(id string) *Entry {
	for _, e := range t.Entries {
		if e.ID == id {
			return e
		}
	}
	return nil
}

// Counts returns the shipped and total task counts.
func (e *Entry) Counts() (done, total int) {
	for _, s := range e.Tasks {
		for _, t := range s.Tasks {
			total++
			if t.Done {
				done++
			}
		}
	}
	return done, total
}

// File is one generated file. Path is relative to the repo root, with forward
// slashes.
type File struct {
	Path    string
	Content []byte
}

// validCategory reports whether c is in Categories.
func validCategory(c string) bool {
	for _, x := range Categories {
		if x == c {
			return true
		}
	}
	return false
}

func validStatus(s string) bool {
	for _, x := range statuses {
		if x == s {
			return true
		}
	}
	return false
}

// checkPath refuses a path the generators must never write: anything outside
// the repo, and anything under a specs folder.
func checkPath(p string) error {
	if p == "" || strings.HasPrefix(p, "/") || strings.Contains(p, "\\") {
		return fmt.Errorf("index: unsafe path %q", p)
	}
	for _, seg := range strings.Split(p, "/") {
		switch seg {
		case "", ".", "..":
			return fmt.Errorf("index: unsafe path %q", p)
		case "specs":
			return fmt.Errorf("index: %q is under specs/, which only a delivery changes", p)
		}
	}
	return nil
}
