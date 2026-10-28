# Catalog Secrets e2e

Manifests for testing catalog variables of type `secret` end to end. Each catalog item points at one of them with `manifestPath`.

| Manifest | Use |
| --- | --- |
| `okteto.yml` | Deploy and destroy commands print what they get: masked raw values, value hashes, variable names and the runner's CLI version |
| `local.yml` | Same commands with `remote: false`, for the local-execution guard |
| `image.yml` | Same commands with `image`, so they run remotely even when the installation runs deploys locally |
| `probe.yml` | Calls the secret variables endpoint from inside the remote runner and prints only the HTTP status of each call |

The scripts never print a secret value: `show.sh` prints the raw value only to check that it comes out masked, and hashes otherwise.
