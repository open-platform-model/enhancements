#!/usr/bin/env bash
# Evaluates each #Component label-union design against one composed component
# and reports what it produces. Self-contained: no registry, no network, no
# dependency on core/ or the catalogs.
set -u
cd "$(dirname "$0")"

row() { printf "  %-18s %-8s %s\n" "$1" "$2" "$3"; }
one() { # pkg expr
	out=$(cue eval -c -e "$2" "./$1" 2>&1)
	if [ $? -eq 0 ]; then
		row "$1" "ok" "$(echo "$out" | tr -d '\t' | tr '\n' ' ' | sed 's/  */ /g')"
	else
		row "$1" "FAIL" "$(echo "$out" | head -1 | cut -c1-70)"
	fi
}

echo "A. Unioning metadata.labels — filter designs"
echo "  variant            verdict  component labels"
echo "  ---------------------------------------------------------------------------"
for v in v_full v_prefix v_denylist v_denylist_req v_index_req; do one "$v" out; done

echo
echo "B. A dedicated matching field — metadata.labels left alone"
echo "  case               verdict  matchLabels"
echo "  ---------------------------------------------------------------------------"
one v_matchfield out
one v_matchfield outBare
one v_matchfield_conflict out

echo
echo "C. Folding matchLabels into rendered output — opt-in, default off"
echo "  case               verdict  rendered componentLabels"
echo "  ---------------------------------------------------------------------------"
one v_render outDefault
one v_render outOff
one v_render outOn

cat <<'EXPECT'

expected — A:
  v_full          FAIL  resource.opmodel.dev/category collides (workload/storage/config)
  v_prefix        ok    workload-type only; opm.opmodel.dev/tier DROPPED
  v_denylist      ok    workload-type AND opm.opmodel.dev/tier carried
  v_denylist_req  FAIL  cannot iterate a struct holding an unset required field
  v_index_req     ok    indexing tolerates the required field; tier not carried

expected — B:
  out             ok    both keys, catalog-owned namespace, no filter involved
  outBare         FAIL  "field is required but not present" — the ! marker still bites
  conflict        FAIL  "conflicting values daemon and stateful" — a real disagreement

expected — C:
  outDefault      ok    no matching labels rendered; flag unset
  outOff          ok    identical to default
  outOn           ok    both matching labels appended to componentLabels
EXPECT
