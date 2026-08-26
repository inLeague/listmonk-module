#!/usr/bin/env bash
# Local-only: restart the Listmonk app container. start.sh runs --install --yes
# (fresh DB, new API token in creds/api.json.env). CI/ACT skip this.
set -euo pipefail

if [[ -n "${CI:-}" || -n "${ACT:-}" ]]; then
	exit 0
fi

DIR="$(cd "$(dirname "$0")" && pwd)"

docker compose --project-directory "$DIR" restart app
docker compose --project-directory "$DIR" up -d --wait --wait-timeout 120 app
