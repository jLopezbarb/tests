#!/bin/sh
# Calls the internal endpoint from BuildKit and prints only the HTTP status line.
# Args: <label> <url> [token]
label="$1"; url="$2"; token="$3"
if [ -n "$token" ]; then
  out=$(wget -q -S -O /dev/null --header "Authorization: Bearer $token" "$url" 2>&1)
else
  out=$(wget -q -S -O /dev/null "$url" 2>&1)
fi
echo "[probe] $label: $(echo "$out" | grep -o 'HTTP/1.1 [0-9]* [A-Za-z ]*' | head -1)"
