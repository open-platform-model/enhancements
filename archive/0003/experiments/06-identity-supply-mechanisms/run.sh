#!/usr/bin/env bash
# Driver for 06-identity-supply-mechanisms.
#
# Three ways to put identity into an artifact, compared on the one property
# that matters: does a TRANSITIVE importer see the right value?
#
#   A  @tag() with a default   — committed and visible, value injected at build
#   B  committed concrete value + inert @opm() marker
#   C  committed marker only, value from a sibling generated file
#
# No registry required.
set -uo pipefail
cd "$(dirname "$0")"

hr() { printf '=%.0s' {1..70}; echo; }

hr
echo "A — @tag(), NO injection.  What an ordinary consumer sees."
hr
cue eval ./a_tag/mod -e moduleSees -e catalogSees -e catalogFQN

hr
echo "A — @tag(), WITH injection of the module's own path."
echo "    This is the best case for OPM tooling: it knows the coordinate"
echo "    it fetched by and injects it. Watch the CATALOG."
hr
cue eval ./a_tag/mod -t modulePath=example.com/real-module@v2 \
	-e moduleSees -e catalogSees -e catalogFQN

hr
echo "B — committed concrete values + @opm() marker.  Plain cue, no flags."
hr
cue eval ./b_committed/mod -e moduleSees -e catalogSees -e catalogFQN
echo
echo "  attributes survive a round-trip through cue def:"
cue def ./b_committed/cat | grep '@opm' | sed 's/^/    /'
echo
echo -n "  cue vet -c on the committed tree: "
cue vet -c ./b_committed/... >/dev/null 2>&1 && echo "PASS" || echo "FAIL"

hr
echo "C — committed marker, value from a sibling GENERATED file."
hr
cue eval ./c_marker_plus_generated/cat -e ModulePath -e resourceFQN
echo
echo "  same tree with the generated file absent (fresh clone):"
mv c_marker_plus_generated/cat/gen_identity.cue ./.gen_hold 2>/dev/null
cue vet -c ./c_marker_plus_generated/... 2>&1 | sed 's/^/    /' | head -4
mv ./.gen_hold c_marker_plus_generated/cat/gen_identity.cue 2>/dev/null

hr
echo "VERDICT"
hr
CAT_UNINJ=$(cue eval ./a_tag/mod -e catalogSees 2>/dev/null | tr -d '"')
CAT_INJ=$(cue eval ./a_tag/mod -t modulePath=example.com/real-module@v2 -e catalogSees 2>/dev/null | tr -d '"')
[ "$CAT_UNINJ" = "$CAT_INJ" ] &&
	echo "  CONFIRMED  @tag injection does NOT reach an imported package." &&
	echo "             The catalog reads '$CAT_INJ' either way — the top-level" &&
	echo "             build cannot supply a transitive dependency's identity."
B_CAT=$(cue eval ./b_committed/mod -e catalogSees 2>/dev/null | tr -d '"')
[ "$B_CAT" = "example.com/real-catalog@v1" ] &&
	echo "  CONFIRMED  a committed value resolves correctly through the import," &&
	echo "             with no flags and no OPM tooling in the loop."
