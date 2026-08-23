#!/usr/bin/env bash
# Stage only AI *.nut files so OpenTTD does not load bench/gamescript as an AI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="${1:-${ROOT}/.stage/CityHub}"

mkdir -p "${STAGE}/path"
for name in info.nut main.nut log.nut cargo.nut settings.nut finance.nut \
	construction.nut events.nut towns.nut vehicles.nut air.nut bus.nut \
	rail.nut longterm.nut; do
	ln -sfn "${ROOT}/${name}" "${STAGE}/${name}"
done
for name in astar.nut cache.nut rail.nut road.nut; do
	ln -sfn "${ROOT}/path/${name}" "${STAGE}/path/${name}"
done
echo "${STAGE}"
