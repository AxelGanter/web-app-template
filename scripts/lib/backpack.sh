#!/usr/bin/env bash

install_backpack() {
  log "Installing Backpack for Laravel"
  COMPOSER_ALLOW_SUPERUSER=1 run_cmd composer require backpack/crud:"${BACKPACK_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction

  if [[ "${INSTALL_BACKPACK_THEME}" == "1" ]]; then
    log "Installing Backpack Tabler theme"
    COMPOSER_ALLOW_SUPERUSER=1 run_cmd composer require backpack/theme-tabler:"${BACKPACK_THEME_TABLER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  fi

  run_cmd php "${BACKEND_DIR}/artisan" backpack:install --no-interaction --skip-basset-check
  run_cmd php "${BACKEND_DIR}/artisan" storage:link --force

  if [[ "${INSTALL_BACKPACK_THEME}" == "1" ]]; then
    run_cmd php "${BACKEND_DIR}/artisan" config:clear
    run_cmd php "${BACKEND_DIR}/artisan" view:clear
    run_cmd php "${BACKEND_DIR}/artisan" route:list --path=admin
    run_cmd mkdir -p "${BACKEND_DIR}/config/backpack"
    [[ -f "${BACKEND_DIR}/config/backpack/theme-tabler.php" ]] || run_cmd cp "${BACKEND_DIR}/vendor/backpack/theme-tabler/config/theme-tabler.php" "${BACKEND_DIR}/config/backpack/theme-tabler.php"
    set_php_config_value "${BACKEND_DIR}/config/backpack/ui.php" "/'view_namespace'\\s*=>\\s*'[^']*'/" "'view_namespace' => 'backpack.theme-tabler::'"
    set_php_config_value "${BACKEND_DIR}/config/backpack/ui.php" "/'view_namespace_fallback'\\s*=>\\s*'[^']*'/" "'view_namespace_fallback' => 'backpack.theme-tabler::'"
    set_php_config_value "${BACKEND_DIR}/config/backpack/theme-tabler.php" "/'layout'\\s*=>\\s*'[^']*'/" "'layout' => 'vertical'"
  fi
}

install_permission_manager() {
  log "Installing Backpack PermissionManager"
  COMPOSER_ALLOW_SUPERUSER=1 run_cmd composer require backpack/permissionmanager:"${PERMISSION_MANAGER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  run_cmd php "${BACKEND_DIR}/artisan" vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag="permission-migrations" --no-interaction
  run_cmd php "${BACKEND_DIR}/artisan" vendor:publish --provider="Spatie\Permission\PermissionServiceProvider" --tag="permission-config" --no-interaction
  run_cmd php "${BACKEND_DIR}/artisan" vendor:publish --provider="Backpack\PermissionManager\PermissionManagerServiceProvider" --tag="config" --tag="migrations" --no-interaction
  run_cmd php "${BACKEND_DIR}/artisan" migrate --force
  run_cmd php "${TEMPLATE_DIR}/patch-user-model.php" "${BACKEND_DIR}/app/Models/User.php"

  log "Copying AuthorizationSeeder"
  run_cmd cp "${TEMPLATE_DIR}/AuthorizationSeeder.php" "${BACKEND_DIR}/database/seeders/AuthorizationSeeder.php"
  run_cmd php "${SCRIPT_DIR}/lib/php/patch_database_seeder.php" "${BACKEND_DIR}/database/seeders/DatabaseSeeder.php"

  run_cmd php "${BACKEND_DIR}/artisan" backpack:add-menu-content "<x-backpack::menu-item title='Roles' icon='la la-id-badge' :link=\"backpack_url('role')\" />"
  run_cmd php "${BACKEND_DIR}/artisan" backpack:add-menu-content "<x-backpack::menu-item title='Permissions' icon='la la-key' :link=\"backpack_url('permission')\" />"
}

install_reverb() {
  log "Installing Laravel Reverb"
  run_cmd php "${BACKEND_DIR}/artisan" install:broadcasting --reverb --without-node --force --no-interaction

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
  run_cmd php "${SCRIPT_DIR}/lib/php/patch_filesystems.php" "${BACKEND_DIR}/config/filesystems.php"
}

install_backup_manager() {
  log "Installing Backpack BackupManager"
  COMPOSER_ALLOW_SUPERUSER=1 run_cmd composer require backpack/backupmanager:"${BACKUP_MANAGER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  run_cmd php "${BACKEND_DIR}/artisan" vendor:publish --provider="Backpack\BackupManager\BackupManagerServiceProvider" --tag="backup-config" --tag="lang" --no-interaction
  run_cmd php "${BACKEND_DIR}/artisan" backpack:add-menu-content "<x-backpack::menu-item title='Backups' icon='la la-hdd-o' :link=\"backpack_url('backup')\" />"
}

install_log_manager() {
  log "Installing Backpack LogManager"
  COMPOSER_ALLOW_SUPERUSER=1 run_cmd composer require backpack/logmanager:"${LOG_MANAGER_VERSION}" --working-dir="${BACKEND_DIR}" --no-interaction
  run_cmd php "${BACKEND_DIR}/artisan" backpack:add-menu-content "<x-backpack::menu-item title='Logs' icon='la la-terminal' :link=\"backpack_url('log')\" />"
}
