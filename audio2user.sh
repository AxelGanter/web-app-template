#!/bin/bash
# audio2user.sh - Quick TTS announcements to user
# Usage: ./audio2user.sh "Your message here"

if [ -z "$1" ]; then
    echo "❌ Usage: $0 \"message text\""
    exit 1
fi

# Direct play via /play endpoint
curl -sS -X POST http://127.0.0.1:8000/play -H 'Content-Type: application/json' -d "{\"text\":\"$1\"}"

exit $?

