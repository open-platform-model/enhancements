// Variant (not part of the published module): the three objects the catalog
// path cannot reproduce exactly, written through objects@v1alpha1 instead.
// hack/variant.sh copies the module, deletes the "controller-manager",
// "manager-rbac", "metrics-auth-rbac" and "leader-election" components from
// the copy and adds this file, then renders and compares.
package opm_operator

import exp "opmodel.dev/catalogs/opm/resources/v1alpha1"

let P = #ctx.instance.name
let NS = #ctx.instance.namespace
let SA = "\(P)-controller-manager"
let SEL = {"app.kubernetes.io/name": "opm-operator", "control-plane": "controller-manager"}

#components: "exact-objects": {
	exp.#Objects
	spec: objects: {
		(SA): {apiVersion: "v1", kind: "ServiceAccount"}
		"\(P)-manager-rolebinding": {
			apiVersion: "rbac.authorization.k8s.io/v1"
			kind:       "ClusterRoleBinding"
			roleRef: {apiGroup: "rbac.authorization.k8s.io", kind: "ClusterRole", name: "\(P)-manager-role"}
			subjects: [{kind: "ServiceAccount", name: SA, namespace: NS}]
		}
		"\(P)-manager-role": {apiVersion: "rbac.authorization.k8s.io/v1", kind: "ClusterRole", rules: #rbacSource["manager-role"].rules}
		"\(P)-metrics-auth-rolebinding": {
			apiVersion: "rbac.authorization.k8s.io/v1"
			kind:       "ClusterRoleBinding"
			roleRef: {apiGroup: "rbac.authorization.k8s.io", kind: "ClusterRole", name: "\(P)-metrics-auth-role"}
			subjects: [{kind: "ServiceAccount", name: SA, namespace: NS}]
		}
		"\(P)-metrics-auth-role": {
			apiVersion: "rbac.authorization.k8s.io/v1"
			kind:       "ClusterRole"
			rules: [
				{apiGroups: ["authentication.k8s.io"], resources: ["tokenreviews"], verbs: ["create"]},
				{apiGroups: ["authorization.k8s.io"], resources: ["subjectaccessreviews"], verbs: ["create"]},
			]
		}
		"\(P)-leader-election-role": {
			apiVersion: "rbac.authorization.k8s.io/v1"
			kind:       "Role"
			rules: [
				{apiGroups: [""], resources: ["configmaps"], verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]},
				{apiGroups: ["coordination.k8s.io"], resources: ["leases"], verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]},
				{apiGroups: [""], resources: ["events"], verbs: ["create", "patch"]},
			]
		}
		"\(P)-leader-election-rolebinding": {
			apiVersion: "rbac.authorization.k8s.io/v1"
			kind:       "RoleBinding"
			roleRef: {apiGroup: "rbac.authorization.k8s.io", kind: "Role", name: "\(P)-leader-election-role"}
			subjects: [{kind: "ServiceAccount", name: SA, namespace: NS}]
		}
		"\(P)-controller-manager-metrics-service": {
			apiVersion: "v1"
			kind:       "Service"
			spec: {
				ports: [{name: "https", port: 8443, protocol: "TCP", targetPort: 8443}]
				selector: SEL
			}
		}
		"\(P)-controller-manager-deployment": {
			apiVersion: "apps/v1"
			kind:       "Deployment"
			metadata: name: SA
			spec: {
				replicas: #config.replicas
				selector: matchLabels: SEL
				template: {
					metadata: {
						annotations: "kubectl.kubernetes.io/default-container": "manager"
						labels: SEL
					}
					spec: {
						containers: [{
							name:            "manager"
							image:           #config.image.reference
							imagePullPolicy: #config.image.pullPolicy
							command: ["/manager"]
							args: [
								"--metrics-bind-address=:8443",
								"--leader-elect",
								"--health-probe-bind-address=:8081",
								if #config.registry != _|_ {"--registry=\(#config.registry)"},
								if #config.defaultServiceAccount != _|_ {"--default-service-account=\(#config.defaultServiceAccount)"},
								for a in #config.extraArgs {a},
							]
							env: [{name: "GOMEMLIMIT", value: #config.goMemLimit}]
							livenessProbe: {httpGet: {path: "/healthz", port: 8081}, initialDelaySeconds: 15, periodSeconds: 20}
							readinessProbe: {httpGet: {path: "/readyz", port: 8081}, initialDelaySeconds: 5, periodSeconds: 10}
							ports: []
							resources: {requests: {cpu: "100m", memory: "256Mi"}, limits: {cpu: "2", memory: "4Gi"}}
							securityContext: {
								allowPrivilegeEscalation: false
								capabilities: drop: ["ALL"]
								readOnlyRootFilesystem: true
							}
							volumeMounts: [{mountPath: "/tmp", name: "tmp"}]
						}]
						securityContext: {runAsNonRoot: true, seccompProfile: type: "RuntimeDefault"}
						serviceAccountName:            SA
						terminationGracePeriodSeconds: 10
						volumes: [{name: "tmp", emptyDir: {}}]
					}
				}
			}
		}
	}
}
