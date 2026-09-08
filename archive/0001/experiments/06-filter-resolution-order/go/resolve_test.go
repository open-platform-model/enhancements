// Demonstration — one canonical case proving the three-step resolution
// order with Masterminds/semver. Not a CI-tracked test suite; `go test` is
// just the cleanest invocation mechanism. Per skill: experiments are
// runnable demonstrations.
package filter

import (
	"reflect"
	"testing"
)

func TestCanonicalCase(t *testing.T) {
	input := []string{"1.0.0", "1.1.0", "1.2.0", "1.3.2", "1.4.0", "2.0.0"}
	filter := Filter{
		Range: ">=1.0.0 <2.0.0",
		Allow: []string{"2.0.1"},
		Deny:  []string{"1.3.2"},
	}
	want := []string{"1.0.0", "1.1.0", "1.2.0", "1.4.0", "2.0.1"}

	got, err := Resolve(input, filter)
	if err != nil {
		t.Fatalf("Resolve returned error: %v", err)
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("filter order mismatch\n got: %v\nwant: %v", got, want)
	}
	t.Logf("resolved (range → allow → deny): %v", got)
}
