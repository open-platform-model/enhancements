package render

// EXPERIMENT 0029/01 ONLY. Dropped into a scratch copy of the cli tree at
// ae60f007 by verify-tool/build.sh; never part of the cli. It re-creates the
// removed handoff gate 4 (cli 7ae153f7^ internal/workflow/handoff/verify.go,
// VerificationDigest) against today's render internals: acquire the CR's
// spec.module strictly from the registry (no local module context, so no
// local-module.cue replaceWith can apply), replay spec.values, render against
// the cluster Platform with the CLI runtime name, and return the render digest
// computed by inventory.ComputeRenderDigest (inside renderInstance).

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/open-platform-model/library/opm/kernel"

	"github.com/open-platform-model/cli/internal/config"
	"github.com/open-platform-model/cli/internal/platform"
)

// ExpVerificationDigest renders modulePath@version with values as instance
// name/namespace against the cluster Platform and returns the render digest.
func ExpVerificationDigest(ctx context.Context, cfg *config.GlobalConfig, k8sCfg *config.ResolvedKubernetesConfig,
	cluster platform.ClusterPlatformGetter, modulePath, version, name, namespace string, values map[string]any) (string, error) {
	k := config.NewKernel(cfg.Registry)

	mod, err := k.AcquireModuleFromRegistry(ctx, modulePath, version)
	if err != nil {
		return "", fmt.Errorf("gate 4: cannot resolve %s %s from the registry: %w", modulePath, version, err)
	}
	if values == nil {
		values = map[string]any{}
	}
	data, err := json.Marshal(values)
	if err != nil {
		return "", err
	}
	inst, err := k.SynthesizeInstance(ctx, kernel.InstanceInput{
		Module:    mod,
		Name:      name,
		Namespace: namespace,
		Values:    []kernel.Source{{Origin: "spec.values", Data: data}},
	})
	if err != nil {
		return "", fmt.Errorf("gate 4: synthesizing instance: %w", err)
	}
	// Cluster Platform only, like the old handoff (0006 D11): no --platform,
	// no deps fallback.
	env, err := resolvePlatformEnv(ctx, k, cfg, platform.ResolveOptions{Cluster: cluster})
	if err != nil {
		return "", fmt.Errorf("gate 4: resolving the cluster Platform: %w", err)
	}
	res, err := renderInstance(ctx, env, inst, k8sCfg, "", false)
	if err != nil {
		return "", fmt.Errorf("gate 4: render: %w", err)
	}
	return res.RenderDigest, nil
}
