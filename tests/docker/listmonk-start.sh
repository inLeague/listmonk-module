#!/bin/sh
set -eu

# Listmonk prints the API token to stderr once, on first install:
#   export LISTMONK_ADMIN_API_TOKEN="..."
# Bind-mount LISTMONK_CREDS_DIR so that file lands on the host.

CREDS_DIR="${LISTMONK_CREDS_DIR:-/listmonk/creds}"
mkdir -p "$CREDS_DIR"
INSTALL_LOG="$CREDS_DIR/install.log"

if ! ./listmonk --install --idempotent --yes --config '' >"$INSTALL_LOG" 2>&1; then
	cat "$INSTALL_LOG"
	exit 1
fi
cat "$INSTALL_LOG"

TOKEN=$(sed -n 's/.*LISTMONK_ADMIN_API_TOKEN="\([^"]*\)".*/\1/p' "$INSTALL_LOG" | tail -n 1)
if [ -n "$TOKEN" ]; then
	json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
	printf '{"LISTMONK_URL":"%s","LISTMONK_API_USER":"%s","LISTMONK_API_TOKEN":"%s"}\n' \
		"$(json_str "http://127.0.0.1:${LISTMONK_PORT:-9002}")" \
		"$(json_str "${LISTMONK_ADMIN_API_USER}")" \
		"$(json_str "$TOKEN")" \
		> "$CREDS_DIR/api.json.env"
fi

./listmonk --upgrade --yes --config ''
exec ./listmonk --config ''
