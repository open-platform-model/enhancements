package vet

import (
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"

	"github.com/open-platform-model/enhancements/tools/enh/internal/entry"
)

var (
	slugRe     = regexp.MustCompile(`^[a-z0-9]([a-z0-9-]*[a-z0-9])?$`)
	dateRe     = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
	acceptedRe = regexp.MustCompile(`^\d{4}-\d{2}-\d{2} [0-9a-f]{7,40}$`)
	idRe       = regexp.MustCompile(`^\d{4}$`)
)

var statuses = []string{"draft", "accepted", "delivered", "rejected", "superseded", "withdrawn"}

// liveStatuses may sit in openspec/changes; the others are archived endings.
var liveStatuses = []string{"draft", "accepted"}

// droppedKeys are the keys the design removed from config.yaml (T2.2 section 2).
var droppedKeys = []string{"depends_on", "amends", "supersedes", "history", "core_schema", "revives", "semver", "updated"}

// requiredKeys maps every required config key to the rule that owns it.
var requiredKeys = []struct{ key, rule string }{
	{"id", "V1"}, {"slug", "V1"}, {"title", "V2"}, {"summary", "V2"}, {"status", "V3"},
	{"category", "V4"}, {"affects", "V4"}, {"authors", "V4"}, {"created", "V4"},
}

// fieldRule maps a config field to its rule for a schema error that no Go
// rule reported first.
var fieldRule = map[string]string{
	"id": "V1", "slug": "V1", "title": "V2", "summary": "V2", "status": "V3",
	"category": "V4", "affects": "V4", "authors": "V4", "created": "V4",
	"breaking": "V5", "after": "V6", "accepted": "V7",
	"rejected": "V8", "withdrawn": "V8", "superseded_by": "V8",
}

func (r *run) configRules(e *ent) {
	if e.isSeed() {
		return
	}
	cfgPath := e.rel + "/config.yaml"
	if !e.ConfigFile.Exists {
		r.add(e, "V1", Error, cfgPath, 0, "config.yaml is missing")
		return
	}
	if e.ConfigErr != nil && e.Keys == nil {
		r.add(e, "V1", Error, cfgPath, 0, "config.yaml cannot be read: %s", firstLine(e.ConfigErr.Error()))
		return
	}
	c := e.Config
	has := map[string]bool{}
	for _, k := range e.Keys {
		has[k] = true
	}

	for _, rk := range requiredKeys {
		if !has[rk.key] {
			r.addField(e, rk.rule, Error, rk.key, "required field %q is missing", rk.key)
		}
	}

	// V1: id and slug agree with the folder.
	if _, _, ok := entry.StrictFolderRe(e.Base); !ok {
		r.add(e, "V1", Error, e.rel, 0, "folder name %q must be <id>-<slug> with a kebab-case slug", e.Base)
	}
	if has["id"] && c.ID != e.FolderID {
		r.addField(e, "V1", Error, "id", "id %q does not equal the folder prefix %q", c.ID, e.FolderID)
	}
	if has["slug"] {
		if !slugRe.MatchString(c.Slug) {
			r.addField(e, "V1", Error, "slug", "slug %q is not kebab-case", c.Slug)
		} else if c.Slug != e.FolderSlug {
			r.addField(e, "V1", Error, "slug", "slug %q does not equal the folder slug %q", c.Slug, e.FolderSlug)
		}
	}

	// V2: title and summary.
	if has["title"] {
		switch n := utf8.RuneCountInString(c.Title); {
		case strings.TrimSpace(c.Title) == "":
			r.addField(e, "V2", Error, "title", "title is empty")
		case n > 80:
			r.addField(e, "V2", Error, "title", "title has %d characters; the limit is 80", n)
		case strings.Contains(c.Title, "\n"):
			r.addField(e, "V2", Error, "title", "title must be one line")
		}
	}
	if has["summary"] {
		switch n := utf8.RuneCountInString(strings.TrimRight(c.Summary, "\n")); {
		case strings.TrimSpace(c.Summary) == "":
			r.addField(e, "V2", Error, "summary", "summary is empty")
		case strings.Contains(strings.TrimRight(c.Summary, "\n"), "\n"):
			r.addField(e, "V2", Error, "summary", "summary must be one line")
		case n > 200:
			r.addField(e, "V2", Error, "summary", "summary has %d characters; the limit is 200", n)
		}
	}

	r.statusRules(e, has)

	// V4: the created date is a date and not in the future.
	if has["created"] {
		switch {
		case !dateRe.MatchString(c.Created):
			r.addField(e, "V4", Error, "created", "created %q is not YYYY-MM-DD", c.Created)
		case c.Created > r.today:
			r.addField(e, "V4", Error, "created", "created %s is after today (%s)", c.Created, r.today)
		}
	}
	if has["authors"] && len(c.Authors) == 0 {
		r.addField(e, "V4", Error, "authors", "authors is empty")
	}
	if has["affects"] && len(c.Affects) == 0 {
		r.addField(e, "V4", Error, "affects", "affects is empty")
	}

	// V5: breaking is set from accept on.
	needBreaking := e.mode >= Accept || c.Status == "accepted" || c.Status == "delivered"
	if e.Archived && c.Status != "delivered" {
		needBreaking = false
	}
	if needBreaking && c.Breaking == nil {
		r.addField(e, "V5", Error, "breaking", "breaking must be true or false from accept on")
	}

	r.afterRules(e, has)
	r.recordRules(e, has)

	// V9: dropped and unknown keys.
	known := map[string]bool{}
	for _, k := range []string{"id", "slug", "title", "summary", "status", "category", "breaking", "affects", "authors", "created", "after", "accepted", "rejected", "withdrawn", "superseded_by"} {
		known[k] = true
	}
	for _, k := range e.Keys {
		switch {
		case containsStr(droppedKeys, k):
			r.addField(e, "V9", Error, k, "key %q was dropped from config.yaml by the design", k)
		case !known[k]:
			r.addField(e, "V9", Error, k, "unknown key %q in config.yaml", k)
		}
	}
	if e.ConfigErr != nil {
		r.add(e, "V1", Error, cfgPath, 0, "config.yaml has a type error: %s", firstLine(e.ConfigErr.Error()))
	}

	// The schema decides what the rules above did not report.
	for _, is := range r.schema.CheckConfig([]byte(e.ConfigFile.Text)) {
		if is.Field != "" && e.reported[is.Field] {
			continue
		}
		rule := fieldRule[is.Field]
		switch {
		case strings.Contains(is.Msg, "field not allowed"):
			rule = "V9"
		case rule == "":
			rule = "V1"
		}
		msg := is.Msg
		if len(is.Path) > 0 {
			msg = strings.Join(is.Path, ".") + ": " + msg
		}
		r.add(e, rule, Error, cfgPath, 0, "schema.cue: %s", msg)
		r.res.Findings[len(r.res.Findings)-1].Field = is.Field
	}
}

// V3: status is one of six and agrees with the markers and the folder.
func (r *run) statusRules(e *ent, has map[string]bool) {
	c := e.Config
	if !has["status"] {
		return
	}
	if !containsStr(statuses, c.Status) {
		r.addField(e, "V3", Error, "status", "status %q is not one of %s", c.Status, strings.Join(statuses, ", "))
		return
	}
	live := containsStr(liveStatuses, c.Status)
	switch {
	case live && e.Archived:
		r.addField(e, "V3", Error, "status", "status %q but the folder is archived", c.Status)
	case !live && !e.Archived:
		r.addField(e, "V3", Error, "status", "status %q but the folder is live (archived endings live under changes/archive)", c.Status)
	}
	// Markers: each status needs its record and no other ending record.
	need := map[string]string{"accepted": "accepted", "delivered": "accepted", "rejected": "rejected", "withdrawn": "withdrawn", "superseded": "superseded_by"}
	if k, ok := need[c.Status]; ok && !has[k] {
		r.addField(e, "V3", Error, "status", "status %q needs the %q record", c.Status, k)
	}
	for _, k := range []string{"rejected", "withdrawn", "superseded_by"} {
		if has[k] && need[c.Status] != k {
			r.addField(e, "V3", Error, k, "record %q does not belong to status %q", k, c.Status)
		}
	}
}

// V6: after names existing entries and makes no cycle.
func (r *run) afterRules(e *ent, has map[string]bool) {
	for _, id := range e.Config.After {
		switch {
		case id == e.ID():
			r.addField(e, "V6", Error, "after", "after names the entry itself")
		case !r.idExists(id):
			r.addField(e, "V6", Error, "after", "after names %q, which does not exist", id)
		}
	}
	if cyc := r.cycleFrom(e.ID()); len(cyc) > 0 {
		r.addField(e, "V6", Error, "after", "after makes a cycle: %s", strings.Join(cyc, " -> "))
	}
}

func (r *run) idExists(id string) bool {
	for _, x := range r.store.All() {
		if x.Kind == entry.Enhancement && x.ID() == id {
			return true
		}
	}
	// An old-layout entry that is still live is a valid target, so that every
	// commit of the migration passes whatever the order of the conversion
	// (DECISIONS.md 2026-10-10 23:35). 0000 was the template, not an entry.
	if id != "0000" && containsStr(r.store.LegacyLive, id) {
		return true
	}
	return containsStr(r.store.OldArchived, id)
}

// cycleFrom returns the ids of a cycle through start, or nil.
func (r *run) cycleFrom(start string) []string {
	edges := map[string][]string{}
	for _, x := range r.store.All() {
		if x.Kind == entry.Enhancement {
			edges[x.ID()] = x.Config.After
		}
	}
	var path []string
	seen := map[string]bool{}
	var dfs func(id string) bool
	dfs = func(id string) bool {
		path = append(path, id)
		for _, n := range edges[id] {
			if n == start {
				path = append(path, n)
				return true
			}
			if !seen[n] {
				seen[n] = true
				if dfs(n) {
					return true
				}
			}
		}
		path = path[:len(path)-1]
		return false
	}
	if dfs(start) && len(path) > 2 {
		return path
	}
	return nil
}

// V7 (format and presence) and V8 (end records).
func (r *run) recordRules(e *ent, has map[string]bool) {
	c := e.Config
	if has["accepted"] {
		if !acceptedRe.MatchString(c.Accepted) {
			r.addField(e, "V7", Error, "accepted", `accepted %q must read "<date> <commit>" (a 7 to 40 character lower-case hex commit)`, c.Accepted)
		} else if c.Accepted[:10] > r.today {
			r.addField(e, "V7", Error, "accepted", "accepted date %s is after today (%s)", c.Accepted[:10], r.today)
		}
		if c.Status == "draft" || c.Status == "rejected" {
			r.addField(e, "V7", Error, "accepted", "accepted is present but a %s entry was never accepted", c.Status)
		}
	}
	end := func(field string, en *entry.Ending) {
		if !has[field] {
			return
		}
		if en == nil || !dateRe.MatchString(en.Date) || strings.TrimSpace(en.Reason) == "" {
			r.addField(e, "V8", Error, field, "%s needs a date (YYYY-MM-DD) and a reason", field)
		}
	}
	end("rejected", c.Rejected)
	end("withdrawn", c.Withdrawn)
	if has["superseded_by"] {
		s := c.SupersededBy
		if s == nil || !dateRe.MatchString(s.Date) || strings.TrimSpace(s.Reason) == "" || len(s.IDs) == 0 {
			r.addField(e, "V8", Error, "superseded_by", "superseded_by needs a date, at least one successor id and a reason")
		} else {
			for _, id := range s.IDs {
				switch {
				case id == e.ID():
					r.addField(e, "V8", Error, "superseded_by", "superseded_by names the entry itself")
				case !r.idExists(id):
					r.addField(e, "V8", Error, "superseded_by", "successor %q does not exist", id)
				}
			}
		}
	}
}

// V10: the id is not reserved, blocked or used twice.
func (r *run) idRules(e *ent) {
	if e.isSeed() {
		for _, o := range r.store.All() {
			if o != e.Entry && o.Kind == entry.Seed && o.Base == e.Base {
				r.add(e, "V10", Error, o.Dir, 0, "seed %q is also used by %s", e.Base, o.Folder)
			}
		}
		return
	}
	id := e.ID()
	if id == "" {
		return
	}
	path := e.rel + "/config.yaml"
	if containsStr(r.schema.Reserved, id) {
		r.addField(e, "V10", Error, "id", "id %s is reserved", id)
	} else if containsStr(r.schema.Blocked, id) {
		r.addField(e, "V10", Error, "id", "id %s is blocked (blockedIds in schema.cue)", id)
	}
	var others []string
	for _, o := range r.store.All() {
		if o != e.Entry && o.Kind == entry.Enhancement && o.FolderID == e.FolderID && e.FolderID != "" {
			others = append(others, o.Folder)
		}
	}
	if containsStr(r.store.OldArchived, e.FolderID) {
		others = append(others, "archive/"+e.FolderID)
	}
	if len(others) > 0 {
		sort.Strings(others)
		r.add(e, "V10", Error, path, 0, "id %s is also used by %s", e.FolderID, strings.Join(others, ", "))
	}
}

// repoRules holds the rules about the checkout, not one entry.
func (r *run) repoRules() {
	if n := len(r.store.LegacyLive); n > 0 {
		lv := Warning
		if r.opts.Final {
			lv = Error
		}
		r.add(nil, "V30", lv, "", 0, "%d legacy live folders remain (migration only): %s", n, strings.Join(r.store.LegacyLive, " "))
	}
}

var allowedOpenSpecKeys = []string{"schema", "created", "skip_specs", "retire_capabilities"}

// V11 and V12.
func (r *run) openspecYamlRules(e *ent) {
	path := e.rel + "/.openspec.yaml"
	if !e.OpenSpecFile.Exists {
		if !e.Archived {
			r.add(e, "V11", Error, path, 0, ".openspec.yaml is missing")
		}
		return
	}
	if e.OpenSpecErr != nil {
		r.add(e, "V11", Error, path, 0, ".openspec.yaml cannot be read: %s", firstLine(e.OpenSpecErr.Error()))
		return
	}
	for _, k := range e.OpenSpecKeys {
		if !containsStr(allowedOpenSpecKeys, k) {
			r.add(e, "V11", Error, path, 0, "unknown key %q in .openspec.yaml (allowed: %s)", k, strings.Join(allowedOpenSpecKeys, ", "))
		}
	}
	if e.Archived {
		return
	}
	// V12: skip_specs is true if and only if there is no specs folder.
	switch {
	case e.SkipSpecs && e.HasSpecsDir:
		r.add(e, "V12", e.warnThenError(Accept), path, 0, "skip_specs is true but specs/ exists")
	case !e.SkipSpecs && !e.HasSpecsDir:
		r.add(e, "V12", e.warnThenError(Accept), path, 0, "there is no specs/ folder, so skip_specs: true is needed")
	}
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}
