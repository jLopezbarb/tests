#!/bin/sh
# Generic dependency for the dependency e2e tests.
#
# Inputs (env vars, passed as dependency `variables`):
#   DEP_NAME       required, name of the node (used for the workload and markers)
#   SLEEP_SECONDS  optional, simulated work before deploying (default 0). It prints a line every second,
#                  so the lines of the dependencies running at the same time interleave
#   FAIL           optional, "true" makes the deploy fail after sleeping (default false)
#   UNHEALTHY      optional, "true" deploys an image that doesn't exist, so its pods never get healthy
#   RECEIVED       optional, printed as is: set it to a variable of another dependency to check that it arrives
#
# It creates two marker ConfigMaps, deps-e2e-<name>-start and deps-e2e-<name>-end.
# Their creationTimestamp is set by the API server, so verify.sh can compare times
# from different pods and machines without clock skew.
set -e

: "${DEP_NAME:?DEP_NAME is required}"
SLEEP_SECONDS="${SLEEP_SECONDS:-0}"
FAIL="${FAIL:-false}"
UNHEALTHY="${UNHEALTHY:-false}"

kubectl delete configmap "deps-e2e-${DEP_NAME}-start" "deps-e2e-${DEP_NAME}-end" --ignore-not-found
kubectl create configmap "deps-e2e-${DEP_NAME}-start"

if [ -n "${RECEIVED:-}" ]; then
  echo "${DEP_NAME}: received '${RECEIVED}'"
fi

i=1
while [ "$i" -le "${SLEEP_SECONDS}" ]; do
  echo "${DEP_NAME}: working ${i}/${SLEEP_SECONDS}s"
  sleep 1
  i=$((i + 1))
done

if [ "${FAIL}" = "true" ]; then
  echo "${DEP_NAME}: failing on purpose"
  exit 1
fi

IMAGE="nginx:alpine"
if [ "${UNHEALTHY}" = "true" ]; then
  IMAGE="ghcr.io/okteto/this-image-does-not-exist:never"
fi

kubectl apply -f - <<YAML
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
        image: ${IMAGE}
        ports:
        - containerPort: 80
YAML

kubectl create configmap "deps-e2e-${DEP_NAME}-end"
echo "${DEP_NAME}: done"
