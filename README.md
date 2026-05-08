# Project Bootstrap Template

This repository bootstraps `backend/` with Laravel + Backpack for Laravel and `frontend/` with Nuxt through a shared setup script.

If root-level `AGENTS.md` and `audio2user.sh` files exist, they are copied into both generated folders.

The backend template ships with Backpack CRUD, PermissionManager, BackupManager, LogManager and Laravel Reverb enabled by default.
It also prepares a first-party SPA auth baseline with Laravel Sanctum cookie sessions, CSRF handling, central frontend API/auth composables, and Pinia stores.

## audio2user.sh

Sends TTS announcements to [t2u-text2user](https://t2u.mctdev.de) so messages are spoken in the browser.

```bash
./audio2user.sh "Deployment finished"
```

By default `app_id` is the current directory name. Override via environment:

```bash
T2U_APP_ID=taskdrop ./audio2user.sh "Build complete"
```

| Variable | Default | Description |
|---|---|---|
| `T2U_URL` | `https://t2u.mctdev.de` | t2u API base URL |
| `T2U_APP_ID` | `$(basename $(pwd))` | Project identifier for message routing |

## Recommendation

`npm`, `composer`, and `./install.sh` are only wrappers.
The bootstrap entrypoint is intentionally small: [scripts/init-project.sh](scripts/init-project.sh).

Topic-specific setup lives in:

- [scripts/lib/backend-auth.sh](scripts/lib/backend-auth.sh) for Sanctum SPA auth and backend env defaults
- [scripts/lib/backpack.sh](scripts/lib/backpack.sh) for Backpack, PermissionManager, Reverb, backups, and logs
- [scripts/lib/frontend.sh](scripts/lib/frontend.sh) for Nuxt, Pinia, and frontend env/defaults
- [scripts/lib/shared.sh](scripts/lib/shared.sh) for shared `.env` and copied helper files

Upgrade-sensitive file mutations are isolated into small PHP patchers under [scripts/lib/php](scripts/lib/php), so future Laravel upgrades do not require digging through shell heredocs.


## Usage

```bash
npm run init
```

or:

```bash
composer project:init
```

or:

```bash
./install.sh
```

The bootstrap is non-interactive by default:

- Laravel defaults to `^12.0`.
- Backpack defaults to `backpack/crud ^7.0` with `backpack/theme-tabler ^2.0`.
- PermissionManager, BackupManager, LogManager and Reverb are installed by default.
- Nuxt uses the `minimal` template unless `NUXT_TEMPLATE` is overridden.
- Nuxt skips the module selection prompt.
- Backpack installs with `--no-interaction`.
- Nested Git repositories are disabled unless `INIT_GIT_REPOS=1` is set.
- The frontend package manager defaults to `npm` and can be changed with `PACKAGE_MANAGER`.

## Configuration

You can override versions and bootstrap behavior with environment variables:

For local URLs and ports, copy `.env.example` to `.env` in the template root before running the bootstrap:

```bash
cp .env.example .env
```

The bootstrap reads:

| Variable | Default | Description |
|---|---|---|
| `BACKEND_HOST` | `localhost` | Host passed into generated backend/frontend defaults |
| `BACKEND_PORT` | `8101` | Backend app / API port |
| `FRONTEND_HOST` | `localhost` | Nuxt dev host |
| `FRONTEND_PORT` | `3101` | Nuxt dev port |
| `BACKEND_APP_URL` | `http://localhost:8101` | Backend base URL written into backend env and frontend API config |
| `FRONTEND_APP_URL` | `http://localhost:3101` | Frontend URL used for CORS / Sanctum stateful domains |

```bash
LARAVEL_VERSION='^12.0' BACKPACK_VERSION='^7.0' BACKPACK_THEME_TABLER_VERSION='^2.0' NUXT_VERSION='latest' npm run init
```

```bash
NUXT_TEMPLATE=minimal INSTALL_BACKPACK=1 INIT_GIT_REPOS=0 npm run init
```

```bash
PACKAGE_MANAGER=pnpm NUXT_TEMPLATE=minimal npm run init
```

Optional backend modules can be toggled if needed:

```bash
INSTALL_REVERB=0 INSTALL_BACKUP_MANAGER=0 INSTALL_LOG_MANAGER=0 INSTALL_PERMISSION_MANAGER=0 npm run init
```

If you want to rebuild an existing scaffold in place, use the force wrapper:

```bash
npm run init:force
```

## Included Baseline

Generated projects now include:

- Laravel Backpack with PermissionManager prepared and an initial admin seeder wired into `DatabaseSeeder`
- Sanctum SPA cookie auth with `/sanctum/csrf-cookie`, `/api/auth/login`, `/api/auth/logout`, `/api/auth/user`
- Nuxt auth/API composables with `credentials: include` and central `401` handling
- Pinia `auth` and `app` stores
- Root `start.sh`, `stop.sh`, and `test.sh` helpers

## Stability Notes

The template is designed to lean on official installers first:

- Laravel API support comes from `php artisan install:api`
- Backpack setup comes from the package installers
- The template only adds the minimum glue needed for SPA auth, Pinia, and admin permissions

That means when Laravel or Nuxt changes, the likely adjustment points are small and obvious:

- backend patchers in `scripts/lib/php/`
- frontend scaffold files in `scripts/templates/frontend/`
- backend config templates in `scripts/templates/backend/config/`
