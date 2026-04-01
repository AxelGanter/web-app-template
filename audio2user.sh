#!/bin/bash
# audio2user.sh - Quick TTS announcements to user
# Usage: ./audio2user.sh "Your message here"

set -euo pipefail

if [ -z "$1" ]; then
    echo "❌ Usage: $0 \"message text\""
    exit 1
fi

# Fire-and-forget TTS request so callers do not block on audio playback.
curl -sS -X POST http://127.0.0.1:8000/play -H 'Content-Type: application/json' -d "{\"text\":\"$1\"}" >/dev/null 2>&1 &

exit 0
