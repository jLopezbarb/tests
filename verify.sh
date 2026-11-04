#!/bin/sh
# Checks the execution order recorded by dependency.sh after an `okteto deploy`.
# Usage: sh verify.sh reset|success|early-failure|late-failure|chain|diamond|single-scheduled|failure-before-scheduled|reserved-variable|unhealthy|timeout|mixed|two-failures
# Run `reset` before each scenario so markers from a previous run don't leak in.
# Uses the current kubectl context/namespace (run `okteto kubeconfig` first).
set -e

SCENARIO="${1:?usage: verify.sh reset|success|early-failure|late-failure|chain|diamond|single-scheduled|failure-before-scheduled|reserved-variable|unhealthy|timeout|mixed}"
FAILED=0

ts() {
  kubectl get configmap "deps-e2e-$1" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null || true
}

# before A B: marker A happened at or before marker B (RFC3339 UTC sorts lexically)
before() {
  a="$(ts "$1")"
  b="$(ts "$2")"
  if [ -z "$a" ] || [ -z "$b" ]; then
    echo "FAIL: missing marker ($1='$a', $2='$b')"
    FAILED=1
    return
  fi
  if [ "$(printf '%s\n%s\n' "$a" "$b" | sort | head -n1)" = "$a" ]; then
    echo "ok:   $1 ($a) <= $2 ($b)"
  else
    echo "FAIL: expected $1 ($a) <= $2 ($b)"
    FAILED=1
  fi
}

exists() {
  if [ -n "$(ts "$1")" ]; then
    echo "ok:   $1 exists"
  else
    echo "FAIL: $1 should exist"
    FAILED=1
  fi
}

absent() {
  if [ -z "$(ts "$1")" ]; then
    echo "ok:   $1 absent"
  else
    echo "FAIL: $1 should not exist"
    FAILED=1
  fi
}

case "$SCENARIO" in
  reset)
    kubectl get configmap -o name | grep '^configmap/deps-e2e-' | xargs -r kubectl delete
    echo "markers removed"
    exit 0
    ;;
  success)
    # database and messaging run in parallel: each starts before the other ends
    before database-start messaging-end
    before messaging-start database-end
    # analytics is scheduled once database ends, while messaging is still running
    before database-end analytics-start
    before analytics-start messaging-end
    # backend waits for both
    before database-end backend-start
    before messaging-end backend-start
    # main waits for backend (wait: true) and the schedule of analytics
    before backend-end main-start
    # run right after `okteto deploy` returns: it didn't wait for analytics
    absent analytics-end
    ;;
  early-failure)
    absent messaging-end
    # database was already running, so it finishes
    exists database-end
    # nothing new is scheduled after the failure, and the main commands don't run
    absent backend-start
    absent analytics-start
    absent main-start
    ;;
  late-failure)
    before database-end main-start
    exists main-end
    absent reports-end
    ;;
  chain)
    before a-end b-start
    before b-end c-start
    before c-end main-start
    ;;
  diamond)
    before a-end b-start
    before a-end c-start
    # b and c run in parallel
    before b-start c-end
    before c-start b-end
    before b-end d-start
    before c-end d-start
    before d-end main-start
    ;;
  single-scheduled)
    exists main-end
    # run right after `okteto deploy` returns: it didn't wait for reports
    absent reports-end
    ;;
  failure-before-scheduled)
    absent database-end
    absent analytics-start
    absent main-start
    ;;
  reserved-variable)
    absent reports-start
    absent main-start
    ;;
  unhealthy)
    # the dependency deploys, but its pods never get healthy, so the main commands don't run
    exists database-end
    absent main-start
    ;;
  timeout)
    absent database-end
    absent main-start
    ;;
  two-failures)
    # both start in parallel and fail
    exists a-start
    exists b-start
    absent a-end
    absent b-end
    # c depends on a, and the main commands don't run
    absent c-start
    absent main-start
    ;;
  mixed)
    # run once mixed-b is deployed: it waits for mixed-a before running its commands
    before mixed-a-end mixed-b-start
    exists mixed-b-end
    ;;
  *)
    echo "unknown scenario: $SCENARIO"
    exit 2
    ;;
esac

if [ "$FAILED" -ne 0 ]; then
  echo "verification FAILED"
  exit 1
fi
echo "verification passed"
