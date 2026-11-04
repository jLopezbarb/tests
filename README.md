# Manual tests: dependencies

Scenarios to test manifest `dependencies` against an Okteto instance, looking at the terminal and at the UI.

`okteto deploy` deploys the dependencies in parallel following `depends_on`, and shows them under one stage, `Deploy dependencies`. The lines of the dependencies running at the same time are interleaved, and every line is prefixed with `[name]`. Each awaited dependency starts with `[name] Deploying dependency '<name>'`. The deploy waits for the dependencies with `wait: true`, their `depends_on` chain and any dependency another one lists in `depends_on`. The rest are only scheduled. The deploy commands start when the awaited dependencies are deployed and the rest are scheduled.

## Setup

The dependencies are remote pipelines, so this repository must be reachable by Okteto (it's public, so no Git credentials are needed):

```sh
export DEPS_E2E_REPO=https://github.com/jLopezbarb/tests
export DEPS_E2E_BRANCH=main   # optional, defaults to main

OKTETO_SRC=<path to a checkout of okteto/okteto> ./build.sh   # builds ./okteto
./okteto context use <your okteto context>
./okteto namespace create deps-test   # or `namespace use` an existing one
./okteto kubeconfig                   # verify.sh uses kubectl
```

Run `sh verify.sh reset` before each scenario, so that markers left by a previous run don't leak into the checks. `verify.sh` compares the API-server timestamps of the `deps-e2e-<name>-start/-end` ConfigMaps that `dependency/dependency.sh` creates. While it works, each dependency prints one line per second, so the lines of the dependencies running at the same time interleave.

## Scenarios

| Scenario | Command | Check | Expected |
|---|---|---|---|
| Spec example | `./okteto deploy --dependencies` | `success` | The lines of database and messaging are interleaved. analytics is a single line, `[analytics] Repository 'analytics' scheduled for deployment`. The main deploy starts after backend, and the command returns without waiting for analytics. Repeat with `--wait`: only database, messaging and backend are health-checked. |
| Early failure | `./okteto deploy --dependencies -f okteto-early-failure.yml` | `early-failure` | messaging's block ends with its error. backend and analytics never start, the main deploy never runs, and the status is `error`. In the UI the error is the last line of `Deploy dependencies`. |
| Late failure | `./okteto deploy --dependencies -f okteto-late-failure.yml` | `late-failure` | reports is only scheduled. `okteto deploy` succeeds right after the commands. About a minute later the UI shows the deploy of reports, on its own, as failed. |
| Chain | `./okteto deploy --dependencies -f okteto-chain.yml` | `chain` | b (`wait: false`) is awaited because c needs it. a, b and c are deployed one after the other. b prints `b: received 'a'` and c prints `c: received 'b'`. |
| Diamond | `./okteto deploy --dependencies -f okteto-diamond.yml` | `diamond` | b and c run in parallel, and their lines are interleaved. |
| One awaited | `./okteto deploy --dependencies -f okteto-single-wait.yml` | | `[database]` lines under `Deploy dependencies`, then the main deploy. |
| One scheduled | `./okteto deploy --dependencies -f okteto-single-scheduled.yml` | `single-scheduled` | A single `[reports] … scheduled for deployment` line. The commands start right away, and the command doesn't wait for reports. |
| Only dependencies | `./okteto deploy --dependencies -f okteto-only-dependencies.yml` | | The `Deploy dependencies` stage, and the deploy ends as deployed. |
| Failure before a scheduled one | `./okteto deploy --dependencies -f okteto-failure-before-scheduled.yml` | `failure-before-scheduled` | analytics is never scheduled, and the error lists it as not deployed. |
| Can't be scheduled | `./okteto deploy --dependencies -f okteto-reserved-variable.yml` | `reserved-variable` | reports' block ends with `OKTETO_NAMESPACE is reserved variable name`. The main deploy never runs. |
| Unhealthy | `./okteto deploy --dependencies -f okteto-unhealthy.yml` | `unhealthy` | database deploys an image that doesn't exist. It fails before the commands, with `repository 'database' deployed with errors` or with its 2m timeout. |
| Two failures | `./okteto deploy --dependencies -f okteto-two-failures.yml` | `two-failures` | a and b fail in parallel: each one ends with its own `[name]  x  …` line, c never starts, and the deploy error lists both failures and c as not deployed. |
| Timeout | `./okteto deploy --dependencies -f okteto-timeout.yml` | `timeout` | It fails before the commands, naming database and its 20s timeout. |
| Nested | `./okteto deploy --dependencies -f okteto-nested.yml` | | parent's block includes the lines of child, as `[parent] [child] …`. |
| Mixed repositories | `./okteto deploy --dependencies --name mixed-a -f okteto-mixed-a.yml` | `mixed`, once mixed-b is deployed | a schedules b and finishes. b waits for a (`Repository 'mixed-a' is already being deployed…`) and then deploys. |
| Mutual `wait: true` | `./okteto deploy --dependencies --name mutual-a -f okteto-mutual-a.yml` | | A known limitation: blocked until the 1m timeout, then it fails. |
| Invalid graphs | `./okteto deploy -f okteto-invalid-cycle.yml`, `./okteto deploy -f okteto-invalid-reference.yml` | | They fail when the manifest loads, and nothing is deployed. |

## Existing state

- **Already deployed:** run the spec example, then `./okteto deploy` without `--dependencies`. Each dependency prints `Skipping repository '<name>' because it's already deployed`, and the main deploy runs right away.
- **Being deployed:** start the spec example, and from another terminal run `./okteto deploy` without `--dependencies` while it runs. The awaited ones print `Repository '<name>' is already being deployed, waiting for it to finish...`, and analytics prints `Repository 'analytics' already scheduled for deployment`.
- **Ctrl+C:** press it while database and messaging run. The command stops without a panic, the deploy is marked as failed, and the dependency pipelines finish on their own.

## Output and entry points

- **TTY:** the default. A spinner shows the dependency being shown, and the build progress of the main deploy is the TTY one.
- **Plain and JSON:** `--log-output plain` and `--log-output json`. One `Deploy dependencies` stage, and every line prefixed.
- **UI:** deploy the spec example from the UI, or with `--remote`. One `Deploy dependencies` stage, no dependency split across stages, and, when it fails, the error as the last line of the stage.
- **`okteto up`** on a dev environment that isn't deployed, and **`okteto test`**: the same output, and neither waits for `wait: false` dependencies.

## Cleanup

```sh
./okteto namespace delete deps-test
```

## Files

| File | Purpose |
|---|---|
| `okteto*.yml` | The scenarios. The dependencies come from `${DEPS_E2E_REPO}@${DEPS_E2E_BRANCH:-main}`. |
| `dependency/` | The generic dependency used by every scenario. Its behavior is set by the `DEP_NAME`, `SLEEP_SECONDS`, `FAIL`, `UNHEALTHY` and `RECEIVED` variables. The main deploys also run it. |
| `verify.sh` | Ordering assertions, based on the API-server timestamps of the marker ConfigMaps. |
| `build.sh` | Builds `./okteto` from a checkout of okteto/okteto. |
