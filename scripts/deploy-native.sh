#!/usr/bin/env bash
set -euo pipefail

REF="${1:-}"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="${APP_DIR}/backend"
FRONTEND_DIR="${APP_DIR}/frontend"
APP_RUNTIME_USER="${APP_RUNTIME_USER:-www-data}"
APP_RUNTIME_GROUP="${APP_RUNTIME_GROUP:-${APP_RUNTIME_USER}}"
SHARED_DIR="${SHARED_DIR:-$(cd "${APP_DIR}/.." && pwd)/shared}"
CACHE_ROOT="${CACHE_ROOT:-${SHARED_DIR}/.cache}"
COMPOSER_HOME_DIR="${COMPOSER_HOME_DIR:-${CACHE_ROOT}/composer/home}"
COMPOSER_CACHE_DIR="${COMPOSER_CACHE_DIR:-${CACHE_ROOT}/composer/cache}"
NPM_CACHE_DIR="${NPM_CACHE_DIR:-${CACHE_ROOT}/npm}"

cd "${APP_DIR}"

reexec_as_runtime_user() {
  if [[ "${EUID}" -ne 0 || "${APP_RUNTIME_USER}" == "root" ]]; then
    return 0
  fi

  if ! id "${APP_RUNTIME_USER}" >/dev/null 2>&1; then
    echo "Runtime user ${APP_RUNTIME_USER} does not exist" >&2
    exit 1
  fi

  local runtime_home
  runtime_home="$(getent passwd "${APP_RUNTIME_USER}" | cut -d: -f6)"
  runtime_home="${runtime_home:-/var/www}"

  exec runuser -u "${APP_RUNTIME_USER}" -- env \
    HOME="${runtime_home}" \
    USER="${APP_RUNTIME_USER}" \
    LOGNAME="${APP_RUNTIME_USER}" \
    APP_RUNTIME_USER="${APP_RUNTIME_USER}" \
    APP_RUNTIME_GROUP="${APP_RUNTIME_GROUP}" \
    SHARED_DIR="${SHARED_DIR}" \
    CACHE_ROOT="${CACHE_ROOT}" \
    COMPOSER_HOME_DIR="${COMPOSER_HOME_DIR}" \
    COMPOSER_CACHE_DIR="${COMPOSER_CACHE_DIR}" \
    NPM_CACHE_DIR="${NPM_CACHE_DIR}" \
    BUILD_FRONTEND="${BUILD_FRONTEND:-0}" \
    PATH="${PATH}" \
    bash "$0" "${REF}"
}

normalize_permissions() {
  local ownership_targets=(
    "${APP_DIR}"
    "${BACKEND_DIR}/storage"
    "${BACKEND_DIR}/bootstrap/cache"
  )
  local root_dirs=(
    "${APP_DIR}"
    "${BACKEND_DIR}"
    "${BACKEND_DIR}/storage"
    "${BACKEND_DIR}/bootstrap/cache"
  )
  local recursive_dirs=(
    "${BACKEND_DIR}/storage"
    "${BACKEND_DIR}/bootstrap/cache"
  )
  local writable_file_roots=(
    "${BACKEND_DIR}/storage"
    "${BACKEND_DIR}/bootstrap/cache"
  )

  if [[ -d "${FRONTEND_DIR}" ]]; then
    ownership_targets+=("${FRONTEND_DIR}")
    root_dirs+=("${FRONTEND_DIR}")
  fi

  if [[ -d "${SHARED_DIR}" ]]; then
    ownership_targets+=("${SHARED_DIR}")
    root_dirs+=("${SHARED_DIR}")
    recursive_dirs+=("${SHARED_DIR}")
    writable_file_roots+=("${SHARED_DIR}")
  fi

  for target in "${ownership_targets[@]}"; do
    [[ -e "${target}" ]] || continue
    if [[ "${EUID}" -eq 0 ]]; then
      chown -R "${APP_RUNTIME_USER}:${APP_RUNTIME_GROUP}" "${target}"
    fi
  done

  for target in "${root_dirs[@]}"; do
    [[ -d "${target}" ]] || continue
    chmod 2775 "${target}"
  done

  for target in "${recursive_dirs[@]}"; do
    [[ -d "${target}" ]] || continue
    find "${target}" -type d -exec chmod 2775 {} +
  done

  for target in "${writable_file_roots[@]}"; do
    [[ -d "${target}" ]] || continue
    find "${target}" -type f -exec chmod 664 {} +
  done

  [[ -f "${BACKEND_DIR}/.env" ]] && chmod 640 "${BACKEND_DIR}/.env"
  [[ -f "${BACKEND_DIR}/artisan" ]] && chmod 775 "${BACKEND_DIR}/artisan"

  if [[ -d "${APP_DIR}/scripts" ]]; then
    find "${APP_DIR}/scripts" -type f -name '*.sh' -exec chmod 775 {} +
  fi

  if [[ -d "${BACKEND_DIR}/bin" ]]; then
    find "${BACKEND_DIR}/bin" -type f -exec chmod 775 {} +
  fi

  [[ -f "${APP_DIR}/audio2user.sh" ]] && chmod 775 "${APP_DIR}/audio2user.sh"
}

reexec_as_runtime_user

# Ensure Node.js >= 22 (Vite 7+ requires >= 20.19)
NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [[ -z "${NODE_MAJOR}" || "${NODE_MAJOR}" -lt 22 ]]; then
  echo "Node.js >= 22 is required (found: $(node -v 2>/dev/null || echo 'none'))" >&2
  exit 1
fi

if [[ -n "${REF}" && -d .git ]]; then
  git fetch origin --tags --prune

  if git show-ref --verify --quiet "refs/remotes/origin/${REF}"; then
    git checkout -B "${REF}" "origin/${REF}"
    git pull --ff-only origin "${REF}"
  else
    git checkout --detach "${REF}"
  fi
fi

if [[ ! -f "${BACKEND_DIR}/.env" ]]; then
  echo "Missing ${BACKEND_DIR}/.env" >&2
  exit 1
fi

ARTISAN_ENV=(
  env -i
  HOME="${HOME}"
  USER="${USER}"
  LOGNAME="${LOGNAME}"
  PATH="${PATH}"
  SHELL="${SHELL:-/bin/bash}"
  COMPOSER_HOME="${COMPOSER_HOME_DIR}"
  COMPOSER_CACHE_DIR="${COMPOSER_CACHE_DIR}"
  npm_config_cache="${NPM_CACHE_DIR}"
)

mkdir -p "${COMPOSER_HOME_DIR}" "${COMPOSER_CACHE_DIR}" "${NPM_CACHE_DIR}"

install_npm_dependencies() {
  local prefix="$1"

  if [[ -f "${prefix}/package-lock.json" ]]; then
    if npm ci --prefix "${prefix}" --cache "${NPM_CACHE_DIR}"; then
      return 0
    fi
  fi

  npm install --prefix "${prefix}" --cache "${NPM_CACHE_DIR}"
}

composer install \
  --working-dir="${BACKEND_DIR}" \
  --no-dev \
  --optimize-autoloader \
  --no-interaction

install_npm_dependencies "${BACKEND_DIR}"
npm run build --prefix "${BACKEND_DIR}"

(
  cd "${BACKEND_DIR}"
  "${ARTISAN_ENV[@]}" php artisan package:discover --ansi
  "${ARTISAN_ENV[@]}" php artisan storage:link --relative --force || true
  "${ARTISAN_ENV[@]}" php artisan config:clear
  "${ARTISAN_ENV[@]}" php artisan route:clear
  "${ARTISAN_ENV[@]}" php artisan view:clear
  "${ARTISAN_ENV[@]}" php artisan migrate --force
  "${ARTISAN_ENV[@]}" php artisan db:seed --force
  "${ARTISAN_ENV[@]}" php artisan cache:clear || true
  "${ARTISAN_ENV[@]}" php artisan config:cache
  "${ARTISAN_ENV[@]}" php artisan route:cache
  "${ARTISAN_ENV[@]}" php artisan view:cache
  "${ARTISAN_ENV[@]}" php artisan queue:restart || true
)

if [[ "${BUILD_FRONTEND:-0}" == "1" && -d "${FRONTEND_DIR}" ]]; then
  install_npm_dependencies "${FRONTEND_DIR}"
  npm run build --prefix "${FRONTEND_DIR}"
fi

normalize_permissions

if command -v php8.3-fpm >/dev/null 2>&1 || systemctl list-units --type=service --all 2>/dev/null | grep -q php.*fpm; then
  systemctl reload "php8.3-fpm" 2>/dev/null || true
fi

if [[ -d .git ]]; then
  echo "Deployed $(git rev-parse --short HEAD) to ${APP_DIR}"
else
  echo "Deployed ${APP_DIR}"
fi
