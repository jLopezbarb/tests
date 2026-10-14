#!/bin/sh
# Generic dependency for the deps-execution-order e2e tests.
#
# Inputs (env vars, passed as dependency `variables`):
#   DEP_NAME       required, name of the node (used for the workload and markers)
#   SLEEP_SECONDS  optional, simulated work before deploying (default 0)
#   FAIL           optional, "true" makes the deploy fail after sleeping (default false)
#
# It creates two marker ConfigMaps, deps-e2e-<name>-start and deps-e2e-<name>-end.
# Their creationTimestamp is set by the API server, so verify.sh can compare times
# from different pods and machines without clock skew.
set -e

: "${DEP_NAME:?DEP_NAME is required}"
SLEEP_SECONDS="${SLEEP_SECONDS:-0}"
FAIL="${FAIL:-false}"

kubectl delete configmap "deps-e2e-${DEP_NAME}-start" "deps-e2e-${DEP_NAME}-end" --ignore-not-found
kubectl create configmap "deps-e2e-${DEP_NAME}-start"

echo "${DEP_NAME}: working for ${SLEEP_SECONDS}s"
sleep "${SLEEP_SECONDS}"

if [ "${FAIL}" = "true" ]; then
  echo "${DEP_NAME}: failing on purpose"
  exit 1
fi

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DEP_NAME}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${DEP_NAME}
  template:
    metadata:
      labels:
        app: ${DEP_NAME}
    spec:
      terminationGracePeriodSeconds: 1
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
EOF

kubectl create configmap "deps-e2e-${DEP_NAME}-end"
echo "${DEP_NAME}: done"
