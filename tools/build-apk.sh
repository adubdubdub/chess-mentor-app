#!/bin/bash
# Baut die APK in einer eigenen cgroup, damit der Build das Smart Home nicht stört.
# Aufruf: tools/build-apk.sh [release|debug]  (Standard release: nur dort baut das Stockfish-Plugin mit -O3;
# im Debug-Build rechnet Stockfish ohne Optimierung um ein Vielfaches langsamer)
# Hintergrund: Ein Build ohne Grenze hat LXC 100 am 06.11.2026 40 Minuten überlastet.
set -u
MODE=${1:-release}
cd "$(dirname "$0")/.."

export ANDROID_HOME=/root/dev/android-sdk
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$PATH:/root/dev/flutter/bin:$ANDROID_HOME/platform-tools"

UNIT=chess-build
LOG=/tmp/build.log
MEMLOG=/tmp/buildmem.log
# Grenzen für 16 GB RAM (08.11.2026): Build max. 4 GB, danach bleiben mindestens 2,5 GB für HA und Co.
MIN_START_MB=6000
MIN_RUN_MB=2500
MAX_PSI=20
# Proxmox teilt dem LXC wechselnde CPUs zu, daher die letzte erlaubte nehmen
BUILD_CPU=$(awk '/Cpus_allowed_list/{print $2}' /proc/self/status | tr ',-' '\n\n' | tail -1)

avail_mb() { free -m | awk 'NR==2{print $7}'; }
psi() { awk -F'[= ]' 'NR==1{print $3}' /proc/pressure/memory; }
otbr() { docker inspect -f '{{.State.Health.Status}}' otbr 2>/dev/null; }

if [ "$(avail_mb)" -lt "$MIN_START_MB" ] || awk "BEGIN{exit !($(psi) >= 1)}" || [ "$(otbr)" != healthy ]; then
  echo "Abbruch vor dem Start: verfügbar $(avail_mb) MB, PSI $(psi), otbr $(otbr)" >&2
  exit 2
fi

: > "$MEMLOG"
(
  while sleep 5; do
    systemctl is-active -q "$UNIT.scope" || continue
    a=$(avail_mb); p=$(psi); o=$(otbr)
    echo "$(date +%T) avail=$a psi=$p otbr=$o" >> "$MEMLOG"
    if [ "$a" -lt "$MIN_RUN_MB" ] || awk "BEGIN{exit !($p > $MAX_PSI)}" || [ "$o" != healthy ]; then
      echo "$(date +%T) WÄCHTER: Build gestoppt (avail=$a psi=$p otbr=$o)" >> "$MEMLOG"
      systemctl stop "$UNIT.scope"
      break
    fi
  done
) &
WATCH=$!
trap 'kill $WATCH 2>/dev/null' EXIT

# Kein MemoryHigh: dessen Drosselung trieb den systemweiten PSI hoch und löste den Wächter aus (07.11.2026)
systemd-run --scope --unit="$UNIT" --collect \
  -p MemoryMax=4000M -p MemorySwapMax=0 -p CPUWeight=10 -p IOWeight=10 --nice=19 \
  taskset -c "$BUILD_CPU" flutter build apk --$MODE --target-platform android-arm64 > "$LOG" 2>&1
code=$?
# Ein Stopp durch den Wächter darf nicht als Erfolg durchgehen
if grep -q WÄCHTER "$MEMLOG"; then
  code=3
  echo "Build vom Wächter gestoppt: $(grep WÄCHTER "$MEMLOG" | tail -1)" | tee -a "$LOG"
fi
echo "Build beendet mit Code $code" | tee -a "$LOG"
exit $code
