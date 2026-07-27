// Package secret is a runnable prototype of the kernel pass enhancement 0013
// proposes for library/opm/secret.
//
// It implements the pass end to end against real cue.Value inputs, with the API
// shape the enhancement proposes:
//
//	Discover(configSchema)           -> []Decl        (D3; values not needed)
//	Resolve(decls, values, instance) -> *Resolution   (D11; both arms converge)
//	RewriteValues(ctx, values, res)  -> cue.Value     (the rewrite itself)
//
// The central move is resolve-in-place. #Secret has two arms — {value} says
// WHAT the data is, {ref, key} says WHERE it lives. For a literal, the kernel's
// whole job is to turn a *what* into a *where*: pick the object, name it, put
// the data there. Once it has, the literal ALSO has a location, so it can be
// restated as a ref. Resolve performs that restatement, and afterwards nothing
// downstream can tell the two arms apart.
//
// This is a demonstration, not production code: errors are collected rather
// than wrapped in the library's error types, and the CUE encoding path is the
// simplest one that works rather than the fastest.
package secret

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"strings"

	"cuelang.org/go/cue"
)

// ─── Phase 1: Discover ──────────────────────────────────────────────────────

// Marker is the parsed form of @opm(secret, …) — the ROUTING half of the
// design. Mirrors #SecretMarker in ../../schemas/target.cue.
type Marker struct {
	Group       string // default "secrets"
	Key         string // default derived from the config path
	Type        string // default "Opaque"
	Immutable   bool
	Description string
}

// Decl is one marked field. Mirrors #SecretDecl.
type Decl struct {
	Path   string // dotted path into #config — the join key for everything
	Marker Marker
	Key    string // resolved: Marker.Key, or derived from Path
}

// Discover walks a module's #config schema and returns one Decl per marked
// field. It reads the SCHEMA, not the values: a CUE attribute belongs to the
// field that declares it and does not travel into the vertex supplying the
// value. Experiment 01 measures that.
//
// Because it reads the schema, this works with no values present — which is
// what lets `opm module inspect` list a module's secrets before any instance
// exists.
func Discover(configSchema cue.Value) ([]Decl, error) {
	var (
		out  []Decl
		errs []string
	)

	var rec func(v cue.Value, prefix string)
	rec = func(v cue.Value, prefix string) {
		switch v.Kind() {
		case cue.StructKind:
			it, err := v.Fields(cue.All())
			if err != nil {
				return
			}
			for it.Next() {
				child, path := it.Value(), join(prefix, it.Selector().String())
				if d, ok, err := parseField(child, path); err != nil {
					errs = append(errs, err.Error())
				} else if ok {
					out = append(out, d)
				}
				rec(child, path)
			}
		case cue.ListKind:
			it, err := v.List()
			if err != nil {
				return
			}
			for i := 0; it.Next(); i++ {
				child, path := it.Value(), fmt.Sprintf("%s[%d]", prefix, i)
				if d, ok, err := parseField(child, path); err != nil {
					errs = append(errs, err.Error())
				} else if ok {
					out = append(out, d)
				}
				rec(child, path)
			}
		}
	}
	rec(configSchema, "")

	if len(errs) > 0 {
		return nil, fmt.Errorf("discovering secrets:\n  - %s", strings.Join(errs, "\n  - "))
	}
	return out, nil
}

// parseField reads @opm off one field and, if it is a secret marker, builds the
// Decl. Reports (_, false, nil) for a field carrying no secret marker.
func parseField(v cue.Value, path string) (Decl, bool, error) {
	// >1 secret marker on one field has no sensible resolution. Experiment 01 E5
	// shows CUE returns both when two conjuncts carry different attribute text.
	var markers []cue.Attribute
	for _, a := range v.Attributes(cue.ValueAttr) {
		if a.Name() != "opm" {
			continue
		}
		if kind, err := a.String(0); err == nil && kind == "secret" {
			markers = append(markers, a)
		}
	}
	switch len(markers) {
	case 0:
		return Decl{}, false, nil
	case 1:
	default:
		return Decl{}, false, fmt.Errorf("%s: %d conflicting @opm(secret) markers", path, len(markers))
	}

	a := markers[0]
	m := Marker{Group: "secrets", Type: "Opaque"}
	for _, f := range []struct {
		key string
		dst *string
	}{
		{"group", &m.Group},
		{"key", &m.Key},
		{"type", &m.Type},
		{"description", &m.Description},
	} {
		if s, found, err := a.Lookup(1, f.key); err != nil {
			return Decl{}, false, fmt.Errorf("%s: parsing @opm(secret) argument %q: %w", path, f.key, err)
		} else if found {
			*f.dst = s
		}
	}
	// `immutable` is a bare flag rather than a key=value pair.
	if flag, err := a.Flag(1, "immutable"); err == nil {
		m.Immutable = flag
	}

	key := m.Key
	if key == "" {
		key = DeriveKey(path)
	}
	return Decl{Path: path, Marker: m, Key: key}, true, nil
}

// DeriveKey is the default data key: the config path with separators folded to
// underscores. Collision-free because the path it comes from is unique, so
// db.password and redis.password cannot both become "password".
func DeriveKey(path string) string {
	return strings.NewReplacer(".", "_", "[", "_", "]", "").Replace(path)
}

// ─── The fulfilment contract ────────────────────────────────────────────────

// Secret is the Go view of core's #Secret disjunction. Exactly one arm is set.
//
//	Literal ({value})    — the deployer has the data
//	Ref     ({ref, key}) — the cluster already holds it
//
// Ref is ALSO what Resolve writes back for a literal, which is the whole trick.
type Secret struct {
	Literal *Literal
	Ref     *Ref
}

// Literal — #SecretLiteral. Says WHAT the data is.
type Literal struct{ Value string }

// Ref — #SecretRef. Says WHERE the data lives.
type Ref struct {
	Ref string
	Key string
}

// DecodeSecret reads one #Secret value and reports which arm the deployer wrote.
// CUE has already guaranteed it is one of the two; this only asks which.
func DecodeSecret(v cue.Value) (Secret, error) {
	if s, err := v.LookupPath(cue.ParsePath("value")).String(); err == nil {
		return Secret{Literal: &Literal{Value: s}}, nil
	}
	ref, refErr := v.LookupPath(cue.ParsePath("ref")).String()
	key, keyErr := v.LookupPath(cue.ParsePath("key")).String()
	if refErr == nil && keyErr == nil {
		return Secret{Ref: &Ref{Ref: ref, Key: key}}, nil
	}
	return Secret{}, fmt.Errorf("value satisfies neither #SecretLiteral nor #SecretRef")
}

// ─── Phase 2: Resolve in place ──────────────────────────────────────────────

// GroupPlan is one Kubernetes Secret object the kernel will materialise. Only
// literals produce one — a deployer-written Ref is not ours to write.
type GroupPlan struct {
	Group      string
	ObjectName string
	Type       string
	Immutable  bool
	Data       map[string]string
	Members    []string
}

// Resolution is the whole pass's output. Mirrors #SecretsResolution.
type Resolution struct {
	Declarations []Decl
	Resolved     map[string]Ref // config path -> what the render sees. ALWAYS a Ref.
	Plans        []GroupPlan    // objects to materialise. literals only.
	Unfulfilled  []string
}

// Resolve groups the declarations, computes each object name exactly ONCE, and
// rewrites every declared secret into its Ref form.
//
// Computing the name here and writing it INTO the value is the point of D5+D11:
// there is exactly one such string, so an env reference and a volume reference
// to the same group cannot disagree. The divergence that exists in catalog_opm
// today becomes unrepresentable rather than merely fixed.
func Resolve(decls []Decl, values map[string]Secret, instance string) (*Resolution, error) {
	res := &Resolution{Declarations: decls, Resolved: map[string]Ref{}}

	type acc struct {
		typ, typFrom  string
		immutable     bool
		immutableFrom string
		data          map[string]string
		members       []string
	}
	groups := map[string]*acc{}
	var order []string
	var errs []string

	// Pass 1 — bucket literals into groups. A ref needs no plan.
	for _, d := range decls {
		s, ok := values[d.Path]
		if !ok {
			res.Unfulfilled = append(res.Unfulfilled, d.Path)
			continue
		}
		if s.Ref != nil {
			continue // already a *where*; nothing to decide
		}

		g, seen := groups[d.Marker.Group]
		if !seen {
			g = &acc{
				typ: d.Marker.Type, typFrom: d.Path,
				immutable: d.Marker.Immutable, immutableFrom: d.Path,
				data: map[string]string{},
			}
			groups[d.Marker.Group] = g
			order = append(order, d.Marker.Group)
		}
		// Type and immutability are properties of the OBJECT, so every member of a
		// group must agree. There is no sensible resolution otherwise.
		if g.typ != d.Marker.Type {
			errs = append(errs, fmt.Sprintf("group %q: %s declares type %q but %s declares %q",
				d.Marker.Group, g.typFrom, g.typ, d.Path, d.Marker.Type))
		}
		if g.immutable != d.Marker.Immutable {
			errs = append(errs, fmt.Sprintf("group %q: %s declares immutable=%v but %s declares %v",
				d.Marker.Group, g.immutableFrom, g.immutable, d.Path, d.Marker.Immutable))
		}
		if prev, dup := g.data[d.Key]; dup && prev != s.Literal.Value {
			errs = append(errs, fmt.Sprintf("group %q: key %q claimed twice with different values",
				d.Marker.Group, d.Key))
		}
		g.data[d.Key] = s.Literal.Value
		g.members = append(g.members, d.Path)
	}

	if len(errs) > 0 {
		sort.Strings(errs)
		return nil, fmt.Errorf("resolving secrets:\n  - %s", strings.Join(errs, "\n  - "))
	}

	// Pass 2 — name each object exactly once. The content hash is computed HERE,
	// before the rewrite, so a member's Ref already carries the suffix and every
	// consumer follows the object when the data changes.
	objectName := map[string]string{}
	for _, name := range order {
		g := groups[name]
		obj := ObjectName(instance, name)
		if g.immutable {
			obj += "-" + ContentHash(g.data)
		}
		objectName[name] = obj
		res.Plans = append(res.Plans, GroupPlan{
			Group: name, ObjectName: obj, Type: g.typ, Immutable: g.immutable,
			Data: g.data, Members: g.members,
		})
	}

	// Pass 3 — RESOLVE IN PLACE. Every declared secret becomes a Ref, whichever
	// arm the deployer wrote. Afterwards the two are indistinguishable.
	for _, d := range decls {
		s, ok := values[d.Path]
		if !ok {
			continue
		}
		if s.Ref != nil {
			// Already a *where*. Passes through as itself — never instance-prefixed,
			// because the module does not own that object.
			res.Resolved[d.Path] = *s.Ref
			continue
		}
		// Was a *what*. The kernel has just invented a place for it.
		res.Resolved[d.Path] = Ref{Ref: objectName[d.Marker.Group], Key: d.Key}
	}

	return res, nil
}

// ObjectName is the ONE place an OPM-owned Secret object gets its name (D5).
// Instance-scoped rather than component-scoped (D6): a Kubernetes Secret is a
// namespaced object, so two components of one instance sharing a group must
// reach the same object.
func ObjectName(instance, group string) string { return instance + "-" + group }

// ContentHash is a deterministic 10-char digest over sorted key=value pairs, so
// it is stable under reordering. It lives in the kernel because after
// resolution no transformer can see the data.
func ContentHash(data map[string]string) string {
	keys := make([]string, 0, len(data))
	for k := range data {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	pairs := make([]string, 0, len(keys))
	for _, k := range keys {
		pairs = append(pairs, k+"="+data[k])
	}
	sum := sha256.Sum256([]byte(strings.Join(pairs, "\n")))
	return hex.EncodeToString(sum[:5])
}

// ─── Applying the rewrite to the values tree ────────────────────────────────

// RewriteValues returns render-time values: the same shape as the supplied
// values, but with every declared secret replaced by its resolved Ref.
//
// The rewrite goes through a Go map because CUE unification cannot REPLACE a
// concrete value — {value: …} & {ref: …, key: …} is bottom under #Secret's
// closed arms, so FillPath would conflict rather than overwrite. Whether
// anything downstream re-unifies the ORIGINAL values against these is OQ2, and
// it is the one step of this design not yet measured on the real kernel path.
func RewriteValues(ctx *cue.Context, values cue.Value, res *Resolution) (cue.Value, error) {
	var raw map[string]any
	if err := values.Decode(&raw); err != nil {
		return cue.Value{}, fmt.Errorf("decoding values for rewrite: %w", err)
	}
	for path, ref := range res.Resolved {
		if !setPath(raw, strings.Split(path, "."), map[string]any{"ref": ref.Ref, "key": ref.Key}) {
			return cue.Value{}, fmt.Errorf("rewriting %s: path not present in values", path)
		}
	}
	return ctx.Encode(raw), nil
}

func setPath(m map[string]any, segs []string, val any) bool {
	cur := m
	for i, s := range segs {
		if i == len(segs)-1 {
			if _, ok := cur[s]; !ok {
				return false
			}
			cur[s] = val
			return true
		}
		next, ok := cur[s].(map[string]any)
		if !ok {
			return false
		}
		cur = next
	}
	return false
}

func join(prefix, sel string) string {
	if prefix == "" {
		return sel
	}
	return prefix + "." + sel
}
