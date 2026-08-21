#!/usr/bin/env bash

##
## ./run-tests.sh --- run locally
## act -j tests   --- run github "tests" action locally via "act" (install act via ./get-act.sh)
##

set -euo pipefail
cd "$(dirname "$0")"

mkdir -p tests/results tests/docker/creds

if [[
	("${CI:-}" == "" && "${ACT:-}" == "") #local runner
	|| ("${ACT:-}" != "") # ACT runner
]]; then
	# have to kill the existing local container, if it exists;
	# otherwise we won't get a "fresh boot" meaning we won't get
	# the test api key written out. In actual CI we assume there simply
	# cannot be currently running container to tear down.
	echo "ACT runner tearing down listmonk container (if running)"
	docker compose --project-directory tests/docker down -v
fi

echo "==> Starting Listmonk (docker compose)"
if ! docker compose --project-directory tests/docker up -d --wait --wait-timeout 180; then
	echo "Listmonk failed to become healthy" >&2
	docker compose --project-directory tests/docker ps -a >&2 || true
	docker compose --project-directory tests/docker logs >&2 || true
	exit 1
fi

# the most recent "full restart" of the listmonk server should have written test api creds here
creds="tests/docker/creds/api.json.env"

if [[ ! -f "$creds" ]]; then
	echo "Listmonk credentials were not written to $creds" >&2
	docker compose --project-directory tests/docker logs >&2 || true
	exit 1
fi

echo "==> Starting BoxLang server"
if [[
	("${CI:-}" == "" && "${ACT:-}" == "") #local runner
	|| ("${ACT:-}" != "") # ACT runner
]]; then
	# "local" runner -- stop the server if it's running, to ensure we restart with fresh api credential
	# (maybe faster -- we might be able to just "framework reinit" the server?)
	server_status=$(box server status serverConfigFile=server-boxlang.json property=status 2>/dev/null || true)
	if [[ "$server_status" == "running" ]]; then
		echo "stopping current server" # I guess we could restart it?...
		box server stop serverConfigFile=server-boxlang.json
	fi
	# probably don't need to do this in "local runner",
	# but in ACT it seems we can accumulate servers and get an error like the following:
	# | You've asked to start a server named [listmonk-boxlang] with a webroot of [/home/david/.cache/act/0004128eed75dd1f/hostexecutor/],
	# | but a server of this name already exists with a different webroot of [/home/david/rmme/listmonk-module/]
	# | Server name and webroot must be unique.  Please forget the old server first.  Use "server list" to see all defined servers.

	# TODO: apparently using serverConfigFile=server-boxlang.json here might be wrong,
	# because it might try to remove server "listmonk-boxlang2" if there are multiple
	# started against this serverConfigFile; which I guess shouldn't be a state
	# we can enter, but maybe does during dev and we get errors after server-start
	# but before server-stop?
	box server forget name=listmonk-boxlang --force
fi

box server start serverConfigFile=server-boxlang.json

set +e
echo "==> Running TestBox"
box testbox run runner=http://127.0.0.1:60299/runner.cfm outputFormats=json,simple,junit outputFile=tests/results/testbox
status=$?
set -e

echo
echo "Results written to tests/results/"
ls -la tests/results/ || true
exit "$status"
