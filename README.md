# Manual test: dependency execution order (`depends_on`)

A sandbox for manually testing the `depends_on` feature from branch `jlo-deps-execution-order`.

The dependencies are remote pipelines, so `dependency/` (with `okteto.yml` and `dependency.sh`) must be pushed to a Git repo that Okteto can clone, **at the root of that repo** (the scenarios use `manifest: dependency/okteto.yml`). Point the scenarios at it:

```sh
export DEPS_E2E_REPO=https://github.com/<owner>/<repo>
export DEPS_E2E_BRANCH=main   # optional, defaults to main
```

The quickest way is to publish this whole folder (a public repo needs no Git credentials in Okteto):

```sh
cd /tmp/okteto-deps-execution-order
git init -b main && echo okteto > .gitignore && git add . && git commit -m "deps e2e scenarios"
gh repo create <owner>/<repo> --public --source . --push
```

Nothing from these scenarios is added to the okteto repo. Scenario 4 (invalid graphs) doesn't need the repo, because it fails at manifest load.

## Setup

```sh
cd /tmp/okteto-deps-execution-order
./build.sh                                  # builds ./okteto from the worktree
./okteto context use <your okteto context>
./okteto namespace create deps-order-test   # or `namespace use` an existing one
./okteto kubeconfig                         # verify.sh uses kubectl
```

Run `sh verify.sh reset` before each scenario, so that markers left by a previous run don't leak into the checks.

## Scenarios

### 1. Success: the spec example

```sh
sh verify.sh reset
./okteto deploy --dependencies
sh verify.sh success
```

Expected:
- `database` and `messaging` start in parallel.
- `analytics` starts after `database`.
- `backend` starts after `database` and `messaging`.
- The main deploy starts after `backend` and finishes before `analytics`.
- The command returns after `analytics` finishes.
- The logs are interleaved, and each dependency line is prefixed with `[name]`.
- In the UI, each dependency's logs are under their own stage, `Deploying dependency <name>`.

Repeat with `--wait`. It should also wait for the pods of `analytics` to be ready.

### 2. Early failure: a dependency fails before the main deploy

```sh
sh verify.sh reset
./okteto deploy --dependencies -f okteto-early-failure.yml
sh verify.sh early-failure
```

Expected:
- The command fails with an error naming `messaging`.
- `database` finishes.
- `backend`, `analytics` and the main deploy never start.
- The deployment status in the UI is `error` and names `messaging`.

### 3. Late failure: a `wait: false` dependency fails after the main deploy

```sh
sh verify.sh reset
./okteto deploy --dependencies -f okteto-late-failure.yml
sh verify.sh late-failure
```

Expected:
- The main deploy runs.
- The command then waits for `reports` and fails with an error naming `reports`.
- The deployment status in the UI is `error` and names `reports`.

### 4. Invalid graphs: nothing is deployed

```sh
./okteto deploy --dependencies -f okteto-invalid-cycle.yml       # cyclic dependency found between dependencies a, b and c
./okteto deploy --dependencies -f okteto-invalid-reference.yml   # 'api' depends on 'cache', which is not defined
```

Only the first error is reported. Remove `api` from the manifest to see `dependency 'worker' cannot depend on itself`.

✅ Verified on `dbacf685`: both manifests fail at load with exit code 1, and nothing is deployed.

### 5. Skip-if-exists: already deployed counts as succeeded

Run scenario 1, then run it again **without** `--dependencies`:

```sh
./okteto deploy
```

Expected: the dependencies are skipped as already deployed and the main deploy runs right away.

### 6. Ctrl+C while waiting for dependencies

```sh
sh verify.sh reset
./okteto deploy --dependencies
# press Ctrl+C while database and messaging are running
```

Expected:
- The command stops right away, without a panic.
- The dependency pipelines keep running in Okteto, and finish on their own.

## Cleanup

```sh
./okteto namespace delete deps-order-test
```

## Files

| File | Purpose |
|---|---|
| `okteto*.yml` | The scenarios. The dependencies come from `${DEPS_E2E_REPO}@${DEPS_E2E_BRANCH:-main}`, using `dependency/okteto.yml`. |
| `dependency/` | The generic dependency used by every scenario. Its behavior is set by the `DEP_NAME`, `SLEEP_SECONDS` and `FAIL` variables. The main deploy also runs it, as `main`. |
| `verify.sh` | Ordering assertions, based on the API-server timestamps of the `deps-e2e-<name>-start/-end` ConfigMaps. |
| `build.sh` | Rebuilds `./okteto` from the worktree. |
