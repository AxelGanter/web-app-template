# Project Bootstrap Template

This repository bootstraps `backend/` with Laravel + Backpack for Laravel and `frontend/` with Nuxt through a shared setup script.

## Recommendation

The actual setup logic lives in `scripts/init-project.sh`. `npm` and `composer` are only wrappers so the team can choose whichever entrypoint they prefer.

## Usage

```bash
npm run init
```

or:

```bash
composer project:init
```

## Options

```bash
./scripts/init-project.sh --help
```

Important flags:

- `--force` removes existing `backend/` and `frontend/` directories before setup.
- `--skip-backend` creates only the frontend.
- `--skip-frontend` creates only the backend.
- `--no-install` scaffolds only; extra steps such as `npm install` and the Backpack installation are skipped.

## Configuration

You can override versions with environment variables:

```bash
LARAVEL_VERSION='^12.0' BACKPACK_VERSION='^6.0' npm run init
```

You can also replace the Nuxt scaffold command:

```bash
NUXT_CMD='npx nuxi@latest init --packageManager npm' npm run init
```
