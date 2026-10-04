#!/usr/bin/env bash
# Fresh kind cluster opm-dogfood whose containerd pulls ghcr.io through the
# host mirror (hack/mirrors.sh). kind 0.32.0, node image kindest/node:v1.36.1.
set -euo pipefail
kind delete cluster --name opm-dogfood || true
kind create cluster --name opm-dogfood
docker exec opm-dogfood-control-plane sh -c 'mkdir -p /etc/containerd/certs.d/ghcr.io && printf "server = \"https://ghcr.io\"\n\n[host.\"http://172.18.0.1:5055\"]\n  capabilities = [\"pull\", \"resolve\"]\n" > /etc/containerd/certs.d/ghcr.io/hosts.toml'
