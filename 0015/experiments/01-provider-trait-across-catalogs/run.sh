#!/usr/bin/env bash
# Experiment 0015/01 verdict table. Run from anywhere: bash run.sh
#
# Assembles one scratch tree per case under _out/, generates the
# cue.mod/local-module.cue files with `cue mod edit --replace` (the file is
# the COMPLETE main-module dependency view, so it is never hand-written),
# runs `opm module build` and prints one PASS/FAIL row per check.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/_out}
ROOT=$(cd "$HERE/../../../.." && pwd)
OPM=${OPM:-$ROOT/cli/bin/opm} # (cd cli && task build)
P=testing.opmodel.dev/experiments/0015
FQN=$P/contracts/traits/backup@v1alpha1

export CUE_REGISTRY='opmodel.dev=ghcr.io/open-platform-model,testing.opmodel.dev=ghcr.io/open-platform-model,registry.cue.works'
export OPM_REGISTRY="$CUE_REGISTRY"

for tool in cue python3; do
	command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done
[ -x "$OPM" ] || { echo "missing opm binary at $OPM (cd cli && task build)" >&2; exit 1; }

echo "cue: $(cue version | head -1)"
echo "opm: $("$OPM" version | head -1)"
echo "cli: $(git -C "$ROOT/cli" rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo

pass=0
fail=0
row() { # row <expected> <observed> <label>
	local want="$1" got="$2" label="$3"
	if [ "$want" = "$got" ]; then
		printf 'PASS  %-62s %s\n' "$label" "$got"
		pass=$((pass + 1))
	else
		printf 'FAIL  %-62s want=%s got=%s\n' "$label" "$want" "$got"
		fail=$((fail + 1))
	fi
}
has() { grep -Fq -- "$2" "$1" && echo yes || echo no; }

stage() { # stage <case> <platform>
	local d=$OUT/$1
	rm -rf "$d" && mkdir -p "$d"
	cp -r "$HERE"/{contracts,k8up,velero,webapp} "$d/"
	cp -r "$HERE/platforms/$2" "$d/platform"
	chmod -R u+w "$d"
	local repl=(--replace="$P/contracts@v0=$d/contracts")
	grep -q "$P/k8up@v0" "$d/platform/cue.mod/module.cue" && repl+=(--replace="$P/k8up@v0=$d/k8up")
	grep -q "$P/velero@v0" "$d/platform/cue.mod/module.cue" && repl+=(--replace="$P/velero@v0=$d/velero")
	(cd "$d/platform" && cue mod edit "${repl[@]}") || return 1
	(cd "$d/webapp" && cue mod edit --replace="$P/contracts@v0=$d/contracts") || return 1
}

build() { # build <case> [extra opm flags...]
	local d=$OUT/$1
	shift
	"$OPM" module build "$d/webapp" --platform "$d/platform" --name web-demo -n demo -o json "$@" \
		>"$d/out.json" 2>"$d/stderr.txt"
	echo $? >"$d/rc"
}

run_case() { # run_case <case> <platform> [extra opm flags...]
	local c=$1 p=$2
	shift 2
	stage "$c" "$p" || { echo "stage $c failed" >&2; return 1; }
	build "$c" "$@"
}

echo "== staging and building =="
run_case A one-provider
run_case B two-providers
run_case C no-provider
run_case D no-provider -f "$OUT/D/webapp/values/advisory.cue"
run_case E velero-only
echo

echo "== case A: one provider (k8up) renders a Schedule scoped to the component =="
row 0 "$(cat "$OUT/A/rc")" "A: exit code"
row ok "$(python3 "$HERE/check.py" A "$OUT/A/out.json")" "A: k8up Schedule shape, no backend, selector == component labels"
row yes "$(has "$OUT/A/stderr.txt" "local replacement in effect: $P/k8up@v0 served from")" "A: k8up catalog served from a directory (platform replacement)"
row yes "$(has "$OUT/A/stderr.txt" "local replacement in effect: $P/contracts@v0 served from")" "A: contracts catalog served from a directory (platform replacement)"
row no "$(has "$OUT/A/stderr.txt" "the caller did not enable local replacements")" "A: opm build honours replacements (PR #209 binary)"

echo "== case B: two providers refuse as over-subscription naming both catalogs =="
row 2 "$(cat "$OUT/B/rc")" "B: exit code (validation error)"
row ok "$(python3 "$HERE/check.py" B "$OUT/B/out.json")" "B: nothing rendered"
row yes "$(has "$OUT/B/stderr.txt" "$FQN")" "B: refusal names the contract"
row yes "$(has "$OUT/B/stderr.txt" "$P/k8up@v0")" "B: refusal names the k8up catalog"
row yes "$(has "$OUT/B/stderr.txt" "$P/velero@v0")" "B: refusal names the velero catalog"
row yes "$(has "$OUT/B/stderr.txt" "provided by more than one enabled catalog")" "B: over-subscription wording"

echo "== case C: no provider, optional false: refused as unresolved demand =="
row 2 "$(cat "$OUT/C/rc")" "C: exit code (validation error)"
row ok "$(python3 "$HERE/check.py" C "$OUT/C/out.json")" "C: nothing rendered"
row yes "$(has "$OUT/C/stderr.txt" "unresolved trait demand")" "C: unresolved-demand wording"
row yes "$(has "$OUT/C/stderr.txt" "nothing on this platform implements this contract")" "C: 'nothing implements' (D1 premise: unimplemented reads as unknown)"
row no "$(has "$OUT/C/stderr.txt" "implemented at")" "C: no alternatives offered"

echo "== case D: no provider, optional true: warning, base objects render =="
row 0 "$(cat "$OUT/D/rc")" "D: exit code"
row ok "$(python3 "$HERE/check.py" D "$OUT/D/out.json")" "D: Deployment and PVC render, no Schedule"
row yes "$(has "$OUT/D/stderr.txt" "is not handled by any matched transformer")" "D: advisory warning names the unhandled trait"

echo "== case E: velero provider maps the same trait (keep-more ttl) =="
row 0 "$(cat "$OUT/E/rc")" "E: exit code"
row ok "$(python3 "$HERE/check.py" E "$OUT/E/out.json")" "E: velero Schedule in ns velero, ttl 672h, selector == component labels"

echo
echo "$pass passed, $fail failed"
exit "$fail"
