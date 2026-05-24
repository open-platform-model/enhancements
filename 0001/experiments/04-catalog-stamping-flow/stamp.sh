#!/usr/bin/env bash
# stamp.sh — demonstrate the temp-build-dir publish-time stamping flow.
#
# Source-tree default: Catalog.Version == "0.0.0-dev". This script:
#   1. rsync's the catalog into .build/catalog/ (source tree untouched)
#   2. writes a version_override.cue setting Catalog.Version to the
#      requested SemVer
#   3. cue vet's the build dir at the stamped version
#   4. cue export's every primitive's metadata.version
#   5. diff's source tree vs build dir — only version_override.cue should differ
#
# Usage: bash stamp.sh [VERSION]   (default 1.0.0)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-1.0.0}"

rm -rf .build
mkdir -p .build
rsync -a --exclude='cue.mod/pkg' --exclude='cue.mod/gen' --exclude='cue.mod/usr' catalog/ .build/catalog/

cat > .build/catalog/version_override.cue <<EOF
package catalog
Catalog: Version: "${VERSION}"
EOF

echo "=== vet (must succeed at stamped version) ==="
( cd .build/catalog && cue vet ./... )

echo "=== export — every metadata.version must equal '${VERSION}' ==="
( cd .build/catalog && cue export ./resources/... ) \
	| jq '.. | objects | select(has("metadata")) | .metadata | {name, modulePath, version, fqn}'

echo "=== source-tree diff (only version_override.cue should appear) ==="
diff -r catalog .build/catalog || true
