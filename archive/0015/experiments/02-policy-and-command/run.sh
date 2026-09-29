#!/usr/bin/env bash
# Experiment 0015/02 (policy-and-command) verdict table. Run from anywhere: bash run.sh
# Copied shape: experiment 01 run.sh, plus a directory replacement of
# catalog_opm itself (the local copy carrying prerequisite P1).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/_out}
ROOT=$(cd "$HERE/../../../.." && pwd)
OPM=${OPM:-$ROOT/cli/bin/opm} # (cd cli && task build)
P=testing.opmodel.dev/experiments/0015/exp02
COMMAND=$P/contracts/traits/backup-command@v1alpha1
BACKUP=$P/contracts/traits/backup@v1alpha1

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
		printf 'PASS  %-72s %s\n' "$label" "$got"
		pass=$((pass + 1))
	else
		printf 'FAIL  %-72s want=%s got=%s\n' "$label" "$want" "$got"
		fail=$((fail + 1))
	fi
}
has() { grep -Fq -- "$2" "$1" && echo yes || echo no; }

stage() { # stage <case> <platform> <consumer>
	local d=$OUT/$1
	rm -rf "$d" && mkdir -p "$d"
	cp -r "$HERE"/{contracts,k8up,velero,catalog_opm} "$d/"
	cp -r "$HERE/$3" "$d/consumer"
	cp -r "$HERE/platforms/$2" "$d/platform"
	chmod -R u+w "$d"
	local repl=(--replace="$P/contracts@v0=$d/contracts" --replace="opmodel.dev/catalogs/opm@v4=$d/catalog_opm")
	grep -q "$P/k8up@v0" "$d/platform/cue.mod/module.cue" && repl+=(--replace="$P/k8up@v0=$d/k8up")
	grep -q "$P/velero@v0" "$d/platform/cue.mod/module.cue" && repl+=(--replace="$P/velero@v0=$d/velero")
	(cd "$d/platform" && cue mod edit "${repl[@]}") || return 1
	(cd "$d/consumer" && cue mod edit --replace="$P/contracts@v0=$d/contracts" --replace="opmodel.dev/catalogs/opm@v4=$d/catalog_opm") || return 1
}

build() { # build <case> <instance name> [extra opm flags...]
	local d=$OUT/$1 name=$2
	shift 2
	"$OPM" module build "$d/consumer" --platform "$d/platform" --name "$name" -n demo -o json "$@" \
		>"$d/out.json" 2>"$d/stderr.txt"
	echo $? >"$d/rc"
}

run_case() { # run_case <case> <platform> <consumer> <instance name> [extra opm flags...]
	local c=$1 p=$2 m=$3 n=$4
	shift 4
	stage "$c" "$p" "$m" || { echo "stage $c failed" >&2; return 1; }
	build "$c" "$n" "$@"
}

echo "== staging and building =="
run_case A k8up-only webapp web-demo
run_case B k8up-only mariadb mariadb-demo
run_case C velero-only mariadb mariadb-demo
run_case D k8up-only minecraft mc-demo -f "$OUT/D/consumer/values/command.cue"
run_case E velero-only minecraft mc-demo -f "$OUT/E/consumer/values/command.cue"
run_case F k8up-only minecraft mc-demo
run_case G velero-only minecraft mc-demo
echo

echo "== P1: the catalog copy stamps the volume key on every PVC =="
row ok "$(python3 "$HERE/check.py" P1 "$OUT/B/out.json")" "P1: PVCs carry volume.opmodel.dev/name == volume key"

echo "== case A: k8up, policy only =="
row 0 "$(cat "$OUT/A/rc")" "A: exit code"
row ok "$(python3 "$HERE/check.py" A "$OUT/A/out.json")" "A: backend from repository name, per-instance path, excludes ConfigMap + envFrom"

echo "== case B: k8up, database command: stream, landing ignored =="
row 0 "$(cat "$OUT/B/rc")" "B: exit code"
row ok "$(python3 "$HERE/check.py" B "$OUT/B/out.json")" "B: PreBackupPod, no mounts; Schedule selects only the command pod; neither PVC matches"

echo "== case C: velero, SAME database module: landing pre-hook, datadir skipped =="
row 0 "$(cat "$OUT/C/rc")" "C: exit code"
row ok "$(python3 "$HERE/check.py" C "$OUT/C/out.json")" "C: hook = command > /dumps/app.sql; policy skips 'data'; storageLocation; ttl"

echo "== case D: k8up, world command: PreBackupPod mounts the world beside the workload =="
row 0 "$(cat "$OUT/D/rc")" "D: exit code"
row ok "$(python3 "$HERE/check.py" D "$OUT/D/out.json")" "D: data PVC mounted ro at /data, pod affinity, .tar identity, quiesce inside the command"

echo "== case E: velero, SAME world module (command): landing pre-hook + compensate =="
row 0 "$(cat "$OUT/E/rc")" "E: exit code"
row ok "$(python3 "$HERE/check.py" E "$OUT/E/out.json")" "E: hook = sequence > /backups/world.tar; post save-on Continue; policy skips 'data'; ttl 480h"

echo "== case F: k8up, executor module: projection + maintenance only =="
row 0 "$(cat "$OUT/F/rc")" "F: exit code"
row ok "$(python3 "$HERE/check.py" F "$OUT/F/out.json")" "F: ConfigMap projection (itzg keys); Schedule prune+check only, no backup; sidecar envFrom; no PreBackupPod"

echo "== case G: velero, SAME executor-module declaration: projection only =="
row 0 "$(cat "$OUT/G/rc")" "G: exit code"
row ok "$(python3 "$HERE/check.py" G "$OUT/G/out.json")" "G: ConfigMap projection; no Schedule, no policy; sidecar present"
row no "$(has "$OUT/G/stderr.txt" "is not handled by any matched transformer")" "G: a projection-only output raises no warning"

echo
echo "$pass passed, $fail failed"
exit "$fail"
