#!/bin/sh
# Rebuilds ./okteto from the worktree branch.
set -e
make -C "/Users/javi/.herdr/worktrees/okteto/jlo-deps-execution-order" build BINDIR="/tmp/okteto-deps-execution-order"
"/tmp/okteto-deps-execution-order/okteto" version
