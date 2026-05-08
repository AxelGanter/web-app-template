#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="${ROOT_DIR}/scripts"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"

load_root_env() {
  local env_file="${ROOT_DIR}/.env"
  [[ -f "${env_file}" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  . "${env_file}"
  set +a
}

load_root_env

LARAVEL_VERSION="${LARAVEL_VERSION:-^12.0}"
BACKEND_HOST="${BACKEND_HOST:-localhost}"
BACKEND_PORT="${BACKEND_PORT:-8101}"
FRONTEND_HOST="${FRONTEND_HOST:-localhost}"
FRONTEND_PORT="${FRONTEND_PORT:-3101}"
BACKEND_APP_URL="${BACKEND_APP_URL:-http://${BACKEND_HOST}:${BACKEND_PORT}}"
FRONTEND_APP_URL="${FRONTEND_APP_URL:-http://${FRONTEND_HOST}:${FRONTEND_PORT}}"
NUXT_VERSION="${NUXT_VERSION:-latest}"
BACKPACK_VERSION="${BACKPACK_VERSION:-^7.0}"
BACKPACK_THEME_TABLER_VERSION="${BACKPACK_THEME_TABLER_VERSION:-^2.0}"
PERMISSION_MANAGER_VERSION="${PERMISSION_MANAGER_VERSION:-^7.3}"
BACKUP_MANAGER_VERSION="${BACKUP_MANAGER_VERSION:-^5.1}"
LOG_MANAGER_VERSION="${LOG_MANAGER_VERSION:-^5.1}"
NUXT_TEMPLATE="${NUXT_TEMPLATE:-minimal}"
INIT_GIT_REPOS="${INIT_GIT_REPOS:-0}"
INSTALL_BACKPACK="${INSTALL_BACKPACK:-1}"
INSTALL_BACKPACK_THEME="${INSTALL_BACKPACK_THEME:-1}"
INSTALL_PERMISSION_MANAGER="${INSTALL_PERMISSION_MANAGER:-1}"
INSTALL_BACKUP_MANAGER="${INSTALL_BACKUP_MANAGER:-1}"
INSTALL_LOG_MANAGER="${INSTALL_LOG_MANAGER:-1}"
INSTALL_REVERB="${INSTALL_REVERB:-1}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"; }

set_env_value() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "${file}"; then
    sed -i "s#^${key}=.*#${key}=${value}#" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file}"
  fi
}

set_php_config_value() {
  local file="$1" search="$2" replace="$3"
  php -r '
    $file = $argv[1];
    $search = $argv[2];
    $replace = $argv[3];
    $contents = file_get_contents($file);
    if ($contents === false) {
        fwrite(STDERR, "Unable to read {$file}\n");
        exit(1);
    }
    $updated = preg_replace($search, $replace, $contents, 1);
    if ($updated === null) {
        fwrite(STDERR, "Regex error while updating {$file}\n");
        exit(1);
    }
    if ($updated !== $contents) {
        file_put_contents($file, $updated);
    }
  ' "$file" "$search" "$replace"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  }
}

copy_template_tree() {
  local source_dir="$1" target_dir="$2"
  [[ -d "${source_dir}" ]] || return 0
  mkdir -p "${target_dir}"
  cp -R "${source_dir}/." "${target_dir}/"
}

source "${SCRIPT_DIR}/lib/shared.sh"
source "${SCRIPT_DIR}/lib/backend-auth.sh"
source "${SCRIPT_DIR}/lib/backpack.sh"
source "${SCRIPT_DIR}/lib/frontend.sh"

run_setup() {
  log "Detected existing project — installing dependencies"

  COMPOSER_ALLOW_SUPERUSER=1 composer install --working-dir="${BACKEND_DIR}" --no-interaction

  if [[ ! -f "${BACKEND_DIR}/.env" ]]; then
    log "Creating .env from .env.example"
    cp "${BACKEND_DIR}/.env.example" "${BACKEND_DIR}/.env"
    php "${BACKEND_DIR}/artisan" key:generate --no-interaction
  fi

  install_api_stack
  configure_backend_env
  install_template_auth_backend
  configure_frontend_package
  install_template_frontend_scaffold
  configure_frontend_env
  configure_root_env
  php "${BACKEND_DIR}/artisan" storage:link --force
  install_frontend_dependencies
  log "Setup complete"
}

run_scaffold() {
  if [[ -e "${BACKEND_DIR}" || -e "${FRONTEND_DIR}" ]]; then
    if [[ "${FORCE}" != "1" ]]; then
      printf 'Refusing to overwrite existing backend/ or frontend/. Use --force to recreate.\n' >&2
      exit 1
    fi
    log "Removing existing backend/ and frontend/ (--force)"
    rm -rf "${BACKEND_DIR}" "${FRONTEND_DIR}"
  fi

  log "Creating Laravel app in ${BACKEND_DIR}"
  COMPOSER_ALLOW_SUPERUSER=1 composer create-project --no-interaction laravel/laravel "${BACKEND_DIR}" "${LARAVEL_VERSION}"
  install_api_stack
  configure_backend_env
  install_template_auth_backend

  [[ "${INSTALL_BACKPACK}" == "1" ]] && install_backpack
  [[ "${INSTALL_BACKPACK}" == "1" && "${INSTALL_PERMISSION_MANAGER}" == "1" ]] && install_permission_manager
  [[ "${INSTALL_REVERB}" == "1" ]] && install_reverb
  configure_backpack_disks
  [[ "${INSTALL_BACKPACK}" == "1" && "${INSTALL_BACKUP_MANAGER}" == "1" ]] && install_backup_manager
  [[ "${INSTALL_BACKPACK}" == "1" && "${INSTALL_LOG_MANAGER}" == "1" ]] && install_log_manager

  git -C "${ROOT_DIR}" checkout -- composer.json 2>/dev/null || true
  rm -f "${ROOT_DIR}/composer.lock"
  rm -rf "${ROOT_DIR}/vendor"

  copy_shared_files "${BACKEND_DIR}"
  init_git_repo "${BACKEND_DIR}"

  run_nuxt_init
  configure_frontend_package
  install_template_frontend_scaffold
  configure_frontend_env
  install_frontend_dependencies
  copy_shared_files "${FRONTEND_DIR}"
  init_git_repo "${FRONTEND_DIR}"

  log "Writing .gitignore"
  cp "${TEMPLATE_DIR}/gitignore" "${ROOT_DIR}/.gitignore"

  log "Writing .env.production.example"
  cp "${TEMPLATE_DIR}/env.production.example" "${ROOT_DIR}/.env.production.example"
  configure_root_env

  log "Reinitializing git repository"
  rm -rf "${ROOT_DIR}/.git"
  git -C "${ROOT_DIR}" init -q
  git -C "${ROOT_DIR}" add -A
  git -C "${ROOT_DIR}" commit -q -m "Initial project scaffold"

  log "Project bootstrap complete"
  log "Next: git remote add origin <your-repo-url> && git push -u origin main"
}

require_cmd composer
require_cmd php
require_cmd git

FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [[ -d "${BACKEND_DIR}/app" && -d "${FRONTEND_DIR}/app" ]]; then
  run_setup
else
  require_cmd npx
  require_cmd "${PACKAGE_MANAGER}"
  run_scaffold
fi
