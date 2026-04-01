#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"
LARAVEL_VERSION="${LARAVEL_VERSION:-^12.0}"
NUXT_CMD="${NUXT_CMD:-npx nuxi@latest init}"
BACKPACK_VERSION="${BACKPACK_VERSION:-^6.0}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/init-project.sh [options]

Options:
  --force             Removes existing backend/frontend directories first
  --skip-backend      Skip Laravel + Backpack installation
  --skip-frontend     Skip Nuxt installation
  --no-install        Create projects only, skip dependency installation steps
  --help              Show this help

Environment variables:
  LARAVEL_VERSION     Composer constraint for laravel/laravel (default: ^12.0)
  BACKPACK_VERSION    Composer constraint for backpack/crud (default: ^6.0)
  NUXT_CMD            Command used to scaffold Nuxt (default: "npx nuxi@latest init")
EOF
}

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
  (cd "${ROOT_DIR}" && eval "${NUXT_CMD} frontend")
}

install_backpack() {
  log "Installing Backpack for Laravel"
  composer require backpack/crud:"${BACKPACK_VERSION}" --working-dir="${BACKEND_DIR}"
  php "${BACKEND_DIR}/artisan" backpack:install
}

force=0
skip_backend=0
skip_frontend=0
no_install=0

while (($# > 0)); do
  case "$1" in
    --force)
      force=1
      ;;
    --skip-backend)
      skip_backend=1
      ;;
    --skip-frontend)
      skip_frontend=1
      ;;
    --no-install)
      no_install=1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

require_cmd composer
require_cmd php
require_cmd npm
require_cmd npx

if ((force)); then
  log "Removing existing application directories"
  rm -rf "${BACKEND_DIR}" "${FRONTEND_DIR}"
fi

if ((!skip_backend)); then
  if [[ -e "${BACKEND_DIR}" ]]; then
    printf 'Refusing to overwrite existing directory: %s\n' "${BACKEND_DIR}" >&2
    exit 1
  fi

  log "Creating Laravel app in ${BACKEND_DIR}"
  composer create-project laravel/laravel "${BACKEND_DIR}" "${LARAVEL_VERSION}"

  if ((!no_install)); then
    install_backpack
  fi
fi

if ((!skip_frontend)); then
  if [[ -e "${FRONTEND_DIR}" ]]; then
    printf 'Refusing to overwrite existing directory: %s\n' "${FRONTEND_DIR}" >&2
    exit 1
  fi

  run_nuxt_init

  if ((!no_install)); then
    log "Installing frontend dependencies"
    npm install --prefix "${FRONTEND_DIR}"
  fi
fi

log "Project bootstrap complete"
