// Experiment 07: do the two existing version selectors agree per major?
// HighestStable is copied from library/opm/compat/predecessor.go (library
// commit 11da9b0); selectCatalogVersion/qualifies/isNumericIdentifier from
// cli/internal/platform/catalog.go (cli commit 2370bd6). Fixture lists are the
// real GHCR listings recorded by experiment 01 on 2026-08-24.
package main

import (
	"fmt"
	"sort"
	"strings"

	msemver "github.com/Masterminds/semver/v3"
	"golang.org/x/mod/semver"
)

// --- copied: library/opm/compat/predecessor.go ---
func HighestStable(published []string) string {
	for i := len(published) - 1; i >= 0; i-- {
		sv, err := msemver.NewVersion(published[i])
		if err != nil {
			continue
		}
		if sv.Prerelease() == "" {
			return published[i]
		}
	}
	return published[len(published)-1]
}

// --- copied: cli/internal/platform/catalog.go ---
func selectCatalogVersion(published []string, prerelease bool) (selected, highest string) {
	for _, v := range published {
		if !semver.IsValid(v) {
			continue
		}
		if highest == "" || semver.Compare(v, highest) > 0 {
			highest = v
		}
		if !qualifies(v, prerelease) {
			continue
		}
		if selected == "" || semver.Compare(v, selected) > 0 {
			selected = v
		}
	}
	return selected, highest
}
func qualifies(v string, prerelease bool) bool {
	pre := strings.TrimPrefix(semver.Prerelease(v), "-")
	if !prerelease {
		return pre == ""
	}
	if pre == "" {
		return false
	}
	first, _, _ := strings.Cut(pre, ".")
	return !isNumericIdentifier(first)
}
func isNumericIdentifier(id string) bool {
	if id == "" {
		return false
	}
	for _, r := range id {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// --- fixtures: real listings from experiment 01 ---
var fixtures = map[string][]string{
	"opmodel.dev/catalogs/opm": {
		"v0.5.0-dev.1780214658.g87da983", "v0.5.0-dev.1780214993.g6a15114", "v0.5.0", "v0.5.1", "v0.5.2",
		"v0.6.0-dev.1781366210.gf22c04d", "v0.6.0-dev.1781635203.g402d667", "v0.6.0-dev.1781717558.g7d8a47c", "v0.6.0",
		"v1.0.0-0.dev.1786203588.gbc56e81", "v1.0.0-0.dev.1786384622.ga29ac27",
		"v1.0.0-alpha", "v1.0.0-alpha.1", "v1.0.0-alpha.2", "v1.0.0-alpha.3", "v1.0.0-alpha.4", "v1.0.0-alpha.5",
		"v1.0.0-alpha.6", "v1.0.0-alpha.7", "v1.0.0-alpha.8", "v1.0.0-alpha.9",
		"v1.0.0-dev.1782554335.gd46dcc0", "v1.0.0-dev.1783263771.g0d968ab", "v1.0.0-dev.1784212239.g0c11c12",
		"v1.0.0-dev.1785176190.g76f3cc6", "v1.0.0-dev.1785221734.g93df9e5", "v1.0.0-dev.1785235455.gfe577b3",
		"v1.0.0-dev.1785236718.g11f778b", "v1.0.0-dev.1785236912.g44e2ee9", "v1.0.0-dev.1785236912.gb7865bb", "v1.0.0",
		"v2.0.0-0.dev.1786372076.g22d3845", "v2.0.0-0.dev.1786373687.g624b02c", "v2.0.0-0.dev.1786373779.g69e2078",
		"v2.0.0-0.dev.1786386942.gdd4c324", "v2.0.0-0.dev.1786392380.g0a3023f", "v2.0.0-0.dev.1786470037.g918d4f1",
		"v2.0.0-0.dev.1787062834.g641abe3", "v2.0.0-0.dev.1787433514.g4cb8b5b", "v2.0.0-0.dev.1787433990.g7fd5af0",
		"v2.0.0-0.dev.1787434745.g9155983", "v2.0.0-0.dev.1787435068.g0a2cdd8",
		"v2.0.0-alpha.1", "v2.0.0-alpha.2", "v2.0.0-alpha.3", "v2.0.0-alpha.4", "v2.0.0-alpha.5",
	},
	"opmodel.dev/modules/cert_manager": {
		"v0.0.7", "v0.0.8", "v0.0.9", "v0.1.0", "v1.0.0", "v1.1.0", "v1.1.1", "v2.0.1",
	},
	"synthetic: dev-only major": {
		"v3.0.0-0.dev.1.gaaaaaaa", "v3.0.0-0.dev.2.gbbbbbbb",
	},
	"synthetic: old-style dev-only major": {
		"v4.0.0-dev.1.gaaaaaaa", "v4.0.0-dev.2.gbbbbbbb",
	},
}

func main() {
	names := make([]string, 0, len(fixtures))
	for n := range fixtures {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		fmt.Println("==", n)
		byMajor := map[string][]string{}
		var majors []string
		for _, v := range fixtures[n] {
			m := semver.Major(v)
			if _, ok := byMajor[m]; !ok {
				majors = append(majors, m)
			}
			byMajor[m] = append(byMajor[m], v)
		}
		fmt.Printf("%-6s %-34s %-34s %-34s %s\n", "major", "HighestStable (module init)", "catalog release pick", "catalog prerelease pick", "agree?")
		for _, m := range majors {
			list := byMajor[m]
			hs := HighestStable(list)
			rel, _ := selectCatalogVersion(list, false)
			pre, _ := selectCatalogVersion(list, true)
			agree := "yes"
			if rel == "" {
				if hs != pre {
					agree = "NO"
				}
			} else if hs != rel {
				agree = "NO"
			}
			fmt.Printf("%-6s %-34s %-34s %-34s %s\n", m, hs, or(rel), or(pre), agree)
		}
	}
}
func or(s string) string {
	if s == "" {
		return "(none)"
	}
	return s
}
