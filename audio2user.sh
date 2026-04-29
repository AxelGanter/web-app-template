#!/bin/bash
# audio2user.sh - Quick TTS announcements to user via t2u
# Usage: ./audio2user.sh "Your message here"

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 \"message text\""
    exit 1
fi

T2U_URL="${T2U_URL:-https://t2u.mctdev.de}"
T2U_APP_ID="${T2U_APP_ID:-$(basename "$(pwd)")}"

# Fire-and-forget TTS request so callers do not block on audio playback.
curl -sS -X POST "${T2U_URL}/api/messages" \
  -H 'Content-Type: application/json' \
  -d "{\"app_id\":\"${T2U_APP_ID}\",\"text\":\"$1\"}" >/dev/null 2>&1 &

exit 0
