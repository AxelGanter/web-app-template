# Project Bootstrap Template

This repository bootstraps `backend/` with Laravel + Backpack for Laravel and `frontend/` with Nuxt through a shared setup script.

It also initializes separate Git repositories inside `backend/` and `frontend/`. If root-level `AGENTS.md` and `audio2user.sh` files exist, they are copied into both generated folders.

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

## Configuration

You can override versions with environment variables:

```bash
LARAVEL_VERSION='^12.0' BACKPACK_VERSION='^6.0' NUXT_VERSION='latest' npm run init
```
