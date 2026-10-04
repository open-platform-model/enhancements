package instance

// EXPERIMENT 0029/01 ONLY (see zz_exp_verify_render.go). `opm instance
// exp-verify NAME -n NS [--fresh-cache]` runs the removed handoff's gates 2,
// 3, 3b, 4 and 5 read-only and prints each verdict. It never flips ownership.

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/spf13/cobra"

	"github.com/open-platform-model/cli/internal/cmdutil"
	"github.com/open-platform-model/cli/internal/config"
	"github.com/open-platform-model/cli/internal/inventory"
	"github.com/open-platform-model/cli/internal/platform"
	"github.com/open-platform-model/cli/internal/workflow/render"
)

func NewExpVerifyCmd(cfg *config.GlobalConfig) *cobra.Command {
	var kf cmdutil.K8sFlags
	var namespace string
	var fresh bool
	c := &cobra.Command{
		Use:    "exp-verify NAME",
		Hidden: true,
		Args:   cobra.ExactArgs(1),
		RunE: func(c *cobra.Command, args []string) error {
			ctx := context.Background()
			k8sCfg, err := config.ResolveKubernetes(config.ResolveKubernetesOptions{
				Config: cfg, KubeconfigFlag: kf.Kubeconfig, ContextFlag: kf.Context, NamespaceFlag: namespace,
			})
			if err != nil {
				return err
			}
			client, err := cmdutil.NewK8sClient(k8sCfg, cfg.Log.Kubernetes.APIWarnings)
			if err != nil {
				return err
			}
			rec, err := inventory.GetRecord(ctx, client, args[0], k8sCfg.Namespace.Value)
			if err != nil || rec == nil {
				return fmt.Errorf("gate 2: no record: %v", err)
			}
			fmt.Printf("gate 2  owner=%q (cli-owned=%v)\n", rec.Owner, inventory.ResolveOwnership(rec) != inventory.ModeOperatorOwned)
			fmt.Printf("gate 3  source-local annotation=%v -> %s\n", rec.SourceLocal, verdict(!rec.SourceLocal))
			fmt.Printf("gate 3b spec.module=%s %s -> %s\n", rec.ModulePath, rec.ModuleVersion, verdict(rec.ModulePath != "" && rec.ModuleVersion != ""))
			fmt.Printf("        recorded lastAppliedRenderDigest=%s\n", rec.LastAppliedRenderDigest)
			if fresh {
				dir, err := os.MkdirTemp("", "exp-0029-01-verify-*")
				if err != nil {
					return err
				}
				os.Setenv("CUE_CACHE_DIR", dir)
				fmt.Printf("        CUE_CACHE_DIR=%s (fresh)\n", dir)
			} else {
				fmt.Printf("        CUE_CACHE_DIR=%s (as inherited)\n", os.Getenv("CUE_CACHE_DIR"))
			}
			start := time.Now()
			d, err := render.ExpVerificationDigest(ctx, cfg, k8sCfg, platform.ClusterPlatformGetterFor(client.Dynamic),
				rec.ModulePath, rec.ModuleVersion, rec.Name, rec.Namespace, rec.SpecValues)
			el := time.Since(start)
			if err != nil {
				fmt.Printf("gate 4  FAIL (%s): %v\n", el.Round(time.Millisecond), err)
				return nil
			}
			fmt.Printf("gate 4  PASS verification render in %s, digest=%s\n", el.Round(time.Millisecond), d)
			fmt.Printf("gate 5  digest equal=%v -> %s\n", d == rec.LastAppliedRenderDigest, verdict(d == rec.LastAppliedRenderDigest))
			return nil
		},
	}
	kf.AddTo(c)
	c.Flags().StringVarP(&namespace, "namespace", "n", "", "namespace")
	c.Flags().BoolVar(&fresh, "fresh-cache", false, "isolate CUE_CACHE_DIR like the old gate 4")
	return c
}

func verdict(ok bool) string {
	if ok {
		return "PASS"
	}
	return "REFUSE"
}
