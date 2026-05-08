#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${ROOT_DIR}/.pids"

stop_pid_file() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  local pid
  pid="$(cat "${file}")"
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}"
    echo "Stopped PID ${pid}"
  fi
  rm -f "${file}"
}

stop_pid_file "${PID_DIR}/backend.pid"
stop_pid_file "${PID_DIR}/frontend.pid"
