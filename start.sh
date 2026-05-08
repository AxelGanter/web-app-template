#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

[[ -f "${ROOT_DIR}/.env" ]] && set -a && . "${ROOT_DIR}/.env" && set +a

BACKEND_HOST="${BACKEND_HOST:-localhost}"
BACKEND_PORT="${BACKEND_PORT:-8101}"
FRONTEND_HOST="${FRONTEND_HOST:-localhost}"
FRONTEND_PORT="${FRONTEND_PORT:-3101}"
LOG_DIR="${ROOT_DIR}/.logs"
PID_DIR="${ROOT_DIR}/.pids"

mkdir -p "${LOG_DIR}" "${PID_DIR}"

"${ROOT_DIR}/stop.sh" 2>/dev/null || true

echo "=== Starting Laravel backend ==="
(
  cd "${ROOT_DIR}/backend"
  nohup php artisan serve --host="${BACKEND_HOST}" --port="${BACKEND_PORT}" > "${LOG_DIR}/backend.log" 2>&1 < /dev/null &
  echo $! > "${PID_DIR}/backend.pid"
)
echo "  backend -> http://${BACKEND_HOST}:${BACKEND_PORT}"

echo
echo "=== Starting Nuxt frontend ==="
(
  cd "${ROOT_DIR}/frontend"
  nohup npm run dev -- --host "${FRONTEND_HOST}" --port "${FRONTEND_PORT}" > "${LOG_DIR}/frontend.log" 2>&1 < /dev/null &
  echo $! > "${PID_DIR}/frontend.pid"
)
echo "  frontend -> http://${FRONTEND_HOST}:${FRONTEND_PORT}"

echo
echo "Logs: ${LOG_DIR}"
