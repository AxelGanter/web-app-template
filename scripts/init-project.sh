#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"
LARAVEL_VERSION="${LARAVEL_VERSION:-^12.0}"
NUXT_VERSION="${NUXT_VERSION:-latest}"
BACKPACK_VERSION="${BACKPACK_VERSION:-^6.0}"
ROOT_AGENTS_FILE="${ROOT_DIR}/AGENTS.md"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

run_nuxt_init() {
  log "Scaffolding Nuxt in ${FRONTEND_DIR}"
  (cd "${ROOT_DIR}" && npx "nuxi@${NUXT_VERSION}" init frontend)
}

install_backpack() {
  log "Installing Backpack for Laravel"
  composer require backpack/crud:"${BACKPACK_VERSION}" --working-dir="${BACKEND_DIR}"
  php "${BACKEND_DIR}/artisan" backpack:install
}

copy_agents_file() {
  local target_dir="$1"

  if [[ -f "${ROOT_AGENTS_FILE}" ]]; then
    cp "${ROOT_AGENTS_FILE}" "${target_dir}/AGENTS.md"
  fi
}

init_git_repo() {
  local target_dir="$1"

  if [[ ! -d "${target_dir}/.git" ]]; then
    log "Initializing Git repository in ${target_dir}"
    git -C "${target_dir}" init -q
  fi
}

require_cmd composer
require_cmd php
require_cmd npm
require_cmd npx
require_cmd git

if [[ $# -gt 0 ]]; then
  printf 'This script does not accept arguments.\n' >&2
  exit 1
fi

if [[ -e "${BACKEND_DIR}" || -e "${FRONTEND_DIR}" ]]; then
  printf 'Refusing to overwrite existing backend/ or frontend/ directory.\n' >&2
  exit 1
fi

log "Creating Laravel app in ${BACKEND_DIR}"
composer create-project laravel/laravel "${BACKEND_DIR}" "${LARAVEL_VERSION}"
install_backpack
copy_agents_file "${BACKEND_DIR}"
init_git_repo "${BACKEND_DIR}"

run_nuxt_init

log "Installing frontend dependencies"
npm install --prefix "${FRONTEND_DIR}"
copy_agents_file "${FRONTEND_DIR}"
init_git_repo "${FRONTEND_DIR}"

log "Project bootstrap complete"
