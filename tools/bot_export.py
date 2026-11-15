#!/usr/bin/env python3
"""Einmalige Übernahme der Daten des Telegram-Bots (mentor.db) in eine Exportdatei der App.

Aufruf: tools/bot_export.py /opt/chess-mentor/data/mentor.db ausgabe.json

Übernommen werden Partien (PGN, Farbe, Datum), der Lernstand der Puzzles (Stufe, Fälligkeit, Wiederholungen) und die
KI-Erklärungen der Besprechung. Die Analyse wird nicht übernommen: Die App rechnet sie neu und überträgt danach den
Lernstand über die Zugnummer (ply). Die Datenbank wird nur lesend geöffnet.
"""
import json
import sqlite3
import sys
from datetime import datetime


def review_texts(coach_json):
    """Bot-Format (zusammenfassung, lernpunkt, momente[ply, frage, tipp, erklaerung]) -> App-Format."""
    if not coach_json:
        return {}
    c = json.loads(coach_json)
    if c.get("fallback"):
        return {}  # nüchterne Ersatztexte des Bots nicht übernehmen
    moments = {
        str(m["ply"]): {"question": m.get("frage"), "tip": m.get("tipp"), "explanation": m.get("erklaerung")}
        for m in c.get("momente", [])
        if isinstance(m.get("ply"), int)
    }
    return {"de": json.dumps({"summary": c.get("zusammenfassung"), "learning": c.get("lernpunkt"), "moments": moments},
                             ensure_ascii=False)}


def main(db_path, out_path):
    con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    games = []
    for gid, pgn, color, created, coach in con.execute(
            "SELECT id, pgn, user_color, created, coach FROM games ORDER BY created"):
        puzzles = [
            {"ply": ply, "level": level, "due": due, "reps": reps, "lapses": lapses, "attempts": [], "ai": {}}
            for ply, level, due, reps, lapses in con.execute(
                "SELECT ply, level, due, reps, lapses FROM puzzles WHERE game_id = ? ORDER BY ply", (gid,))
        ]
        games.append({
            "pgn": pgn,
            "color": {"w": "white", "b": "black"}.get(color),
            "added": datetime.fromtimestamp(created).isoformat(timespec="seconds"),
            "analysis": None,
            "puzzles": puzzles,
            "reviewTexts": review_texts(coach),
        })
    out = {"format": "schach-mentor-export", "version": 1, "exported": datetime.now().isoformat(timespec="seconds"),
           "games": games}
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(f"{len(games)} Partien, {sum(len(g['puzzles']) for g in games)} Puzzle-Stände -> {out_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
