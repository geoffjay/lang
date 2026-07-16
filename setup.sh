#!/usr/bin/env bash
# One-time setup for the Japanese conversation tutor.
set -e

cd "$(dirname "$0")"

echo "==> Creating Python virtual environment (.venv)"
python3 -m venv .venv

echo "==> Installing Python dependencies"
# These are public PyPI packages. Point explicitly at pypi.org so a private
# index configured via PIP_INDEX_URL / pip.conf (e.g. a corp CodeArtifact
# mirror) doesn't shadow them.
PIP_INDEX="${JP_TUTOR_PIP_INDEX:-https://pypi.org/simple/}"
./.venv/bin/pip install --index-url "$PIP_INDEX" --upgrade pip
./.venv/bin/pip install --index-url "$PIP_INDEX" -r requirements.txt

echo "==> Making sure Ollama is running and the model is available"
if ! curl -s http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "    Ollama isn't running. Start it in another terminal with: ollama serve"
else
  MODEL="${JP_TUTOR_MODEL:-qwen2.5:7b}"
  if ! ollama list | grep -q "${MODEL%%:*}"; then
    echo "    Pulling model $MODEL (this is a few GB, one time)..."
    ollama pull "$MODEL"
  else
    echo "    Model already present."
  fi
fi

echo ""
echo "Done! Start a conversation with:"
echo "    ./run.sh"
