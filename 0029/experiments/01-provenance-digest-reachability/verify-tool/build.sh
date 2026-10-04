#!/usr/bin/env bash
# Builds an opm CLI from a COPY of cli at ae60f007 (1.0.0-beta.7) with the
# experiment's read-only `opm instance exp-verify` command dropped in.
# Usage: verify-tool/build.sh <scratch-dir>   -> <scratch-dir>/opmx
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?scratch dir}
cli=${CLI_REPO:-/var/home/emil/dev/open-platform-model/cli}
rm -rf "$out/clicopy" && mkdir -p "$out/clicopy"
git -C "$cli" archive ae60f007 | tar -x -C "$out/clicopy"
cp "$here/zz_exp_verify_render.go" "$out/clicopy/internal/workflow/render/"
cp "$here/zz_exp_verify_cmd.go" "$out/clicopy/internal/cmd/instance/"
sed -i 's|\tc.AddCommand(NewInstanceListCmd(cfg))|\tc.AddCommand(NewInstanceListCmd(cfg))\n\tc.AddCommand(NewExpVerifyCmd(cfg))|' \
  "$out/clicopy/internal/cmd/instance/instance.go"
# --runtime-name needs RuntimeName assignable in the copy.
sed -i 's|^const RuntimeName = "opm-cli"|var RuntimeName = "opm-cli"|' "$out/clicopy/internal/workflow/render/env.go"
go build -C "$out/clicopy" -o "$out/opmx" ./cmd/opm
echo "built $out/opmx"
