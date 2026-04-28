#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${ROOT_DIR}/backend"
FRONTEND_DIR="${ROOT_DIR}/frontend"
LARAVEL_VERSION="${LARAVEL_VERSION:-^12.0}"
BACKEND_APP_URL="${BACKEND_APP_URL:-http://127.0.0.1:8000}"
NUXT_VERSION="${NUXT_VERSION:-latest}"
BACKPACK_VERSION="${BACKPACK_VERSION:-^7.0}"
BACKPACK_THEME_TABLER_VERSION="${BACKPACK_THEME_TABLER_VERSION:-^2.0}"
PERMISSION_MANAGER_VERSION="${PERMISSION_MANAGER_VERSION:-^7.3}"
NUXT_TEMPLATE="${NUXT_TEMPLATE:-minimal}"
INIT_GIT_REPOS="${INIT_GIT_REPOS:-0}"
INSTALL_BACKPACK="${INSTALL_BACKPACK:-1}"
INSTALL_BACKPACK_THEME="${INSTALL_BACKPACK_THEME:-1}"
INSTALL_PERMISSION_MANAGER="${INSTALL_PERMISSION_MANAGER:-1}"
PACKAGE_MANAGER="${PACKAGE_MANAGER:-npm}"
ROOT_AGENTS_FILE="${ROOT_DIR}/AGENTS.md"
ROOT_AUDIO_FILE="${ROOT_DIR}/audio2user.sh"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

set_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  if grep -q "^${key}=" "${file}"; then
    sed -i "s#^${key}=.*#${key}=${value}#" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >>"${file}"
  fi
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
      --no-modules \
      --no-install \
      --no-gitInit
  )
}

configure_backend_env() {
  log "Configuring backend environment defaults"
  set_env_value "${BACKEND_DIR}/.env" APP_URL "${BACKEND_APP_URL}"
  set_env_value "${BACKEND_DIR}/.env" ASSET_URL "${BACKEND_APP_URL}"
  set_env_value "${BACKEND_DIR}/.env.example" APP_URL "${BACKEND_APP_URL}"
  set_env_value "${BACKEND_DIR}/.env.example" ASSET_URL "${BACKEND_APP_URL}"
}

install_backpack() {
  log "Installing Backpack for Laravel"
  COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/crud:"${BACKPACK_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction

  if [[ "${INSTALL_BACKPACK_THEME}" == "1" ]]; then
    log "Installing Backpack Tabler theme in backend"
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
  log "Installing Backpack PermissionManager (spatie/laravel-permission)"
  COMPOSER_ALLOW_SUPERUSER=1 composer require backpack/permissionmanager:"${PERMISSION_MANAGER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  php "${BACKEND_DIR}/artisan" vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag="permission-migrations" --no-interaction
  php "${BACKEND_DIR}/artisan" vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag="permission-config" --no-interaction
  php "${BACKEND_DIR}/artisan" vendor:publish --provider="Backpack\PermissionManager\PermissionManagerServiceProvider" --tag="config" --tag="migrations" --no-interaction
  php "${BACKEND_DIR}/artisan" migrate --force

  local user_model="${BACKEND_DIR}/app/Models/User.php"
  php -r '
    $path = $argv[1];
    $contents = file_get_contents($path);
    $contents = str_replace(
        "use Database\\Factories\\UserFactory;\n",
        "use Backpack\\CRUD\\app\\Models\\Traits\\CrudTrait;\nuse Database\\Factories\\UserFactory;\n",
        $contents
    );
    $contents = str_replace(
        "use Illuminate\\Foundation\\Auth\\User as Authenticatable;\n",
        "use Illuminate\\Foundation\\Auth\\User as Authenticatable;\nuse Spatie\\Permission\\Traits\\HasRoles;\n",
        $contents
    );
    $contents = str_replace(
        "use HasFactory, Notifiable;",
        "use CrudTrait, HasFactory, HasRoles, Notifiable;",
        $contents
    );
    file_put_contents($path, $contents);
  ' "${user_model}"
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

rewrite_gitignore() {
  log "Rewriting .gitignore for project repository"
  cat > "${ROOT_DIR}/.gitignore" << 'GITIGNORE'
.DS_Store
.env
.env.*
!.env.example
!.env.production.example
.idea/
.vscode/

/vendor/
/node_modules/

/backend/.env
/backend/vendor/
/backend/node_modules/
/backend/public/build/
/backend/public/hot
/backend/public/storage
/backend/storage/*.key
/backend/storage/pail/
/backend/database/*.sqlite

/frontend/node_modules/
/frontend/.nuxt/
/frontend/.output/
/frontend/.data/
/frontend/.nitro/
/frontend/.cache/
/frontend/dist/
GITIGNORE
}

generate_admin_seeder() {
  log "Generating AuthorizationSeeder with admin provisioning"
  cat > "${BACKEND_DIR}/database/seeders/AuthorizationSeeder.php" << 'SEEDER'
<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class AuthorizationSeeder extends Seeder
{
    public function run(): void
    {
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        $this->ensureInitialAdmin();
    }

    private function ensureInitialAdmin(): void
    {
        $email = env('CCC_ADMIN_EMAIL', 'admin@example.com');
        $password = env('CCC_ADMIN_PASSWORD');

        $attributes = [
            'name' => env('CCC_ADMIN_NAME', 'Admin'),
            'email_verified_at' => now(),
        ];

        if ($password !== null && $password !== '') {
            $attributes['password'] = Hash::make($password);
        }

        $user = User::firstOrCreate(
            ['email' => $email],
            $attributes + ['password' => Hash::make(str()->password(32))]
        );

        if (! $user->wasRecentlyCreated) {
            $user->forceFill($attributes)->save();
        }
    }
}
SEEDER
}

generate_env_production_example() {
  log "Generating .env.production.example"
  cat > "${ROOT_DIR}/.env.production.example" << 'ENVPROD'
# Production environment template.
# Copy to backend/.env and fill in the values for your deployment.

APP_NAME="My App"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://example.com
APP_TIMEZONE=Europe/Berlin

BACKPACK_REGISTRATION_OPEN=false

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=warning

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=myapp
DB_USERNAME=myapp
DB_PASSWORD=

BROADCAST_CONNECTION=log
CACHE_STORE=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MAIL_MAILER=smtp
MAIL_HOST=localhost
MAIL_PORT=25
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="${APP_NAME}"

# Initial admin user (used by AuthorizationSeeder during first deploy)
# CCC_ADMIN_NAME="Admin"
# CCC_ADMIN_EMAIL=admin@example.com
# CCC_ADMIN_PASSWORD=changeme
ENVPROD
}

require_cmd composer
require_cmd php
require_cmd npx
require_cmd git
require_cmd "${PACKAGE_MANAGER}"

FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -e "${BACKEND_DIR}" || -e "${FRONTEND_DIR}" ]]; then
  if [[ "${FORCE}" != "1" ]]; then
    printf 'Refusing to overwrite existing backend/ or frontend/ directory. Use --force to recreate them.\n' >&2
    exit 1
  fi

  log "Removing existing backend/ and frontend/ because --force was requested"
  rm -rf "${BACKEND_DIR}" "${FRONTEND_DIR}"
fi

log "Creating Laravel app in ${BACKEND_DIR}"
COMPOSER_ALLOW_SUPERUSER=1 composer create-project --no-interaction laravel/laravel "${BACKEND_DIR}" "${LARAVEL_VERSION}"
configure_backend_env

if [[ "${INSTALL_BACKPACK}" == "1" ]]; then
  install_backpack
fi

if [[ "${INSTALL_BACKPACK}" == "1" && "${INSTALL_PERMISSION_MANAGER}" == "1" ]]; then
  install_permission_manager
  generate_admin_seeder
fi

copy_shared_files "${BACKEND_DIR}"
init_git_repo "${BACKEND_DIR}"

run_nuxt_init

install_frontend_dependencies
copy_shared_files "${FRONTEND_DIR}"
init_git_repo "${FRONTEND_DIR}"

rewrite_gitignore
generate_env_production_example

# Reinitialize git — the template history is irrelevant for the new project
log "Reinitializing git repository (clean slate, no template history)"
rm -rf "${ROOT_DIR}/.git"
git -C "${ROOT_DIR}" init -q
git -C "${ROOT_DIR}" add -A
git -C "${ROOT_DIR}" commit -q -m "Initial project scaffold"

log "Project bootstrap complete"
log "Next: git remote add origin <your-repo-url> && git push -u origin main"
