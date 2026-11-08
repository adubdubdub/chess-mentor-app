"""Referenz für den Vergleichstest: rechnet eine PGN mit analysis.py des Telegram-Bots.

Läuft im Container chess-mentor (dort liegen analysis.py, python-chess und Stockfish 17.1):
  docker exec -i -w /app chess-mentor python - black 12 < tools/make_golden.py ... (siehe tools/make_golden.sh)
Statt Tiefe + Zeitlimit wie im Bot nur eine feste Tiefe, damit das Ergebnis reproduzierbar ist.
"""
import json
import sys

import chess
import chess.engine

import analysis

color, depth, pgn = sys.argv[1], int(sys.argv[2]), sys.argv[3]
analysis.LIMIT = chess.engine.Limit(depth=depth)
game = analysis.read_pgn(pgn)
result = analysis.analyse(game, chess.WHITE if color == "white" else chess.BLACK)
print(json.dumps({"depth": depth, "color": color, "engine": "Stockfish 17.1", "analysis": result},
                 ensure_ascii=False, indent=1))
