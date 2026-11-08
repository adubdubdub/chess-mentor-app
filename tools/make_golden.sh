#!/bin/bash
# Erzeugt test/fixtures/<name>.golden.json mit der Analyse des Telegram-Bots (Container chess-mentor).
# Aufruf: tools/make_golden.sh <name> <white|black> [Tiefe]
set -eu
cd "$(dirname "$0")/.."
name=$1 color=$2 depth=${3:-12}
docker exec -i -w /app chess-mentor python - "$color" "$depth" "$(cat "test/fixtures/$name.pgn")" \
  < tools/make_golden.py > "test/fixtures/$name.golden.json"
echo "test/fixtures/$name.golden.json"
