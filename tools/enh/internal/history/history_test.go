package history

import (
	"bytes"
	"strings"
	"testing"

	"github.com/open-platform-model/enhancements/tools/enh/internal/delta"
)

func spec(cap, src string) *delta.Spec { return delta.Parse(cap+".md", cap, []byte(src)) }

const scen = "\n#### Scenario: s\n- **WHEN** a\n- **THEN** b\n"

func added(name, text string) string {
	return "### Requirement: " + name + "\n" + text + "\n" + scen + "\n"
}

func sources() []Source {
	return []Source{
		{Folder: "2026-10-14-seed-reg", Date: "2026-10-14", Label: "seed-reg", Specs: []*delta.Spec{spec("reg",
			"## ADDED Requirements\n\n"+added("Refuse the build-incompatible", "Acceptance SHALL refuse it.")+
				added("One provider", "Acceptance SHALL refuse a second claim."))}},
		{Folder: "2026-10-28-0032-name", Date: "2026-10-28", Label: "0032", Status: "delivered", Specs: []*delta.Spec{spec("reg",
			"## MODIFIED Requirements\n\n"+added("Refuse the build-incompatible", "Acceptance SHALL refuse it and name the provider."))}},
		{Folder: "2026-11-01-0040-rejected", Date: "2026-11-01", Label: "0040", Status: "rejected", Specs: []*delta.Spec{spec("reg",
			"## MODIFIED Requirements\n\n"+added("Refuse the build-incompatible", "NEVER SHALL appear."))}},
		{Folder: "2026-11-12-0026-per-resolution", Date: "2026-11-12", Label: "0026", Status: "delivered", Specs: []*delta.Spec{spec("reg",
			"## ADDED Requirements\n\n"+added("One provider per resolution", "Acceptance SHALL count per resolution.")+
				"## REMOVED Requirements\n\n### Requirement: One provider\n**Reason**: counted per resolution.\n**Migration**: Replaced by \"One provider per resolution\"\n\n"+
				"## RENAMED Requirements\n\n- FROM: `### Requirement: Refuse the build-incompatible`\n- TO: `### Requirement: Refuse a build-incompatible provider`\n")}},
	}
}

func TestQuery(t *testing.T) {
	chains, err := Query(sources(), "Refuse the build-incompatible", "", nil)
	if err != nil || len(chains) != 1 {
		t.Fatalf("%v %v", chains, err)
	}
	c := chains[0]
	if c.Name != "Refuse a build-incompatible provider" || len(c.Rows) != 3 {
		t.Fatalf("chain = %+v", c)
	}
	ops := []string{c.Rows[0].Op, c.Rows[1].Op, c.Rows[2].Op}
	if strings.Join(ops, ",") != "ADDED,MODIFIED,RENAMED" || !c.Rows[0].Seed {
		t.Errorf("rows = %v seed=%v", ops, c.Rows[0].Seed)
	}
	for _, r := range c.Rows {
		if strings.Contains(r.Text, "NEVER") {
			t.Error("a rejected entry is in the history")
		}
	}
	// the new name finds the same chain
	if c2, err := Query(sources(), "refuse a build-incompatible provider", "reg", nil); err != nil || len(c2) != 1 || len(c2[0].Rows) != 3 {
		t.Errorf("by the new name: %v %v", c2, err)
	}
}

func TestReplacedByIsFollowedBothWays(t *testing.T) {
	for _, req := range []string{"One provider", "One provider per resolution"} {
		chains, err := Query(sources(), req, "", nil)
		if err != nil || len(chains) != 1 {
			t.Fatalf("%s: %v %v", req, chains, err)
		}
		c := chains[0]
		if len(c.Rows) != 3 || c.Rows[0].Name != "One provider" || c.Rows[1].Name != "One provider per resolution" {
			t.Errorf("%s: chain = %+v", req, c)
		}
		var buf bytes.Buffer
		Format(&buf, chains)
		if !strings.Contains(buf.String(), `Migration: Replaced by "One provider per resolution"`) ||
			!strings.Contains(buf.String(), "Reason: counted per resolution.") {
			t.Errorf("%s: output:\n%s", req, buf.String())
		}
	}
}

func TestQueryErrorsAndOrder(t *testing.T) {
	if _, err := Query(sources(), "Nothing", "", nil); err == nil || !strings.Contains(err.Error(), "no requirement named") {
		t.Errorf("unknown: %v", err)
	}
	if _, err := Query(sources(), "One provider", "other-cap", nil); err == nil {
		t.Error("a wrong capability matched")
	}
	// two folders of one date: the order map decides, then the name
	a := Source{Folder: "2026-10-01-b", Date: "2026-10-01", Label: "b", Specs: []*delta.Spec{spec("c", "## ADDED Requirements\n\n"+added("R", "first SHALL x."))}}
	b := Source{Folder: "2026-10-01-a", Date: "2026-10-01", Label: "a", Specs: []*delta.Spec{spec("c", "## MODIFIED Requirements\n\n"+added("R", "second SHALL x."))}}
	chains, err := Query([]Source{b, a}, "R", "", map[string]int{"2026-10-01-b": 0, "2026-10-01-a": 1})
	if err != nil || chains[0].Rows[0].Label != "b" || chains[0].Rows[1].Label != "a" {
		t.Errorf("order map: %+v %v", chains, err)
	}
	chains, _ = Query([]Source{b, a}, "R", "", nil)
	if chains[0].Rows[0].Label != "a" {
		t.Errorf("name order: %+v", chains)
	}
}

func TestSameNameInTwoCapabilitiesIsTwoChains(t *testing.T) {
	s := []Source{{Folder: "2026-01-01-x", Date: "2026-01-01", Label: "0001", Status: "delivered", Specs: []*delta.Spec{
		spec("one", "## ADDED Requirements\n\n"+added("Same", "A SHALL x.")),
		spec("two", "## ADDED Requirements\n\n"+added("Same", "B SHALL x.")),
	}}}
	chains, err := Query(s, "Same", "", nil)
	if err != nil || len(chains) != 2 {
		t.Fatalf("%v %v", chains, err)
	}
	if one, _ := Query(s, "Same", "two", nil); len(one) != 1 || one[0].Capability != "two" {
		t.Errorf("narrowed: %+v", one)
	}
}

func TestReplacedBy(t *testing.T) {
	for in, want := range map[string]string{
		`Replaced by "X y"`:        "X y",
		`  replaced by "X y" `:     "X y",
		`Read "X y"`:               "",
		`Replaced by X y`:          "",
		`Replaced by "A" and more`: "A",
	} {
		got, ok := ReplacedBy(in)
		if got != want || ok != (want != "") {
			t.Errorf("ReplacedBy(%q) = %q, %v", in, got, ok)
		}
	}
}
