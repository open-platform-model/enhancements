// Kubernetes policy/v1 API group re-exports
package v1

import pv1 "cue.dev/x/k8s.io/api/policy/v1"

#Eviction:                  pv1.#Eviction
#PodDisruptionBudget:       pv1.#PodDisruptionBudget
#PodDisruptionBudgetList:   pv1.#PodDisruptionBudgetList
#PodDisruptionBudgetSpec:   pv1.#PodDisruptionBudgetSpec
#PodDisruptionBudgetStatus: pv1.#PodDisruptionBudgetStatus
