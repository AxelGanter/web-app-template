#!/usr/bin/env bash

configure_root_env() {
  log "Writing root .env.example"
  local target="${1:-${ROOT_DIR}/.env.example}"
  cat > "${target}" <<EOF
BACKEND_HOST=${BACKEND_HOST}
BACKEND_PORT=${BACKEND_PORT}
FRONTEND_HOST=${FRONTEND_HOST}
FRONTEND_PORT=${FRONTEND_PORT}
BACKEND_APP_URL=${BACKEND_APP_URL}
FRONTEND_APP_URL=${FRONTEND_APP_URL}
EOF

  [[ -f "${ROOT_DIR}/.env" ]] || run_cmd cp "${ROOT_DIR}/.env.example" "${ROOT_DIR}/.env"
}

copy_shared_files() {
  local target_dir="$1"
  [[ -f "${ROOT_DIR}/AGENTS.md" ]] && run_cmd cp "${ROOT_DIR}/AGENTS.md" "${target_dir}/AGENTS.md"
  if [[ -f "${ROOT_DIR}/audio2user.sh" ]]; then
    run_cmd cp "${ROOT_DIR}/audio2user.sh" "${target_dir}/audio2user.sh"
    run_cmd chmod +x "${target_dir}/audio2user.sh"
  fi
}

init_git_repo() {
  [[ "${INIT_GIT_REPOS}" != "1" ]] && return
  [[ ! -d "$1/.git" ]] && { log "Initializing Git repository in $1"; run_cmd git -C "$1" init -q; }
}
