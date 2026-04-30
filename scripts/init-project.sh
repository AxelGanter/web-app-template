#!/usr/bin/env bash

set -euo pipefail

# ── Paths ──
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="${ROOT_DIR}/scripts"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"

# ── Configurable defaults (override via environment) ──
LARAVEL_VERSION="${LARAVEL_VERSION:-^12.0}"
BACKEND_APP_URL="${BACKEND_APP_URL:-http://127.0.0.1:8000}"
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

# ── Helpers ──

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"; }

set_env_value() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "${file}"; then
    sed -i "s#^${key}=.*#${key}=${value}#" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file}"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { printf 'Required command not found: %s\n' "$1" >&2; exit 1; }
}

# ── Backend ──

configure_backend_env() {
  log "Configuring backend environment defaults"
  for f in "${BACKEND_DIR}/.env" "${BACKEND_DIR}/.env.example"; do
    set_env_value "$f" APP_URL "${BACKEND_APP_URL}"
    set_env_value "$f" ASSET_URL "${BACKEND_APP_URL}"
    set_env_value "$f" SESSION_DRIVER file
    set_env_value "$f" QUEUE_CONNECTION sync
    set_env_value "$f" CACHE_STORE file
    set_env_value "$f" LOG_STACK daily
  done
}

install_backpack() {
  log "Installing Backpack for Laravel"
  COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/crud:"${BACKPACK_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction

  if [[ "${INSTALL_BACKPACK_THEME}" == "1" ]]; then
    log "Installing Backpack Tabler theme"
    COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/theme-tabler:"${BACKPACK_THEME_TABLER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  fi

  php "${BACKEND_DIR}/artisan" backpack:install --no-interaction --skip-basset-check
  php "${BACKEND_DIR}/artisan" storage:link --force

  if [[ "${INSTALL_BACKPACK_THEME}" == "1" ]]; then
    php "${BACKEND_DIR}/artisan" config:clear
    php "${BACKEND_DIR}/artisan" view:clear
    php "${BACKEND_DIR}/artisan" route:list --path=admin >/dev/null
  fi
}

install_permission_manager() {
  log "Installing Backpack PermissionManager"
  COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/permissionmanager:"${PERMISSION_MANAGER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  php "${BACKEND_DIR}/artisan" vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag="permission-migrations" --no-interaction
  php "${BACKEND_DIR}/artisan" vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag="permission-config" --no-interaction
  php "${BACKEND_DIR}/artisan" vendor:publish --provider="Backpack\PermissionManager\PermissionManagerServiceProvider" --tag="config" --tag="migrations" --no-interaction
  php "${BACKEND_DIR}/artisan" migrate --force
  php "${TEMPLATE_DIR}/patch-user-model.php" "${BACKEND_DIR}/app/Models/User.php"

  log "Copying AuthorizationSeeder"
  cp "${TEMPLATE_DIR}/AuthorizationSeeder.php" "${BACKEND_DIR}/database/seeders/AuthorizationSeeder.php"
}

install_reverb() {
  log "Installing Laravel Reverb"
  php "${BACKEND_DIR}/artisan" install:broadcasting --reverb --without-node --force --no-interaction

  for f in "${BACKEND_DIR}/.env" "${BACKEND_DIR}/.env.example"; do
    set_env_value "$f" BROADCAST_CONNECTION reverb
    set_env_value "$f" REVERB_APP_ID 1001
    set_env_value "$f" REVERB_APP_KEY app-key
    set_env_value "$f" REVERB_APP_SECRET app-secret
    set_env_value "$f" REVERB_HOST 127.0.0.1
    set_env_value "$f" REVERB_PORT 8080
    set_env_value "$f" REVERB_SCHEME http
    set_env_value "$f" REVERB_SERVER_HOST 0.0.0.0
    set_env_value "$f" REVERB_SERVER_PORT 8080
  done
}

configure_backpack_disks() {
  local filesystem_config="${BACKEND_DIR}/config/filesystems.php"

  php /dev/stdin "${filesystem_config}" <<'PHP'
<?php

$path = $argv[1];
$contents = file_get_contents($path);

if (str_contains($contents, "'backups' => [")) {
    exit(0);
}

$insert = <<<'BLOCK'

        'backups' => [
            'driver' => 'local',
            'root' => storage_path('backups'),
            'throw' => false,
            'report' => false,
        ],

        'storage' => [
            'driver' => 'local',
            'root' => storage_path(),
            'throw' => false,
            'report' => false,
        ],
BLOCK;

$marker = <<<'BLOCK'
    ],

    /*
    |--------------------------------------------------------------------------
    | Symbolic Links
BLOCK;

if (! str_contains($contents, $marker)) {
    fwrite(STDERR, "Unable to find disks section in {$path}\n");
    exit(1);
}

file_put_contents($path, str_replace($marker, $insert.$marker, $contents));
PHP
}

install_backup_manager() {
  log "Installing Backpack BackupManager"
  COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/backupmanager:"${BACKUP_MANAGER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  php "${BACKEND_DIR}/artisan" vendor:publish --provider="Backpack\BackupManager\BackupManagerServiceProvider" --tag="backup-config" --tag="lang" --no-interaction
  php "${BACKEND_DIR}/artisan" backpack:add-menu-content "<x-backpack::menu-item title='Backups' icon='la la-hdd-o' :link=\"backpack_url('backup')\" />"
}

install_log_manager() {
  log "Installing Backpack LogManager"
  COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/logmanager:"${LOG_MANAGER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  php "${BACKEND_DIR}/artisan" backpack:add-menu-content "<x-backpack::menu-item title='Logs' icon='la la-terminal' :link=\"backpack_url('log')\" />"
}

# ── Frontend ──

install_frontend_dependencies() {
  log "Installing frontend dependencies with ${PACKAGE_MANAGER}"
  case "${PACKAGE_MANAGER}" in
    npm)  npm install --prefix "${FRONTEND_DIR}" ;;
    pnpm) (cd "${FRONTEND_DIR}" && pnpm install) ;;
    yarn) (cd "${FRONTEND_DIR}" && yarn install) ;;
    bun)  (cd "${FRONTEND_DIR}" && bun install) ;;
    *)    printf 'Unsupported PACKAGE_MANAGER: %s\n' "${PACKAGE_MANAGER}" >&2; exit 1 ;;
  esac
}

run_nuxt_init() {
  log "Scaffolding Nuxt in ${FRONTEND_DIR}"
  rm -rf "${FRONTEND_DIR}"
  (cd "${ROOT_DIR}" && CI=1 npx "nuxi@${NUXT_VERSION}" init frontend \
    --template "${NUXT_TEMPLATE}" --packageManager "${PACKAGE_MANAGER}" \
    --no-modules --no-install --no-gitInit)
}

# ── Shared ──

copy_shared_files() {
  local target_dir="$1"
  [[ -f "${ROOT_DIR}/AGENTS.md" ]]    && cp "${ROOT_DIR}/AGENTS.md" "${target_dir}/AGENTS.md"
  [[ -f "${ROOT_DIR}/audio2user.sh" ]] && cp "${ROOT_DIR}/audio2user.sh" "${target_dir}/audio2user.sh" && chmod +x "${target_dir}/audio2user.sh"
}

init_git_repo() {
  [[ "${INIT_GIT_REPOS}" != "1" ]] && return
  [[ ! -d "$1/.git" ]] && { log "Initializing Git repository in $1"; git -C "$1" init -q; }
}

# ── Mode: setup (project already scaffolded) ──

run_setup() {
  log "Detected existing project — installing dependencies"

  COMPOSER_ALLOW_SUPERUSER=1 composer install --working-dir="${BACKEND_DIR}" --no-interaction

  if [[ ! -f "${BACKEND_DIR}/.env" ]]; then
    log "Creating .env from .env.example"
    cp "${BACKEND_DIR}/.env.example" "${BACKEND_DIR}/.env"
    php "${BACKEND_DIR}/artisan" key:generate --no-interaction
  fi

  configure_backend_env
  install_frontend_dependencies
  log "Setup complete"
}

# ── Mode: scaffold (new project from template) ──

run_scaffold() {
  if [[ -e "${BACKEND_DIR}" || -e "${FRONTEND_DIR}" ]]; then
    if [[ "${FORCE}" != "1" ]]; then
      printf 'Refusing to overwrite existing backend/ or frontend/. Use --force to recreate.\n' >&2
      exit 1
    fi
    log "Removing existing backend/ and frontend/ (--force)"
    rm -rf "${BACKEND_DIR}" "${FRONTEND_DIR}"
  fi

  # Backend
  log "Creating Laravel app in ${BACKEND_DIR}"
  COMPOSER_ALLOW_SUPERUSER=1 composer create-project --no-interaction laravel/laravel "${BACKEND_DIR}" "${LARAVEL_VERSION}"
  configure_backend_env

  [[ "${INSTALL_BACKPACK}" == "1" ]] && install_backpack
  [[ "${INSTALL_BACKPACK}" == "1" && "${INSTALL_PERMISSION_MANAGER}" == "1" ]] && install_permission_manager
  [[ "${INSTALL_REVERB}" == "1" ]] && install_reverb
  configure_backpack_disks
  [[ "${INSTALL_BACKPACK}" == "1" && "${INSTALL_BACKUP_MANAGER}" == "1" ]] && install_backup_manager
  [[ "${INSTALL_BACKPACK}" == "1" && "${INSTALL_LOG_MANAGER}" == "1" ]] && install_log_manager

  # composer require --working-dir pollutes the root composer.json — restore it
  git -C "${ROOT_DIR}" checkout -- composer.json 2>/dev/null || true
  rm -f "${ROOT_DIR}/composer.lock" "${ROOT_DIR}/vendor" 2>/dev/null || true
  rm -rf "${ROOT_DIR}/vendor"

  copy_shared_files "${BACKEND_DIR}"
  init_git_repo "${BACKEND_DIR}"

  # Frontend
  run_nuxt_init
  install_frontend_dependencies
  copy_shared_files "${FRONTEND_DIR}"
  init_git_repo "${FRONTEND_DIR}"

  # Project-level files from templates
  log "Writing .gitignore"
  cp "${TEMPLATE_DIR}/gitignore" "${ROOT_DIR}/.gitignore"

  log "Writing .env.production.example"
  cp "${TEMPLATE_DIR}/env.production.example" "${ROOT_DIR}/.env.production.example"

  # Clean git history — template history is irrelevant
  log "Reinitializing git repository"
  rm -rf "${ROOT_DIR}/.git"
  git -C "${ROOT_DIR}" init -q
  git -C "${ROOT_DIR}" add -A
  git -C "${ROOT_DIR}" commit -q -m "Initial project scaffold"

  log "Project bootstrap complete"
  log "Next: git remote add origin <your-repo-url> && git push -u origin main"
}

# ── Main ──

require_cmd composer
require_cmd php
require_cmd git

FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    *)       printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

if [[ -d "${BACKEND_DIR}/app" && -d "${FRONTEND_DIR}/app" ]]; then
  run_setup
else
  require_cmd npx
  require_cmd "${PACKAGE_MANAGER}"
  run_scaffold
fi
