# ♟️ Schach-Mentor (Android-App)

Stockfish rechnet, du lernst: Android-App, die eigene Schachpartien auf dem Handy analysiert, Fehler im Dialog bespricht
und als Puzzles mit Wiederholung einübt. Ohne eigenen Server und ohne Pflicht-Schlüssel. Abgeleitet vom Telegram-Bot
[chess-mentor](https://github.com/adubdubdub/chess-mentor).

> **Stand: Phase 0 abgeschlossen.** Bisher gibt es nur eine Prüf-App: ein Brett, auf dem man zieht, mit Stockfish-Bewertung und dem
> besten Zug als Pfeil. Analyse, Besprechung und Puzzles folgen.

## 🧭 Zielbild

```mermaid
flowchart LR
    A["📱 Lichess-App<br/>PGN teilen"] --> M
    L["☁️ Lichess-API<br/>Online-Partien"] -.-> M
    M(["♟️ Schach-Mentor<br/>Stockfish auf dem Handy"]) --> R["💬 Besprechung"]
    M --> P["🧩 Puzzles"]
    M -.-> C["🤖 ChatGPT, Gemini, Claude<br/>optional"]
    M -.-> S["📚 Lichess-Studie<br/>optional"]
```

Texte entstehen in drei Stufen, nur die erste ist Pflicht:

| Stufe | Wie | Kosten |
|---|---|---|
| Textbausteine | aus Engine-Fakten und Motiven, offline | keine |
| Übergabe | fertiger Prompt per Teilen an eine Chat-App, Stockfish prüft dort nichts mehr | keine |
| Eigener Schlüssel | App fragt den Anbieter des Nutzers direkt | je nach Anbieter |

## 🗂️ Aufbau

```
chess-mentor-app/
├── lib/main.dart        Prüf-App: Brett (chessground), Regeln (dartchess), Engine (multistockfish)
├── test/                Tests
├── android/             Android-Projekt, Speichergrenzen in gradle.properties
├── tools/build-apk.sh   begrenzter APK-Build für den Heimserver
└── LICENSE              GPL-3.0
```

## ⚙️ Entwicklung

```bash
flutter pub get
flutter analyze
flutter test
tools/build-apk.sh       # baut build/app/outputs/flutter-apk/app-debug.apk
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk   # -t: Debug-APK ist test-only
```

Gebaut wird nur `arm64-v8a` (`android.injected.build.abi` in `android/gradle.properties`).

## ⚠️ Stolpersteine

- `multistockfish` kompiliert drei Engines aus C++. Ohne Grenze hat das den Heimserver lahmgelegt, deshalb dort nie
  `flutter build` direkt aufrufen. `tools/build-apk.sh` baut in einer eigenen cgroup, mit einem Compiler-Job und
  Wächter. Es setzt die Pfade dieses Servers voraus.
- Die Vorlage von Flutter setzt Gradle auf 8 GB Heap, hier sind es 1,5 GB.

## 🗺️ Roadmap

- [x] **Phase 0:** Werkzeuge, Prüf-App auf dem Gerät (getestet auf Pixel 6, Android 16)
- [ ] **Phase 1:** PGN-Eingang, Analyse
- [ ] **Phase 2:** Besprechung am Brett
- [ ] **Phase 3:** Puzzles mit Wiederholung
- [ ] **Phase 4:** Lichess-Abruf und Studien-Export
- [ ] **Phase 5:** KI-Übergabe und eigener Schlüssel
- [ ] **Phase 6:** Veröffentlichung als APK, später F-Droid

## 📜 Lizenz

GPL-3.0, weil Stockfish und die Lichess-Pakete unter dieser Lizenz stehen. Die App steht in keiner Verbindung zu Lichess.
