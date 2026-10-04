#!/usr/bin/env bash
# predict.sh <namespace> <instance> [service-account]
# service-account: the SA the handoff is about to write into spec, or the
# operator's --default-service-account when the spec names none.
#
# Prototype of the applier-identity gate: resolve the operator's EFFECTIVE
# applier identity for a ModuleInstance the way buildApplyClient does
# (spec.serviceAccountName > --default-service-account > the controller's own
# ServiceAccount), then ask the API server (SubjectAccessReview via
# `kubectl auth can-i --as`) whether that identity holds every verb the first
# operator reconcile needs on every status.inventory entry:
#   get    - Flux ssa ApplyAll reads the live object; Prune reads it too
#   create - SSA of an absent object (re-create after drift / immutable recreate)
#   patch  - the server-side apply itself
#   delete - Prune of a stale entry and Flux's immutable-field recreate
# For ClusterRole / ClusterRoleBinding (and Role / RoleBinding) the API server
# additionally enforces RBAC escalation prevention, which no verb on the RBAC
# object captures: the identity must hold every rule it grants, or `escalate`
# (roles) / `bind` (bindings). That is checked separately per rule.
# Groups are passed exactly as the operator's impersonation config sets them
# (internal/apply/impersonate.go), so a binding to system:serviceaccounts[:ns]
# or system:authenticated is honoured.
set -uo pipefail
NS=$1; MI=$2; DEFAULT_SA=${3:-}
CTX=${CTX:-kind-opm-handoff-id}
K="kubectl --context $CTX"
CTRL_NS=opm-operator-system; CTRL_SA=opm-operator-controller-manager

spec_sa=$($K -n "$NS" get moduleinstance "$MI" -o jsonpath='{.spec.serviceAccountName}')
if [ -n "$spec_sa" ]; then sa_ns=$NS; sa=$spec_sa; src=spec.serviceAccountName
elif [ -n "$DEFAULT_SA" ]; then sa_ns=$NS; sa=$DEFAULT_SA; src="argument (SA the flip will set, or --default-service-account)"
else sa_ns=$CTRL_NS; sa=$CTRL_SA; src="controller (no SA configured)"; fi
user="system:serviceaccount:$sa_ns:$sa"
AS=(--as="$user" --as-group=system:serviceaccounts --as-group="system:serviceaccounts:$sa_ns" --as-group=system:authenticated)
echo "effective applier: $user  [source: $src]"
if [ "$src" != "controller (no SA configured)" ] && ! $K -n "$sa_ns" get sa "$sa" >/dev/null 2>&1; then
  echo "PREDICT FAIL: ServiceAccount $sa_ns/$sa does not exist (operator: Stalled/ImpersonationFailed)"; exit 1
fi

plural() { # group kind -> resource plural
  $K api-resources --api-group="$1" --no-headers -o wide 2>/dev/null | awk -v k="$2" '$NF!="" { if ($(NF-1)==k || $0 ~ " "k" ") print $1 }' | head -1
}
fail=0
can() { # verb resource.group ns name
  local nsflag=(); [ -n "$3" ] && nsflag=(-n "$3")
  $K auth can-i "$1" "$2${4:+/$4}" "${nsflag[@]}" "${AS[@]}" 2>/dev/null
}
check_rules() { # json rules array, label
  echo "$1" | jq -r '.[]? | . as $r | $r.apiGroups[] as $g | $r.resources[] as $res | $r.verbs[] as $v | "\($v) \(if $g == "" then $res else $res + "." + $g end)"' |
  while read -r v rg; do
    echo "      escalation check ($2): $v $rg -> $(can "$v" "$rg" "" "")"
  done
}
entries=$($K -n "$NS" get moduleinstance "$MI" -o json | jq -c '.status.inventory.entries[]')
while read -r e; do
  g=$(echo "$e" | jq -r '.group // ""'); kind=$(echo "$e" | jq -r .kind); n=$(echo "$e" | jq -r .name); ens=$(echo "$e" | jq -r '.namespace // ""')
  res=$($K api-resources --api-group="$g" --no-headers 2>/dev/null | awk -v k="$kind" '$NF==k {print $1}' | head -1)
  rg=$res; [ -n "$g" ] && rg="$res.$g"
  line="  $kind ${ens:+$ens/}$n:"
  for v in get create patch delete; do a=$(can $v "$rg" "$ens" "$n"); [ "$v" = create ] && a=$(can create "$rg" "$ens" ""); line="$line $v=$a"; [ "$a" = yes ] || fail=1; done
  echo "$line"
  case "$kind" in
    ClusterRole|Role)
      esc=$(can escalate "$rg" "$ens" "$n"); echo "      escalate=$esc"
      if [ "$esc" != yes ]; then
        out=$(check_rules "$($K ${ens:+-n $ens} get "$rg" "$n" -o json | jq -c .rules)" "$kind $n"); echo "$out"
        echo "$out" | grep -q -- '-> no' && fail=1
      fi ;;
    ClusterRoleBinding|RoleBinding)
      ref=$($K ${ens:+-n $ens} get "$rg" "$n" -o json | jq -r '.roleRef.kind+" "+.roleRef.name')
      rk=${ref% *}; rn=${ref#* }
      rres=clusterroles.rbac.authorization.k8s.io; rns=""; [ "$rk" = Role ] && { rres=roles.rbac.authorization.k8s.io; rns=$ens; }
      bind=$(can bind "$rres" "$rns" "$rn"); echo "      bind $rk/$rn=$bind"
      if [ "$bind" != yes ]; then
        out=$(check_rules "$($K ${rns:+-n $rns} get "$rres" "$rn" -o json 2>/dev/null | jq -c .rules)" "$rk $rn"); echo "$out"
        echo "$out" | grep -q -- '-> no' && fail=1
      fi ;;
  esac
done <<< "$entries"
if [ $fail = 0 ]; then echo "PREDICT OK: the effective applier holds every needed verb"; else echo "PREDICT FAIL: at least one entry is not appliable by the effective applier"; fi
exit $fail
