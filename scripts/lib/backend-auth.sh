#!/usr/bin/env bash

ensure_template_backend_config() {
  mkdir -p "${BACKEND_DIR}/config"
  [[ -f "${BACKEND_DIR}/config/cors.php" ]] || cp "${TEMPLATE_DIR}/backend/config/cors.php" "${BACKEND_DIR}/config/cors.php"
  [[ -f "${BACKEND_DIR}/config/sanctum.php" ]] || cp "${TEMPLATE_DIR}/backend/config/sanctum.php" "${BACKEND_DIR}/config/sanctum.php"
}

install_api_stack() {
  local requires_api=0

  [[ -f "${BACKEND_DIR}/routes/api.php" ]] || requires_api=1

  php -r '
    $composer = json_decode(file_get_contents($argv[1]), true, flags: JSON_THROW_ON_ERROR);
    exit(isset($composer["require"]["laravel/sanctum"]) ? 0 : 1);
  ' "${BACKEND_DIR}/composer.json" || requires_api=1

  if [[ "${requires_api}" == "1" ]]; then
    log "Installing Laravel API stack with Sanctum"
    run_cmd php "${BACKEND_DIR}/artisan" install:api --no-interaction --without-migration-prompt
  fi
}

configure_backend_env() {
  log "Configuring backend environment defaults"
  ensure_template_backend_config

  for f in "${BACKEND_DIR}/.env" "${BACKEND_DIR}/.env.example"; do
    set_env_value "$f" APP_URL "${BACKEND_APP_URL}"
    set_env_value "$f" ASSET_URL "${BACKEND_APP_URL}"
    set_env_value "$f" SESSION_DOMAIN null
    set_env_value "$f" SESSION_PATH /
    set_env_value "$f" SESSION_SAME_SITE lax
    set_env_value "$f" SESSION_SECURE_COOKIE false
    set_env_value "$f" SESSION_DRIVER file
    set_env_value "$f" QUEUE_CONNECTION sync
    set_env_value "$f" CACHE_STORE file
    set_env_value "$f" LOG_STACK daily
    set_env_value "$f" SANCTUM_STATEFUL_DOMAINS "${FRONTEND_HOST}:${FRONTEND_PORT},${BACKEND_HOST}:${BACKEND_PORT},127.0.0.1:${FRONTEND_PORT},127.0.0.1:${BACKEND_PORT}"
  done

  set_php_config_value "${BACKEND_DIR}/config/cors.php" \
    "/'allowed_origins'\\s*=>\\s*\\[[^\\]]*\\]/s" \
    "'allowed_origins' => ['${FRONTEND_APP_URL}', 'http://${FRONTEND_HOST}:${FRONTEND_PORT}', 'http://127.0.0.1:${FRONTEND_PORT}']"

  set_php_config_value "${BACKEND_DIR}/config/cors.php" \
    "/'supports_credentials'\\s*=>\\s*(true|false)/" \
    "'supports_credentials' => true"

  set_php_config_value "${BACKEND_DIR}/config/sanctum.php" \
    "/'localhost,localhost:3000,localhost:3101,localhost:8101,127.0.0.1,127.0.0.1:3000,127.0.0.1:3101,127.0.0.1:8101,::1,'/" \
    "'localhost,localhost:3000,localhost:${FRONTEND_PORT},localhost:${BACKEND_PORT},127.0.0.1,127.0.0.1:3000,127.0.0.1:${FRONTEND_PORT},127.0.0.1:${BACKEND_PORT},::1,'"
}

install_template_auth_backend() {
  log "Preparing backend SPA auth scaffolding"

  run_cmd mkdir -p "${BACKEND_DIR}/app/Http/Controllers/Api"
  run_cmd cp "${TEMPLATE_DIR}/backend/AuthController.php" "${BACKEND_DIR}/app/Http/Controllers/Api/AuthController.php"
  copy_template_tree "${TEMPLATE_DIR}/backend/tests" "${BACKEND_DIR}/tests"

  run_cmd php "${SCRIPT_DIR}/lib/php/patch_bootstrap_app.php" "${BACKEND_DIR}/bootstrap/app.php"
  run_cmd php "${SCRIPT_DIR}/lib/php/patch_api_routes.php" "${BACKEND_DIR}/routes/api.php"
}
