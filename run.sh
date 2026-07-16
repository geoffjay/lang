#!/usr/bin/env bash
# Start the conversation tutor using the project's virtual environment.
set -e
cd "$(dirname "$0")"

if [ ! -d .venv ]; then
  echo "No .venv found. Run ./setup.sh first."
  exit 1
fi

exec ./.venv/bin/python main.py
