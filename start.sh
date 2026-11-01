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

wait_for_port() {
  local name="$1" host="$2" port="$3" log_file="$4" pid_file="$5"
  local attempt

  for attempt in $(seq 1 40); do
    if [[ ! -s "${pid_file}" ]] || ! kill -0 "$(cat "${pid_file}")" 2>/dev/null; then
      echo "  ${name} process exited before becoming ready" >&2
      [[ -s "${log_file}" ]] && tail -n 40 "${log_file}" >&2
      return 1
    fi
    if php -r '$s = @fsockopen($argv[1], (int) $argv[2], $errno, $errstr, 0.25); if ($s) { fclose($s); exit(0); } exit(1);' "${host}" "${port}"; then
      echo "  ${name} ready -> http://${host}:${port}"
      return 0
    fi
    sleep 0.25
  done

  echo "  ${name} did not become ready on ${host}:${port}" >&2
  if [[ -s "${log_file}" ]]; then
    echo "  Last ${name} log lines:" >&2
    tail -n 40 "${log_file}" >&2
  fi
  return 1
}

assert_port_free() {
  local name="$1" host="$2" port="$3"
  if php -r '$s = @fsockopen($argv[1], (int) $argv[2], $errno, $errstr, 0.25); if ($s) { fclose($s); exit(0); } exit(1);' "${host}" "${port}"; then
    echo "  ${name} port ${host}:${port} is already in use" >&2
    return 1
  fi
}

"${ROOT_DIR}/stop.sh" 2>/dev/null || true

assert_port_free "backend" "${BACKEND_HOST}" "${BACKEND_PORT}"
assert_port_free "frontend" "${FRONTEND_HOST}" "${FRONTEND_PORT}"

echo "=== Starting Laravel backend ==="
(
  cd "${ROOT_DIR}/backend"
  nohup php artisan serve --host="${BACKEND_HOST}" --port="${BACKEND_PORT}" > "${LOG_DIR}/backend.log" 2>&1 < /dev/null &
  echo $! > "${PID_DIR}/backend.pid"
)
wait_for_port "backend" "${BACKEND_HOST}" "${BACKEND_PORT}" "${LOG_DIR}/backend.log" "${PID_DIR}/backend.pid"

echo
echo "=== Starting Nuxt frontend ==="
(
  cd "${ROOT_DIR}/frontend"
  nohup npm run dev -- --host "${FRONTEND_HOST}" --port "${FRONTEND_PORT}" > "${LOG_DIR}/frontend.log" 2>&1 < /dev/null &
  echo $! > "${PID_DIR}/frontend.pid"
)
wait_for_port "frontend" "${FRONTEND_HOST}" "${FRONTEND_PORT}" "${LOG_DIR}/frontend.log" "${PID_DIR}/frontend.pid"

echo
echo "Logs: ${LOG_DIR}"
