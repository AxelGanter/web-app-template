#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Backend tests ==="
(cd "${ROOT_DIR}/backend" && php artisan test)

echo
echo "=== Frontend build ==="
(cd "${ROOT_DIR}/frontend" && npm run build)
