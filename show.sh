#!/bin/sh
# Prints what a catalog deploy or destroy command sees, without the secret values.
# The raw lines must come out masked; the hashes prove which value arrived.
phase="$1"
echo "[$phase] runner: $(okteto version 2>&1 | head -1) on $(hostname)"
echo "[$phase] E2E_API_TOKEN raw: ${E2E_API_TOKEN}"
echo "[$phase] E2E_API_TOKEN length: ${#E2E_API_TOKEN}"
echo "[$phase] E2E_API_TOKEN sha256: $(printf %s "$E2E_API_TOKEN" | sha256sum | cut -c1-16)"
echo "[$phase] E2E_DB_PASSWORD sha256: $(printf %s "$E2E_DB_PASSWORD" | sha256sum | cut -c1-16)"
echo "[$phase] E2E_SHORT raw: ${E2E_SHORT}"
echo "[$phase] E2E_LOG_LEVEL: ${E2E_LOG_LEVEL}"
echo "[$phase] env names: $(env | cut -d= -f1 | grep -E '^(E2E_|OKTETO_CATALOG)' | sort | tr '\n' ' ')"
