// Package sample prepares the human review of an entry (design part one,
// section 4, steps 6 and 8): the random sample of requirements and the
// collision list, the nearest requirements of specs/ by shared words.
package sample

import (
	"crypto/rand"
	"encoding/binary"
	randv2 "math/rand/v2"
	"sort"
	"strings"
	"unicode"
)

// Metric states the score in the words the output prints.
const Metric = "score = shared distinct words / distinct words in either text (Jaccard index), " +
	"name and text, stop words removed; the 3 nearest across all of specs/, no threshold, no capability filter"

// Count is the number of ADDED requirements to draw out of n: max(3, 10 percent)
// rounded up, and all of them when there are fewer than 3.
func Count(n int) int {
	if n <= 3 {
		return n
	}
	k := (n + 9) / 10
	if k < 3 {
		k = 3
	}
	return k
}

// NewSeed returns a random seed for a draw.
func NewSeed() (uint64, error) {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return 0, err
	}
	return binary.LittleEndian.Uint64(b[:]), nil
}

// Draw picks k of n positions at random and returns them in ascending order.
// The same seed gives the same draw on any platform (PCG is fixed by the
// standard library).
func Draw(n, k int, seed uint64) []int {
	if k > n {
		k = n
	}
	if k <= 0 {
		return nil
	}
	r := randv2.New(randv2.NewPCG(seed, 0x656e68))
	idx := make([]int, n)
	for i := range idx {
		idx[i] = i
	}
	for i := 0; i < k; i++ {
		j := i + int(r.Uint64N(uint64(n-i)))
		idx[i], idx[j] = idx[j], idx[i]
	}
	out := append([]int(nil), idx[:k]...)
	sort.Ints(out)
	return out
}

// Req is a requirement as the collision list reads it.
type Req struct {
	Capability string
	Name       string
	Text       string
}

// ID is "capability/Name".
func (r Req) ID() string { return r.Capability + "/" + r.Name }

// Near is one entry of a collision list.
type Near struct {
	Req
	Score  float64
	Shared int
}

// Nearest returns the n requirements of universe nearest to target, best
// first. skip drops a requirement from the universe. A tie goes to the lower ID.
func Nearest(target Req, universe []Req, skip func(Req) bool, n int) []Near {
	tw := Words(target.Name + " " + target.Text)
	var all []Near
	for _, u := range universe {
		if u.ID() == target.ID() || (skip != nil && skip(u)) {
			continue
		}
		score, shared := Jaccard(tw, Words(u.Name+" "+u.Text))
		all = append(all, Near{u, score, shared})
	}
	sort.SliceStable(all, func(i, j int) bool {
		if all[i].Score != all[j].Score {
			return all[i].Score > all[j].Score
		}
		return all[i].ID() < all[j].ID()
	})
	if len(all) > n {
		all = all[:n]
	}
	return all
}

// Words returns the distinct words of s: lower case, letters and digits, at
// least two characters, stop words removed.
func Words(s string) map[string]struct{} {
	out := map[string]struct{}{}
	for _, w := range strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	}) {
		if len([]rune(w)) < 2 {
			continue
		}
		if _, stop := stopWords[w]; stop {
			continue
		}
		out[w] = struct{}{}
	}
	return out
}

// Jaccard returns the shared words divided by the words of either set, and
// the number of shared words. Two empty sets score 0.
func Jaccard(a, b map[string]struct{}) (float64, int) {
	if len(a) == 0 || len(b) == 0 {
		return 0, 0
	}
	shared := 0
	for w := range a {
		if _, ok := b[w]; ok {
			shared++
		}
	}
	union := len(a) + len(b) - shared
	return float64(shared) / float64(union), shared
}

var stopWords = func() map[string]struct{} {
	m := map[string]struct{}{}
	for _, w := range strings.Fields(`a about after all also an and any are as at be been but by can for from had has have
		if in into is it its may no not of on or other over per same so than that the their then there these this those
		to under up was were when where which while who will with within without would shall must should does do did
		each every one two such only own more most some`) {
		m[w] = struct{}{}
	}
	return m
}()
