#!/usr/bin/env -S -- PYTHONSAFEPATH= python3
from __future__ import annotations

from contextlib import contextmanager, nullcontext
from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from json import dumps, loads
from logging import DEBUG as DEBUG
from logging import INFO, basicConfig, captureWarnings, getLogger
from os import environ, replace
from pathlib import Path
from sys import exit, stdin
from time import time
from typing import Any

from langfuse import Langfuse, propagate_attributes

with nullcontext():
    captureWarnings(True)
    basicConfig(
        format="%(message)s",
        level=DEBUG if environ.get("CC_LANGFUSE_DEBUG", "").lower() == "true" else INFO,
    )

_MAX_CHARS = int(environ.get("CC_LANGFUSE__MAX_CHARS", "20000"))

# --- Paths ---
_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_SESSIONS_DIR = _ROOT / "var" / "sessions"


@contextmanager
def _langfuse_client(langfuse: Langfuse):
    try:
        yield langfuse
    except Exception as e:
        getLogger().error("%s", f"Unexpected failure: {e}", exc_info=True)
    finally:
        try:
            langfuse.shutdown()
        except Exception as e:
            getLogger().error("%s", f"shutdown failed: {e}", exc_info=True)


def _state_path(session_id: str) -> Path:
    return _SESSIONS_DIR / f"{session_id}.langfuse.json"


def _load_state(session_id: str) -> dict[str, Any]:
    p = _state_path(session_id)
    try:
        if not p.exists():
            return {}
        return loads(p.read_text(encoding="utf-8"))
    except Exception:
        getLogger().error(
            "%s", f"load_state failed: {_state_path(session_id)}", exc_info=True
        )
        return {}


def _save_state(session_id: str, state: dict[str, Any]) -> None:
    try:
        _SESSIONS_DIR.mkdir(parents=True, exist_ok=True)
        tmp = _state_path(session_id).with_suffix(".tmp")
        tmp.write_text(dumps(state, indent=2, sort_keys=True), encoding="utf-8")
        replace(tmp, _state_path(session_id))
    except Exception as e:
        getLogger().error("%s", f"save_state failed: {e}", exc_info=True)


# ----------------- Hook payload -----------------
def _read_hook_payload() -> dict[str, Any]:
    """
    Claude Code hooks pass a JSON payload on stdin.
    This script tolerates missing/empty stdin by returning {}.
    """
    try:
        data = stdin.read()
        if not data.strip():
            return {}
        return loads(data)
    except Exception:
        getLogger().error("%s", "read_hook_payload failed", exc_info=True)
        return {}


def _extract_session_and_transcript(
    payload: dict[str, Any],
) -> tuple[str | None, Path | None]:
    """
    Tries a few plausible field names; exact keys can vary across hook types/versions.
    Prefer structured values from stdin over heuristics.
    """
    session_id = (
        payload.get("sessionId")
        or payload.get("session_id")
        or payload.get("session", {}).get("id")
    )

    transcript = (
        payload.get("transcriptPath")
        or payload.get("transcript_path")
        or payload.get("transcript", {}).get("path")
    )

    if transcript:
        try:
            transcript_path = Path(transcript).expanduser().resolve()
        except Exception:
            getLogger().error("%s", f"bad transcript path: {transcript}", exc_info=True)
            transcript_path = None
    else:
        transcript_path = None

    return session_id, transcript_path


# ----------------- Transcript parsing helpers -----------------
def _get_content(msg: dict[str, Any]) -> Any:
    if "message" in msg and isinstance(msg.get("message"), dict):
        return msg["message"].get("content")
    return msg.get("content")


def _get_role(msg: dict[str, Any]) -> str | None:
    # Claude Code transcript lines commonly have type=user/assistant OR message.role
    t = msg.get("type")
    if t in ("user", "assistant"):
        return t
    m = msg.get("message")
    if isinstance(m, dict):
        r = m.get("role")
        if r in ("user", "assistant"):
            return r
    return None


def _is_tool_result(msg: dict[str, Any]) -> bool:
    return _get_role(msg) == "user" and bool(
        _iter_content_blocks(_get_content(msg), "tool_result")
    )


def _iter_content_blocks(content: Any, block_type: str) -> list[dict[str, Any]]:
    if not isinstance(content, list):
        return []
    return [x for x in content if isinstance(x, dict) and x.get("type") == block_type]


def _extract_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for x in content:
            if isinstance(x, dict) and x.get("type") == "text":
                parts.append(x.get("text", ""))
            elif isinstance(x, str):
                parts.append(x)
        return "\n".join(p for p in parts if p)
    return ""


def _truncate_text(
    s: str | None, max_chars: int = _MAX_CHARS
) -> tuple[str, dict[str, Any]]:
    if s is None:
        return "", {"truncated": False, "orig_len": 0}
    orig_len = len(s)
    if orig_len <= max_chars:
        return s, {"truncated": False, "orig_len": orig_len}
    head = s[:max_chars]
    return head, {
        "truncated": True,
        "orig_len": orig_len,
        "kept_len": len(head),
        "sha256": sha256(s.encode("utf-8")).hexdigest(),
    }


def _get_model(msg: dict[str, Any]) -> str:
    m = msg.get("message")
    if isinstance(m, dict):
        return m.get("model") or "claude"
    return "claude"


def _get_message_id(msg: dict[str, Any]) -> str | None:
    m = msg.get("message")
    if isinstance(m, dict):
        mid = m.get("id")
        if isinstance(mid, str) and mid:
            return mid
    return None


# ----------------- Incremental reader -----------------
@dataclass
class SessionState:
    offset: int = 0
    buffer: str = ""
    turn_count: int = 0


def _load_session_state(state: dict[str, Any]) -> SessionState:
    return SessionState(
        offset=int(state.get("offset", 0)),
        buffer=str(state.get("buffer", "")),
        turn_count=int(state.get("turn_count", 0)),
    )


def _write_session_state(state: dict[str, Any], ss: SessionState) -> None:
    state.update(
        {
            "offset": ss.offset,
            "buffer": ss.buffer,
            "turn_count": ss.turn_count,
            "updated": datetime.now(timezone.utc).isoformat(),
        }
    )


def _read_new_jsonl(
    transcript_path: Path, ss: SessionState
) -> tuple[list[dict[str, Any]], SessionState]:
    """
    Reads only new bytes since ss.offset. Keeps ss.buffer for partial last line.
    Returns parsed JSON lines (best-effort) and updated state.
    """
    if not transcript_path.exists():
        return [], ss

    try:
        with open(transcript_path, "rb") as f:
            f.seek(ss.offset)
            chunk = f.read()
            new_offset = f.tell()
    except Exception as e:
        getLogger().error("%s", f"read_new_jsonl failed: {e}", exc_info=True)
        return [], ss

    if not chunk:
        return [], ss

    try:
        text = chunk.decode("utf-8", errors="replace")
    except Exception:
        text = chunk.decode(errors="replace")

    combined = ss.buffer + text
    lines = combined.split("\n")
    # last element may be incomplete
    ss.buffer = lines[-1]
    ss.offset = new_offset

    msgs: list[dict[str, Any]] = []
    for line in lines[:-1]:
        line = line.strip()
        if not line:
            continue
        try:
            msgs.append(loads(line))
        except Exception:
            continue

    return msgs, ss


# ----------------- Turn assembly -----------------
@dataclass
class Turn:
    user_msg: dict[str, Any]
    assistant_msgs: list[dict[str, Any]]
    tool_results_by_id: dict[str, Any]


def _build_turns(messages: list[dict[str, Any]]) -> list[Turn]:
    """
    Groups incremental transcript rows into turns:
    user (non-tool-result) -> assistant messages -> (tool_result rows, possibly interleaved)
    Uses:
    - assistant message dedupe by message.id (latest row wins)
    - tool results dedupe by tool_use_id (latest wins)
    """
    turns: list[Turn] = []
    current_user: dict[str, Any] | None = None

    # assistant messages for current turn:
    assistant_order: list[str] = (
        []
    )  # message ids in order of first appearance (or synthetic)
    assistant_latest: dict[str, dict[str, Any]] = {}  # id -> latest msg

    tool_results_by_id: dict[str, Any] = {}  # tool_use_id -> content

    def flush_turn():
        nonlocal current_user, assistant_order, assistant_latest, tool_results_by_id, turns
        if current_user is None:
            return
        if not assistant_latest:
            return
        assistants = [
            assistant_latest[mid] for mid in assistant_order if mid in assistant_latest
        ]
        turns.append(
            Turn(
                user_msg=current_user,
                assistant_msgs=assistants,
                tool_results_by_id=dict(tool_results_by_id),
            )
        )

    for msg in messages:
        role = _get_role(msg)

        # tool_result rows show up as role=user with content blocks of type tool_result
        if _is_tool_result(msg):
            for tr in _iter_content_blocks(_get_content(msg), "tool_result"):
                tid = tr.get("tool_use_id")
                if tid:
                    tool_results_by_id[str(tid)] = tr.get("content")
            continue

        if role == "user":
            # new user message -> finalize previous turn
            flush_turn()

            # start a new turn
            current_user = msg
            assistant_order = []
            assistant_latest = {}
            tool_results_by_id = {}
            continue

        if role == "assistant":
            if current_user is None:
                # ignore assistant rows until we see a user message
                continue

            mid = _get_message_id(msg) or f"noid:{len(assistant_order)}"
            if mid not in assistant_latest:
                assistant_order.append(mid)
            assistant_latest[mid] = msg
            continue

        # ignore unknown rows

    # flush last
    flush_turn()
    return turns


# ----------------- Langfuse emit -----------------
def _tool_calls_from_assistants(
    assistant_msgs: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    for am in assistant_msgs:
        for tu in _iter_content_blocks(_get_content(am), "tool_use"):
            tid = tu.get("id") or ""
            calls.append(
                {
                    "id": str(tid),
                    "name": tu.get("name") or "unknown",
                    "input": (
                        tu.get("input")
                        if isinstance(
                            tu.get("input"), (dict, list, str, int, float, bool)
                        )
                        else {}
                    ),
                }
            )
    return calls


def _emit_turn(
    langfuse: Langfuse,
    session_id: str,
    turn_num: int,
    turn: Turn,
    transcript_path: Path,
) -> None:
    user_text_raw = _extract_text(_get_content(turn.user_msg))
    user_text, user_text_meta = _truncate_text(user_text_raw)

    last_assistant = turn.assistant_msgs[-1]
    assistant_text_raw = _extract_text(_get_content(last_assistant))
    assistant_text, assistant_text_meta = _truncate_text(assistant_text_raw)

    model = _get_model(turn.assistant_msgs[0])

    tool_calls = _tool_calls_from_assistants(turn.assistant_msgs)

    # attach tool outputs
    for c in tool_calls:
        if c["id"] and c["id"] in turn.tool_results_by_id:
            out_raw = turn.tool_results_by_id[c["id"]]
            out_str = (
                out_raw
                if isinstance(out_raw, str)
                else dumps(out_raw, ensure_ascii=False)
            )
            out_trunc, out_meta = _truncate_text(out_str)
            c["output"] = out_trunc
            c["output_meta"] = out_meta
        else:
            c["output"] = None

    with propagate_attributes(
        session_id=session_id,
        trace_name=f"Claude Code - Turn {turn_num}",
        tags=["claude-code"],
    ):
        with langfuse.start_as_current_observation(
            name=f"Claude Code - Turn {turn_num}",
            input={"role": "user", "content": user_text},
            metadata={
                "source": "claude-code",
                "session_id": session_id,
                "turn_number": turn_num,
                "transcript_path": str(transcript_path),
                "user_text": user_text_meta,
            },
        ) as trace_span:
            # LLM generation
            with langfuse.start_as_current_observation(
                name="Claude Response",
                as_type="generation",
                model=model,
                input={"role": "user", "content": user_text},
                output={"role": "assistant", "content": assistant_text},
                metadata={
                    "assistant_text": assistant_text_meta,
                    "tool_count": len(tool_calls),
                },
            ):
                ...

            # Tool observations
            for tc in tool_calls:
                in_obj = tc["input"]
                # truncate tool input if it's a large string payload
                if isinstance(in_obj, str):
                    in_obj, in_meta = _truncate_text(in_obj)
                else:
                    in_meta = None

                with langfuse.start_as_current_observation(
                    name=f"Tool: {tc['name']}",
                    as_type="tool",
                    input=in_obj,
                    metadata={
                        "tool_name": tc["name"],
                        "tool_id": tc["id"],
                        "input_meta": in_meta,
                        "output_meta": tc.get("output_meta"),
                    },
                ) as tool_obs:
                    tool_obs.update(output=tc.get("output"))

            trace_span.update(output={"role": "assistant", "content": assistant_text})


# ----------------- Main -----------------
def _main() -> int:
    start = time()
    getLogger().debug("%s", "Hook started")

    if environ.get("TRACE_TO_LANGFUSE", "").lower() != "true":
        return 0

    public_key = environ.get("CC_LANGFUSE_PUBLIC_KEY") or environ.get(
        "LANGFUSE_PUBLIC_KEY"
    )
    secret_key = environ.get("CC_LANGFUSE_SECRET_KEY") or environ.get(
        "LANGFUSE_SECRET_KEY"
    )
    host = (
        environ.get("CC_LANGFUSE_BASE_URL")
        or environ.get("LANGFUSE_BASE_URL")
        or "https://cloud.langfuse.com"
    )

    if not public_key or not secret_key:
        return 0

    payload = _read_hook_payload()
    session_id, transcript_path = _extract_session_and_transcript(payload)

    if not session_id or not transcript_path:
        # No structured payload; fail open (do not guess)
        getLogger().debug(
            "%s", "Missing session_id or transcript_path from hook payload; exiting."
        )
        return 0

    if not transcript_path.exists():
        getLogger().debug("%s", f"Transcript path does not exist: {transcript_path}")
        return 0

    try:
        langfuse = Langfuse(
            public_key=public_key, secret_key=secret_key, host=host, timeout=300
        )
    except Exception:
        getLogger().error("%s", "Langfuse init failed", exc_info=True)
        return 0

    with _langfuse_client(langfuse):
        state = _load_state(session_id)
        ss = _load_session_state(state)

        msgs, ss = _read_new_jsonl(transcript_path, ss)
        if not msgs:
            _write_session_state(state, ss)
            _save_state(session_id, state)
            return 0

        turns = _build_turns(msgs)
        if not turns:
            _write_session_state(state, ss)
            _save_state(session_id, state)
            return 0

        # emit turns
        emitted = 0
        for t in turns:
            emitted += 1
            turn_num = ss.turn_count + emitted
            try:
                _emit_turn(langfuse, session_id, turn_num, t, transcript_path)
            except Exception as e:
                getLogger().error("%s", f"emit_turn failed: {e}", exc_info=True)

        ss.turn_count += emitted
        _write_session_state(state, ss)
        _save_state(session_id, state)
        langfuse.flush()
        dur = time() - start
        getLogger().info(
            "%s", f"Processed {emitted} turns in {dur:.2f}s (session={session_id})"
        )
        return 0


exit(_main())
