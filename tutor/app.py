"""
Main interactive loop: push-to-talk voice conversation with a Japanese partner.
"""
import sys

import config
from tutor import llm, session, tts
from tutor.audio import Recorder
from tutor.stt import Transcriber

# ANSI colors for a friendlier terminal.
DIM = "\033[2m"
BOLD = "\033[1m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RESET = "\033[0m"


def _show_turn(turn: dict, is_reply: bool) -> None:
    """Print a turn according to the configured level of text support."""
    support = config.TEXT_SUPPORT
    if support == "audio":
        return

    if is_reply:
        jp, romaji, en = turn["reply_japanese"], turn["reply_romaji"], turn["reply_english"]
        label, color = "あい", CYAN
    else:
        jp, romaji, en = turn["user_japanese"], turn["user_romaji"], turn["user_english"]
        label, color = "あなた", GREEN

    print(f"{color}{BOLD}{label}:{RESET} {jp}")
    if support in ("full",):
        print(f"  {DIM}{romaji}{RESET}")
    if support in ("full", "japanese_english"):
        print(f"  {DIM}{en}{RESET}")


def _show_correction(turn: dict) -> None:
    if config.TEXT_SUPPORT != "full":
        return
    note = (turn.get("correction") or "").strip()
    if note:
        print(f"  {YELLOW}💡 {note}{RESET}")


def _banner(state: dict) -> None:
    print(f"\n{BOLD}=== 日本語会話 — Japanese Conversation Tutor ==={RESET}")
    print(f"{DIM}Model: {config.OLLAMA_MODEL} | Voice: {config.TTS_VOICE} | "
          f"Level: {config.LEVEL} | Difficulty: {state['difficulty']}/10 | "
          f"Turns so far: {state.get('total_turns', 0)}{RESET}")
    print(f"{DIM}Press Enter to start talking, Enter again to stop. "
          f"Type 'q' then Enter to quit.{RESET}\n")


def run() -> None:
    ready, msg = llm.check_ready()
    if not ready:
        print(f"{YELLOW}{msg}{RESET}")
        sys.exit(1)

    state = session.load()
    _banner(state)

    transcriber = Transcriber()
    recorder = Recorder()
    convo = llm.Conversation(level=config.LEVEL, difficulty=state["difficulty"])

    # Opening greeting from the tutor.
    print(f"{DIM}(あい is greeting you...){RESET}")
    turn = convo.opening_line()
    _show_turn(turn, is_reply=True)
    tts.speak(turn["reply_japanese"], difficulty=convo.difficulty)

    while True:
        try:
            cmd = input(f"\n{DIM}[Enter to talk / q to quit]{RESET} ")
        except (EOFError, KeyboardInterrupt):
            break
        if cmd.strip().lower() in {"q", "quit", "exit"}:
            break

        recorder.start()
        try:
            input(f"{YELLOW}● Recording... press Enter to stop{RESET}")
        except (EOFError, KeyboardInterrupt):
            recorder.stop()
            break
        audio = recorder.stop()

        print(f"{DIM}(transcribing...){RESET}")
        user_text = transcriber.transcribe(audio)
        if not user_text:
            print(f"{DIM}(didn't catch anything — try again){RESET}")
            continue

        print(f"{DIM}(thinking...){RESET}")
        try:
            turn = convo.respond(user_text)
        except Exception as exc:  # noqa: BLE001
            print(f"{YELLOW}Error talking to the model: {exc}{RESET}")
            continue

        _show_turn(turn, is_reply=False)
        _show_correction(turn)
        _show_turn(turn, is_reply=True)

        tts.speak(turn["reply_japanese"], difficulty=convo.difficulty)

        session.record_turn(state, user_text, turn)
        session.save(state)

    session.save(state)
    print(f"\n{GREEN}またね！ (See you!) "
          f"Difficulty is now {state['difficulty']}/10 — it'll pick up here next time.{RESET}")
