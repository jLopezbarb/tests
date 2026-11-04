#!/bin/sh
# Builds ./okteto from a checkout of the okteto repo: OKTETO_SRC=<path to the checkout> ./build.sh
set -e
: "${OKTETO_SRC:?OKTETO_SRC must point to a checkout of github.com/okteto/okteto}"
make -C "${OKTETO_SRC}" build BINDIR="$(pwd)"
./okteto version
