#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p tests/results

box server start serverConfigFile=server-boxlang.json

set +e
box testbox run outputFormats=json,simple,junit outputFile=tests/results/testbox
status=$?
set -e

echo
echo "Results written to tests/results/"
ls -la tests/results/ || true
exit "$status"
