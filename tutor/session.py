"""
Persistence so the tutor "grows with you": difficulty and a full transcript
are saved between runs.
"""
import json
import os
from datetime import datetime

import config


def load() -> dict:
    if os.path.exists(config.SESSION_FILE):
        with open(config.SESSION_FILE, encoding="utf-8") as fh:
            return json.load(fh)
    return {
        "difficulty": config.START_DIFFICULTY,
        "total_turns": 0,
        "created": datetime.now().isoformat(timespec="seconds"),
        "transcript": [],
    }


def save(state: dict) -> None:
    os.makedirs(config.DATA_DIR, exist_ok=True)
    state["updated"] = datetime.now().isoformat(timespec="seconds")
    with open(config.SESSION_FILE, "w", encoding="utf-8") as fh:
        json.dump(state, fh, ensure_ascii=False, indent=2)


def record_turn(state: dict, user_text: str, turn: dict) -> None:
    state["total_turns"] = state.get("total_turns", 0) + 1
    state["difficulty"] = turn["new_difficulty"]
    state["transcript"].append(
        {
            "time": datetime.now().isoformat(timespec="seconds"),
            "heard": user_text,
            "turn": turn,
        }
    )
