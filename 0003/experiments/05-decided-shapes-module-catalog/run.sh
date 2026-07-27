#!/usr/bin/env bash
# Driver for 05-decided-shapes-module-catalog.
#
# The identity/ packages are GENERATED, never committed — that is the mechanism
# under test. This script plays the two roles that generate them:
#
#   publish  — `opm {module,catalog} publish` writing real coordinates
#   dev      — `opm module build/vet` writing the vMAJOR.0.0-dev placeholder (D20)
#
# It then evaluates the same source tree under both and diffs what changed.
set -uo pipefail
cd "$(dirname "$0")"

CAT_PATH="enhancements.opmodel.dev/0003/exp05/cat@v1"
MOD_PATH="enhancements.opmodel.dev/0003/exp05/media_server@v2"

# Modules and catalogs generate DIFFERENTLY, and the asymmetry is the point.
#
#   module  -> a file in the module's OWN package (mod/gen_identity.cue).
#              Modules are single-package, so there is no import cycle to break
#              and nothing for the author to reference. Zero author involvement.
#
#   catalog -> an identity/ SUBPACKAGE (cat/identity/identity.cue). Not
#              optional: experiment 03 measured that removing it makes the
#              catalog root and its transformers subpackage import each other
#              (`package import cycle not allowed`), and the leaves need the
#              constant at their own definition site to compute their FQNs.
gen_module_identity() { # $1 = dir, $2 = package, $3 = module path
	{
		echo "// GENERATED — do not commit. Written by publish, or by a local"
		echo "// build with a dev coordinate. The author writes none of this."
		echo "package $2"
		echo
		echo "metadata: modulePath: \"$3\""
	} >"$1/gen_identity.cue"
}

gen_catalog_identity() { # $1 = dir, $2 = package, $3 = module path, $4 = version
	# TWO generated files for a catalog, and both are needed:
	#   identity/identity.cue — the shared constant the LEAVES import to compute
	#                           their own FQNs. Cannot be merged into the root:
	#                           that is the import cycle experiment 03 measured.
	#   gen_identity.cue      — the ROOT binding, so the catalog author writes
	#                           no more than a module author does.
	mkdir -p "$1/identity"
	{
		echo "// GENERATED — do not commit. Read by resources/ and transformers/"
		echo "// to compute their own FQNs at their own definition sites."
		echo "package identity"
		echo
		echo "ModulePath: \"$3\""
		echo "Version:    \"$4\""
	} >"$1/identity/identity.cue"
	{
		echo "// GENERATED — do not commit. The root binding, so the author"
		echo "// writes nothing about identity."
		echo "package $2"
		echo
		echo "metadata: modulePath: \"$3\""
	} >"$1/gen_identity.cue"
}

show() {
	echo "  moduleFQN            $(cue eval . -e moduleFQN 2>/dev/null | tr -d '"')"
	echo "  moduleUUID           $(cue eval . -e moduleUUID 2>/dev/null | tr -d '"')"
	echo "  catalogFQN           $(cue eval . -e catalogFQN 2>/dev/null | tr -d '"')"
	echo "  module demands       $(cue eval . -e 'moduleDemands[0]' 2>/dev/null | tr -d '"')"
	echo "  catalog supplies     $(cue eval . -e 'catalogSupplies[0]' 2>/dev/null | tr -d '"')"
	echo "  matched              $(cue eval . -e 'len(matched)' 2>/dev/null)"
	echo "  builtAgainstCatalog  $(cue eval . -e builtAgainstCatalog 2>/dev/null | tr -d '"')"
	echo "  floor satisfied      $(cue eval . -e floor.satisfied 2>/dev/null)"
}

rm -rf cat/identity mod/identity mod/gen_identity.cue cat/gen_identity.cue

echo "=============================================================="
echo "MODE 1 — PUBLISH.  catalog published at v1.2.0, module at v2.1.0"
echo "=============================================================="
gen_catalog_identity cat cat "$CAT_PATH" "1.2.0"
gen_module_identity mod mod "$MOD_PATH"
cue vet ./... 2>&1 | head -5
show
PUB_UUID=$(cue eval . -e moduleUUID 2>/dev/null | tr -d '"')
PUB_DEMAND=$(cue eval . -e 'moduleDemands[0]' 2>/dev/null | tr -d '"')

echo
echo "=============================================================="
echo "MODE 2 — PUBLISH AGAIN at a later MINOR.  catalog v1.2.0 -> v1.3.0"
echo "  Identity and match keys must NOT move."
echo "=============================================================="
gen_catalog_identity cat cat "$CAT_PATH" "1.3.0"
show
BUMP_UUID=$(cue eval . -e moduleUUID 2>/dev/null | tr -d '"')
BUMP_DEMAND=$(cue eval . -e 'moduleDemands[0]' 2>/dev/null | tr -d '"')

echo
echo "=============================================================="
echo "MODE 3 — LOCAL DEV.  latest published 1.2.3 -> dev is 1.2.4-dev (D24)"
echo "=============================================================="
gen_catalog_identity cat cat "$CAT_PATH" "1.2.4-dev"
gen_module_identity mod mod "$MOD_PATH"
show
DEV_UUID=$(cue eval . -e moduleUUID 2>/dev/null | tr -d '"')
DEV_DEMAND=$(cue eval . -e 'moduleDemands[0]' 2>/dev/null | tr -d '"')

echo
echo "=============================================================="
echo "VERDICT"
echo "=============================================================="
[ "$PUB_UUID" = "$BUMP_UUID" ] &&
	echo "  PASS  module uuid stable across a catalog MINOR bump" ||
	echo "  FAIL  module uuid moved on a catalog MINOR bump ($PUB_UUID -> $BUMP_UUID)"
[ "$PUB_UUID" = "$DEV_UUID" ] &&
	echo "  PASS  module uuid identical local vs published" ||
	echo "  FAIL  module uuid diverges local vs published ($PUB_UUID vs $DEV_UUID)"
[ "$PUB_DEMAND" = "$BUMP_DEMAND" ] && [ "$PUB_DEMAND" = "$DEV_DEMAND" ] &&
	echo "  PASS  match key identical across minor bump AND local vs published" ||
	echo "  FAIL  match key moved"

echo
echo "=============================================================="
echo "THE D19 FLOOR, exercised directly"
echo "=============================================================="
floor() { # $1 = module built against, $2 = platform materialized
	printf "  built against %-10s platform on %-10s satisfied = %s\n" \
		"$1" "$2" \
		"$(cue eval ./platform -e "(#CatalogFloor & {requiredVersion: \"$1\", resolvedVersion: \"$2\"}).satisfied" 2>&1 | head -1)"
}
floor "1.0.0" "1.2.0" # cross-minor forward — the supported pattern
floor "1.2.0" "1.2.0" # exact
floor "1.2.0" "1.0.0" # THE FAILURE: platform catalog too old
floor "1.2.3" "1.2.4-dev" # D24: dev sorts ABOVE the latest release, so it passes

echo
echo "  NOTE on MODE 2's 'floor satisfied false': all three artifacts live in"
echo "  ONE tree here, so regenerating the catalog identity also changes what"
echo "  the module reports as builtAgainstCatalog. In reality that value is"
echo "  FROZEN into the module's published artifact at publish time. Mode 2 is"
echo "  therefore showing 'module rebuilt against 1.3.0, platform still on"
echo "  1.2.0' — a real too-old case, not a bug in the shapes."
echo
echo "  Generated identity left in place for inspection:"
echo "    cat/identity/identity.cue  cat/gen_identity.cue  mod/gen_identity.cue"
