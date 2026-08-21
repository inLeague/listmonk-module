#!/usr/bin/env bash

##
## ./run-tests.sh --- run locally
## act -j tests   --- run github "tests" action locally via "act" (install act via ./get-act.sh)
##

set -euo pipefail
cd "$(dirname "$0")"

mkdir -p tests/results tests/docker/creds

if [[ "${CI:-}" == "" && "${ACT:-}" == "" ]]; then
    # Not CI and not ACT - this is a "purely" local run
    # we could manage this with some flags but we don't need at this time
    echo ""
	echo "Local test runner -- if you need to rebuild/restart listmonk containers please do so manually"
    echo ""
fi

echo "==> Starting Listmonk (docker compose)"
if ! docker compose --project-directory tests/docker up -d --wait --wait-timeout 180; then
	echo "Listmonk failed to become healthy" >&2
	docker compose --project-directory tests/docker ps -a >&2 || true
	docker compose --project-directory tests/docker logs >&2 || true
	exit 1
fi

creds="tests/docker/creds/api.json.env"
if [[ ! -f "$creds" ]]; then
	echo "Listmonk credentials were not written to $creds" >&2
	docker compose --project-directory tests/docker logs >&2 || true
	exit 1
fi

echo "==> Starting BoxLang server"
if [[ "${ACT:-}" == "true" ]]; then
	echo "act: using host BoxLang server at http://127.0.0.1:60299"
else
	box server restart serverConfigFile=server-boxlang.json
fi

set +e
echo "==> Running TestBox"
box testbox run runner=http://127.0.0.1:60299/tests/runner.cfm outputFormats=json,simple,junit outputFile=tests/results/testbox
status=$?
set -e

echo
echo "Results written to tests/results/"
ls -la tests/results/ || true
exit "$status"
