#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"
LARAVEL_VERSION="${LARAVEL_VERSION:-^12.0}"
NUXT_VERSION="${NUXT_VERSION:-latest}"
BACKPACK_VERSION="${BACKPACK_VERSION:-^6.0}"
NUXT_TEMPLATE="${NUXT_TEMPLATE:-minimal}"
INIT_GIT_REPOS="${INIT_GIT_REPOS:-0}"
INSTALL_BACKPACK="${INSTALL_BACKPACK:-1}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"
ROOT_AGENTS_FILE="${ROOT_DIR}/AGENTS.md"
ROOT_AUDIO_FILE="${ROOT_DIR}/audio2user.sh"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

install_frontend_dependencies() {
  log "Installing frontend dependencies with ${PACKAGE_MANAGER}"

  case "${PACKAGE_MANAGER}" in
    npm)
      npm install --prefix "${FRONTEND_DIR}"
      ;;
    pnpm)
      (cd "${FRONTEND_DIR}" && pnpm install)
      ;;
    yarn)
      (cd "${FRONTEND_DIR}" && yarn install)
      ;;
    bun)
      (cd "${FRONTEND_DIR}" && bun install)
      ;;
    *)
      printf 'Unsupported PACKAGE_MANAGER: %s\n' "${PACKAGE_MANAGER}" >&2
      exit 1
      ;;
  esac
}

run_nuxt_init() {
  log "Scaffolding Nuxt in ${FRONTEND_DIR}"
  (
    cd "${ROOT_DIR}" && \
    CI=1 npx "nuxi@${NUXT_VERSION}" init frontend \
      --template "${NUXT_TEMPLATE}" \
      --packageManager "${PACKAGE_MANAGER}" \
      --no-install \
      --no-gitInit
  )
}

install_backpack() {
  log "Installing Backpack for Laravel"
  COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/crud:"${BACKPACK_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  php "${BACKEND_DIR}/artisan" backpack:install --no-interaction --skip-basset-check
}

copy_shared_files() {
  local target_dir="$1"

  if [[ -f "${ROOT_AGENTS_FILE}" ]]; then
    cp "${ROOT_AGENTS_FILE}" "${target_dir}/AGENTS.md"
  fi

  if [[ -f "${ROOT_AUDIO_FILE}" ]]; then
    cp "${ROOT_AUDIO_FILE}" "${target_dir}/audio2user.sh"
    chmod +x "${target_dir}/audio2user.sh"
  fi
}

init_git_repo() {
  local target_dir="$1"

  if [[ "${INIT_GIT_REPOS}" != "1" ]]; then
    return
  fi

  if [[ ! -d "${target_dir}/.git" ]]; then
    log "Initializing Git repository in ${target_dir}"
    git -C "${target_dir}" init -q
  fi
}

require_cmd composer
require_cmd php
require_cmd npx
require_cmd git
require_cmd "${PACKAGE_MANAGER}"

if [[ $# -gt 0 ]]; then
  printf 'This script does not accept arguments.\n' >&2
  exit 1
fi

if [[ -e "${BACKEND_DIR}" || -e "${FRONTEND_DIR}" ]]; then
  printf 'Refusing to overwrite existing backend/ or frontend/ directory.\n' >&2
  exit 1
fi

log "Creating Laravel app in ${BACKEND_DIR}"
COMPOSER_ALLOW_SUPERUSER=1 composer create-project --no-interaction laravel/laravel "${BACKEND_DIR}" "${LARAVEL_VERSION}"

if [[ "${INSTALL_BACKPACK}" == "1" ]]; then
  install_backpack
fi

copy_shared_files "${BACKEND_DIR}"
init_git_repo "${BACKEND_DIR}"

run_nuxt_init

install_frontend_dependencies
copy_shared_files "${FRONTEND_DIR}"
init_git_repo "${FRONTEND_DIR}"

log "Project bootstrap complete"
