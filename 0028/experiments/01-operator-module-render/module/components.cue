package opm_operator

import (
	bp "opmodel.dev/catalogs/opm/blueprints/v1beta1"
	res "opmodel.dev/catalogs/opm/resources/v1beta1"
	tr "opmodel.dev/catalogs/opm/traits/v1beta1"
	exp "opmodel.dev/catalogs/opm/resources/v1alpha1"
)

// The kustomize namePrefix, as the instance name.
let P = #ctx.instance.name

// The controller's ServiceAccount; every binding subject points at it.
let SA = "\(P)-controller-manager"

#components: {

	// Namespace — the instance namespace itself (kustomize: opm-operator-system).
	// Catalog path: resources/v1alpha1 #Namespaces (exact name).
	namespace: {
		exp.#Namespaces
		spec: namespaces: (#ctx.instance.namespace): {}
	}

	// CRDs — catalog path: resources/v1beta1 #CRDs, fed from the cue-imported
	// controller-gen output. The whole imported spec is embedded, not picked
	// field by field: #CRDSchema is closed, so a spec field the catalog cannot
	// carry (spec.conversion, spec.preserveUnknownFields) refuses at render
	// instead of being dropped silently.
	crds: {
		res.#CRDs
		spec: crds: {
			for crdName, raw in #crdSource {
				(crdName): {
					raw.spec
					if raw.metadata.annotations != _|_ {
						annotations: raw.metadata.annotations
					}
				}
			}
		}
	}

	// Controller Deployment + its ServiceAccount + metrics Service.
	// Catalog path: blueprints/v1beta1 #StatelessWorkload (Deployment),
	// resources #ServiceAccount + #Volumes, traits WorkloadIdentity,
	// SecurityContext, GracefulShutdown, PodMetadata, Expose (Service).
	// Name: <instance>-controller-manager (derived, no override).
	"controller-manager": {
		bp.#StatelessWorkload
		res.#ServiceAccount
		res.#Volumes
		tr.#SecurityContext
		tr.#WorkloadIdentity
		tr.#GracefulShutdown
		tr.#PodMetadata
		tr.#Expose

		// Lands in the selector (immutable) and the pod labels; the Service
		// selects on the same componentLabels.
		metadata: labels: "control-plane": "controller-manager"

		spec: {
			statelessWorkload: {
				scaling: count: #config.replicas
				// Required by the blueprint; both are the Kubernetes defaults
				// install.yaml leaves implicit.
				restartPolicy: "Always"
				updateStrategy: type: "RollingUpdate"
				container: {
					name: "manager"
					image: {
						repository: #config.image.repository
						tag:        #config.image.tag
						digest:     #config.image.digest
						pullPolicy: #config.image.pullPolicy
					}
					command: ["/manager"]
					args: [
						"--metrics-bind-address=:8443",
						"--leader-elect",
						"--health-probe-bind-address=:8081",
						if #config.registry != _|_ {"--registry=\(#config.registry)"},
						if #config.defaultServiceAccount != _|_ {"--default-service-account=\(#config.defaultServiceAccount)"},
						for a in #config.extraArgs {a},
					]
					env: GOMEMLIMIT: value: #config.goMemLimit
					resources: #config.resources
					livenessProbe: {
						httpGet: {path: "/healthz", port: 8081}
						initialDelaySeconds: 15
						periodSeconds:       20
					}
					readinessProbe: {
						httpGet: {path: "/readyz", port: 8081}
						initialDelaySeconds: 5
						periodSeconds:       10
					}
					securityContext: {
						allowPrivilegeEscalation: false
						capabilities: drop: ["ALL"]
						readOnlyRootFilesystem: true
					}
					volumeMounts: tmp: spec.volumes.tmp & {mountPath: "/tmp"}
				}
			}

			volumes: tmp: {emptyDir: {}, readOnly: false}

			// Pod-level. seccompProfile: RuntimeDefault has no field in the
			// catalog's #SecurityContextSchema (finding, see README).
			securityContext: runAsNonRoot: true

			gracefulShutdown: terminationGracePeriodSeconds: 10

			podMetadata: annotations: "kubectl.kubernetes.io/default-container": "manager"

			// automountToken is optional in the schema but the SA helper reads
			// it unguarded, so it must be set (true == the API default).
			workloadIdentity: {name: SA, automountToken: true}
			serviceAccount: {name: SA, automountToken: true}

			expose: {
				name: "\(P)-controller-manager-metrics-service"
				type: "ClusterIP"
				ports: https: {targetPort: 8443, exposedPort: 8443}
			}
		}
	}

	// manager-role (controller-gen) + its binding. Catalog path: #Role,
	// which names the binding after the role (finding: kustomize names it
	// <prefix>-manager-rolebinding).
	"manager-rbac": {
		res.#Role
		spec: role: {
			name:  "\(P)-manager-role"
			scope: "cluster"
			rules: #rbacSource["manager-role"].rules
			subjects: [{name: SA}]
		}
	}

	// metrics-auth-role + binding (kubebuilder scaffold, hand-authored here).
	"metrics-auth-rbac": {
		res.#Role
		spec: role: {
			name:  "\(P)-metrics-auth-role"
			scope: "cluster"
			rules: [
				{apiGroups: ["authentication.k8s.io"], resources: ["tokenreviews"], verbs: ["create"]},
				{apiGroups: ["authorization.k8s.io"], resources: ["subjectaccessreviews"], verbs: ["create"]},
			]
			subjects: [{name: SA}]
		}
	}

	// leader-election Role + RoleBinding in the instance namespace.
	"leader-election": {
		res.#Role
		spec: role: {
			name:  "\(P)-leader-election-role"
			scope: "namespace"
			rules: [
				{apiGroups: [""], resources: ["configmaps"], verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]},
				{apiGroups: ["coordination.k8s.io"], resources: ["leases"], verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]},
				{apiGroups: [""], resources: ["events"], verbs: ["create", "patch"]},
			]
			subjects: [{name: SA}]
		}
	}

	// The five ClusterRoles nothing binds (aggregation helpers for admins).
	// #Role requires >=1 subject, so these go through objects@v1alpha1.
	"unbound-cluster-roles": {
		exp.#Objects
		spec: objects: {
			for k, raw in #rbacSource if k != "manager-role" {
				"\(P)-\(k)": {
					apiVersion: raw.apiVersion
					kind:       raw.kind
					rules:      raw.rules
				}
			}
		}
	}
}
