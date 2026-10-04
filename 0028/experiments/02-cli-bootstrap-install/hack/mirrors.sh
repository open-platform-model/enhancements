#!/usr/bin/env bash
# Host-network pull-through mirrors. Needed on this host only: kind nodes and
# pods have no internet egress, host-network containers do. Not part of the
# design under test. Reached from the kind network at its gateway 172.18.0.1.
#   :5055 -> https://ghcr.io           (operator image, opmodel.dev CUE modules)
#   :5056 -> https://registry.cue.works (cue.dev/x/k8s.io)
set -euo pipefail
docker run -d --name exp-0028-02-ghcr-mirror --network host \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5055 -e REGISTRY_PROXY_REMOTEURL=https://ghcr.io registry:2
docker run -d --name exp-0028-02-cueworks-mirror --network host \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5056 -e REGISTRY_PROXY_REMOTEURL=https://registry.cue.works registry:2
