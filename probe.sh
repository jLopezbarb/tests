#!/bin/sh
# Calls the internal endpoint from BuildKit and prints only the HTTP status code.
# Args: <label> <url> [token]
label="$1"; url="$2"; token="$3"
if [ -n "$token" ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $token" "$url")
else
  code=$(curl -s -o /dev/null -w '%{http_code}' "$url")
fi
echo "[probe] $label: HTTP $code"
