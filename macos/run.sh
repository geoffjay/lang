#!/usr/bin/env bash
# Build (if needed) and launch the menu-bar app.
set -e
cd "$(dirname "$0")"

APP="build/JapaneseTutor.app"
if [ ! -d "$APP" ]; then
  ./build_app.sh
fi

# Relaunch cleanly if it's already running.
killall JapaneseTutor 2>/dev/null || true
open "$APP"
echo "Launched. Look for the 💬 icon in your menu bar (top-right)."
echo "Tip: to watch logs, run:  log stream --predicate 'process == \"JapaneseTutor\"' --level debug"
