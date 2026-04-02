# Project Bootstrap Template

This repository bootstraps `backend/` with Laravel + Backpack for Laravel and `frontend/` with Nuxt through a shared setup script.

If root-level `AGENTS.md` and `audio2user.sh` files exist, they are copied into both generated folders.

## Recommendation

The actual setup logic lives in `scripts/init-project.sh`. `npm` and `composer` are only wrappers so the team can choose whichever entrypoint they prefer.

If you want to use `audio2user.sh`, you will also want a local text-to-speech playback service. This template expects the `/play` endpoint provided by [playText2Speaker](https://github.com/AxelGanter/playText2Speaker).

## Usage

```bash
npm run init
```

or:

```bash
composer project:init
```

The bootstrap is now non-interactive by default:

- Nuxt uses the `minimal` template unless `NUXT_TEMPLATE` is overridden.
- Backpack installs with `--no-interaction`.
- Nested Git repositories are disabled unless `INIT_GIT_REPOS=1` is set.
- The frontend package manager defaults to `npm` and can be changed with `PACKAGE_MANAGER`.

## Configuration

You can override versions and bootstrap behavior with environment variables:

```bash
LARAVEL_VERSION='^12.0' BACKPACK_VERSION='^6.0' NUXT_VERSION='latest' npm run init
```

```bash
NUXT_TEMPLATE=minimal INSTALL_BACKPACK=1 INIT_GIT_REPOS=0 npm run init
```

```bash
PACKAGE_MANAGER=pnpm NUXT_TEMPLATE=minimal npm run init
```
