#!/usr/bin/env bash

configure_frontend_env() {
  log "Configuring frontend environment defaults"
  cat > "${FRONTEND_DIR}/.env" <<EOF
NUXT_HOST=${FRONTEND_HOST}
NUXT_PORT=${FRONTEND_PORT}
NUXT_PUBLIC_API_BASE=${BACKEND_APP_URL}/api
EOF

  cp "${FRONTEND_DIR}/.env" "${FRONTEND_DIR}/.env.example"
}

configure_frontend_package() {
  log "Preparing frontend package defaults"
  php -r '
    $file = $argv[1];
    $nuxtVersion = $argv[2];
    $vueVersion = $argv[3];
    $vueRouterVersion = $argv[4];
    $data = json_decode(file_get_contents($file), true, flags: JSON_THROW_ON_ERROR);
    $data["dependencies"]["@pinia/nuxt"] = "^0.11.3";
    $data["dependencies"]["nuxt"] = $nuxtVersion;
    $data["dependencies"]["pinia"] = "^3.0.4";
    $data["dependencies"]["vue"] = $vueVersion;
    $data["dependencies"]["vue-router"] = $vueRouterVersion;
    ksort($data["dependencies"]);
    file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES).PHP_EOL);
  ' "${FRONTEND_DIR}/package.json" "${NUXT_PACKAGE_VERSION}" "${VUE_PACKAGE_VERSION}" "${VUE_ROUTER_PACKAGE_VERSION}"
}

install_template_frontend_scaffold() {
  log "Preparing frontend auth and store scaffolding"
  copy_template_tree "${TEMPLATE_DIR}/frontend/app" "${FRONTEND_DIR}/app"
  run_cmd cp "${TEMPLATE_DIR}/frontend/nuxt.config.ts" "${FRONTEND_DIR}/nuxt.config.ts"
}

install_frontend_dependencies() {
  log "Installing frontend dependencies with ${PACKAGE_MANAGER}"
  case "${PACKAGE_MANAGER}" in
    npm) NPM_CONFIG_LOGLEVEL="${NPM_CONFIG_LOGLEVEL:-warn}" run_cmd npm install --no-audit --foreground-scripts --prefix "${FRONTEND_DIR}" ;;
    pnpm) (cd "${FRONTEND_DIR}" && pnpm install) ;;
    yarn) (cd "${FRONTEND_DIR}" && yarn install) ;;
    bun) (cd "${FRONTEND_DIR}" && bun install) ;;
    *) printf 'Unsupported PACKAGE_MANAGER: %s\n' "${PACKAGE_MANAGER}" >&2; exit 1 ;;
  esac
}

run_nuxt_init() {
  log "Scaffolding Nuxt in ${FRONTEND_DIR}"
  run_cmd rm -rf "${FRONTEND_DIR}"
  (cd "${ROOT_DIR}" && CI=1 run_cmd npx "nuxi@${NUXT_VERSION}" init frontend \
    --template "${NUXT_TEMPLATE}" --packageManager "${PACKAGE_MANAGER}" \
    --no-modules --no-install --no-gitInit)
}
