#!/bin/sh
set -eu

# Listmonk prints the API token to stderr once, on first install:
#   export LISTMONK_ADMIN_API_TOKEN="..."
# Bind-mount LISTMONK_CREDS_DIR so that file lands on the host.
#


CREDS_DIR="${LISTMONK_CREDS_DIR:-/creds}"

# The files we create in $CREDS_DIR will be initially owned by root,
# but we will need to restore them the original owner of the dir,
# as that folder is expected to be a bindmount to host machine,
# and it's just annoying to have a root-owned file that the host
# will later have to chown themselves.
CREDS_UID=$(stat -c '%u' "$CREDS_DIR") # original UID for creds/ dir on host machine
CREDS_GID=$(stat -c '%g' "$CREDS_DIR") # original GID for creds/ dir on host machine
INSTALL_LOG="$CREDS_DIR/install.log"

restore_creds_owner() {
	chown -R "${CREDS_UID}:${CREDS_GID}" "$CREDS_DIR" || true
}

if ! ./listmonk --install --idempotent --yes --config '' >"$INSTALL_LOG" 2>&1; then
	cat "$INSTALL_LOG"
	restore_creds_owner
	exit 1
fi
cat "$INSTALL_LOG"

TOKEN=$(sed -n 's/.*LISTMONK_ADMIN_API_TOKEN="\([^"]*\)".*/\1/p' "$INSTALL_LOG" | tail -n 1)
if [ -n "$TOKEN" ]; then
	json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
	printf '{"LISTMONK_URL":"%s","LISTMONK_API_USER":"%s","LISTMONK_API_TOKEN":"%s","CREATED_ON":"%s"}\n' \
		"$(json_str "http://127.0.0.1:${LISTMONK_PORT:-9002}")" \
		"$(json_str "${LISTMONK_ADMIN_API_USER}")" \
		"$(json_str "$TOKEN")" \
		"$(json_str "$(date -u +%Y-%m-%dT%H:%M:%SZ)")" \
		> "$CREDS_DIR/api.json.env"
fi

restore_creds_owner

./listmonk --upgrade --yes --config ''
exec ./listmonk --config ''
