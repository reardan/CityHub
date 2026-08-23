#!/usr/bin/env bash
# Run a CityHub dedicated match and capture script stderr.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TTD_ROOT="$(cd "${ROOT}/.." && pwd)"
BIN="${OPENTTD_BIN:-${TTD_ROOT}/OpenTTD/build/openttd}"
SEED="${SEED:-12345}"
YEARS="${YEARS:-2}"
OPPONENT="${OPPONENT:-AAAHogEx}"
OUT_DIR="${OUT_DIR:-${ROOT}/bench/out}"
MATCH="${MATCH:-cityhub-vs-${OPPONENT}-${YEARS}yr}"
TICKS_PER_DAY=74

if [[ ! -x "${BIN}" ]]; then
  echo "OpenTTD binary not found: ${BIN}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
STAGE_AI="$(dirname "${BIN}")/ai"
STAGE_GS="$(dirname "${BIN}")/game"
mkdir -p "${STAGE_AI}" "${STAGE_GS}"

AI_PKG="$("${ROOT}/bench/stage_ai.sh")"
ln -sfn "${AI_PKG}" "${STAGE_AI}/CityHub"
if [[ -d "${TTD_ROOT}/AAAHogEx" ]]; then
  ln -sfn "${TTD_ROOT}/AAAHogEx" "${STAGE_AI}/AAAHogEx"
fi
if [[ -n "${OPPONENT}" && "${OPPONENT}" != "AAAHogEx" && -d "${TTD_ROOT}/${OPPONENT}" ]]; then
  ln -sfn "${TTD_ROOT}/${OPPONENT}" "${STAGE_AI}/${OPPONENT}"
fi
ln -sfn "${ROOT}/bench/gamescript" "${STAGE_GS}/CityHubBench"

USER_AI="${HOME}/.local/share/openttd/ai"
USER_GS="${HOME}/.local/share/openttd/game"
mkdir -p "${USER_AI}" "${USER_GS}"
ln -sfn "${AI_PKG}" "${USER_AI}/CityHub"
ln -sfn "${ROOT}/bench/gamescript" "${USER_GS}/CityHubBench"
if [[ -d "${TTD_ROOT}/AAAHogEx" ]]; then
  ln -sfn "${TTD_ROOT}/AAAHogEx" "${USER_AI}/AAAHogEx"
fi

CFG="$(mktemp "${OUT_DIR}/match-${SEED}-XXXX.cfg")"
cat > "${CFG}" <<EOF
[misc]
language = english.lng

[gui]
autosave = off
pause_on_newgame = false

[ai]
ai_in_multiplayer = true

[network]
pause_on_join = false

[difficulty]
max_no_competitors = 2
competitors_interval = 0
vehicle_breakdowns = 0

[game_creation]
town_name = english
starting_year = 1970
generation_seed = ${SEED}
map_x = 8
map_y = 8
landscape = temperate

[game_scripts]
CityHubBench = cut_year_offset=${YEARS}

[ai_players]
CityHub =
${OPPONENT} =
EOF

TICKS=$((YEARS * 366 * TICKS_PER_DAY + 120 * TICKS_PER_DAY))
LOG="${OUT_DIR}/${MATCH}-${SEED}.log"
echo "Running ${MATCH} seed=${SEED} years=${YEARS} ticks=${TICKS}"
set +e
"${BIN}" -x -c "${CFG}" -g -snull -mnull -vnull:ticks="${TICKS}" -d script=4 \
  >"${LOG}" 2>&1
STATUS=$?
set -e
echo "exit=${STATUS} log=${LOG}"
python3 "${ROOT}/bench/parse_log.py" "${LOG}" --out "${OUT_DIR}/${MATCH}-${SEED}.csv"
exit "${STATUS}"
