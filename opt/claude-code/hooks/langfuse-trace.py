#!/usr/bin/env -S -- PYTHONSAFEPATH= python3
from __future__ import annotations

from contextlib import contextmanager, nullcontext, suppress
from dataclasses import dataclass, replace
from datetime import datetime, timezone
from hashlib import sha256
from json import dumps, loads
from logging import DEBUG, INFO, basicConfig, captureWarnings, getLogger
from os import environ
from os import replace as atomic_replace
from pathlib import Path
from sys import exit, stdin
from time import time
from typing import Any, Iterator, NotRequired, TypedDict

from langfuse import Langfuse, propagate_attributes

with nullcontext():
    captureWarnings(True)
    basicConfig(
        format="%(message)s",
        level=DEBUG if environ.get("CC_LANGFUSE_DEBUG", "").lower() == "true" else INFO,
    )

_MAX_CHARS = int(environ.get("CC_LANGFUSE__MAX_CHARS", "20000"))
_ROOT = Path(__file__).resolve().parent.parent.parent.parent
_SESSIONS_DIR = _ROOT / "var" / "sessions"


@contextmanager
def _log_errors() -> Iterator[None]:
    try:
        yield
    except Exception as e:
        getLogger().error("%s", e, exc_info=True)


@contextmanager
def _timed(label: str) -> Iterator[None]:
    getLogger().debug("%s", f"{label} started")
    start = time()
    yield
    getLogger().debug("%s", f"{label} completed in {time() - start:.2f}s")


# ── Types ──────────────────────────────────────────────


class _ApiMessage(TypedDict, total=False):
    role: str
    content: Any
    model: str
    id: str


class _TranscriptLine(TypedDict, total=False):
    type: str
    message: _ApiMessage
    content: Any


class _TruncMeta(TypedDict):
    truncated: bool
    orig_len: int
    kept_len: NotRequired[int]
    sha256: NotRequired[str]


class _ToolCall(TypedDict):
    id: str
    name: str
    input: Any
    output: NotRequired[str | None]
    output_meta: NotRequired[_TruncMeta]


@dataclass(frozen=True)
class _Config:
    public_key: str
    secret_key: str
    host: str


@dataclass(frozen=True)
class _HookPayload:
    session_id: str
    transcript_path: Path


@dataclass(frozen=True)
class _ReaderState:
    offset: int = 0
    buffer: str = ""
    turn_count: int = 0


@dataclass(frozen=True)
class _Turn:
    user_msg: _TranscriptLine
    assistant_msgs: tuple[_TranscriptLine, ...]
    tool_results: dict[str, Any]


# ── Input ──────────────────────────────────────────────


def _read_config() -> _Config | None:
    if environ.get("TRACE_TO_LANGFUSE", "").lower() != "true":
        return None

    public_key = environ.get("CC_LANGFUSE_PUBLIC_KEY") or environ.get(
        "LANGFUSE_PUBLIC_KEY"
    )
    secret_key = environ.get("CC_LANGFUSE_SECRET_KEY") or environ.get(
        "LANGFUSE_SECRET_KEY"
    )
    if not public_key or not secret_key:
        return None

    host = (
        environ.get("CC_LANGFUSE_BASE_URL")
        or environ.get("LANGFUSE_BASE_URL")
        or "https://cloud.langfuse.com"
    )
    return _Config(public_key=public_key, secret_key=secret_key, host=host)


def _read_payload() -> _HookPayload | None:
    try:
        data = stdin.read()
        if not data.strip():
            return None
        payload = loads(data)
    except Exception as e:
        getLogger().error("%s", e, exc_info=True)
        return None

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
    if not session_id or not transcript:
        getLogger().debug("%s", "Missing session_id or transcript_path; exiting.")
        return None

    try:
        transcript_path = Path(transcript).expanduser().resolve()
    except Exception as e:
        getLogger().error("%s", e, exc_info=True)
        return None

    if not transcript_path.exists():
        getLogger().debug("%s", f"Transcript does not exist: {transcript_path}")
        return None

    return _HookPayload(session_id=session_id, transcript_path=transcript_path)


# ── State ──────────────────────────────────────────────


def _state_path(session_id: str) -> Path:
    return _SESSIONS_DIR / f"{session_id}.langfuse.json"


def _load_state(session_id: str) -> _ReaderState:
    p = _state_path(session_id)
    with _log_errors():
        if p.exists():
            raw = loads(p.read_text(encoding="utf-8"))
            return _ReaderState(
                offset=int(raw.get("offset", 0)),
                buffer=str(raw.get("buffer", "")),
                turn_count=int(raw.get("turn_count", 0)),
            )
    return _ReaderState()


@contextmanager
def _atomic_write(path: Path) -> Iterator[Path]:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    yield tmp
    atomic_replace(tmp, path)


def _save_state(session_id: str, *, state: _ReaderState) -> None:
    with _log_errors():
        with _atomic_write(_state_path(session_id)) as tmp:
            tmp.write_text(
                dumps(
                    {
                        "offset": state.offset,
                        "buffer": state.buffer,
                        "turn_count": state.turn_count,
                        "updated": datetime.now(timezone.utc).isoformat(),
                    },
                    indent=2,
                    sort_keys=True,
                ),
                encoding="utf-8",
            )


# ── Message vocabulary ─────────────────────────────────


def _get_content(msg: _TranscriptLine) -> Any:
    match msg:
        case {"message": {"content": content}}:
            return content
        case {"content": content}:
            return content
        case _:
            return None


def _get_role(msg: _TranscriptLine) -> str | None:
    match msg:
        case {"type": "user" | "assistant" as role}:
            return str(role)
        case {"message": {"role": "user" | "assistant" as role}}:
            return str(role)
        case _:
            return None


def _content_blocks(content: Any, *, block_type: str) -> list[dict[str, Any]]:
    if not isinstance(content, list):
        return []
    return [x for x in content if isinstance(x, dict) and x.get("type") == block_type]


def _is_tool_result(msg: _TranscriptLine) -> bool:
    return _get_role(msg) == "user" and bool(
        _content_blocks(_get_content(msg), block_type="tool_result")
    )


def _get_model(msg: _TranscriptLine) -> str:
    match msg:
        case {"message": {"model": str(model)}} if model:
            return model
        case _:
            return "claude"


def _get_message_id(msg: _TranscriptLine) -> str | None:
    match msg:
        case {"message": {"id": str(mid)}} if mid:
            return mid
        case _:
            return None


def _extract_text(content: Any) -> str:
    match content:
        case str(text):
            return text
        case list(blocks):
            parts: list[str] = []
            for block in blocks:
                match block:
                    case {"type": "text", "text": str(text)} if text:
                        parts.append(text)
                    case str(text) if text:
                        parts.append(text)
            return "\n".join(parts)
        case _:
            return ""


def _truncate(s: str, *, max_chars: int = _MAX_CHARS) -> tuple[str, _TruncMeta]:
    orig_len = len(s)
    if orig_len <= max_chars:
        return s, _TruncMeta(truncated=False, orig_len=orig_len)
    head = s[:max_chars]
    return head, _TruncMeta(
        truncated=True,
        orig_len=orig_len,
        kept_len=len(head),
        sha256=sha256(s.encode("utf-8")).hexdigest(),
    )


# ── Parse ──────────────────────────────────────────────


def _read_new_messages(
    path: Path, *, state: _ReaderState
) -> tuple[list[_TranscriptLine], _ReaderState]:
    """Read only new bytes since state.offset. Returns parsed lines and updated state."""
    if not path.exists():
        return [], state

    try:
        with open(path, "rb") as f:
            f.seek(state.offset)
            chunk = f.read()
            new_offset = f.tell()
    except Exception as e:
        getLogger().error("%s", e, exc_info=True)
        return [], state

    if not chunk:
        return [], state

    text = chunk.decode("utf-8", errors="replace")
    combined = state.buffer + text
    lines = combined.split("\n")

    msgs: list[_TranscriptLine] = []
    for line in lines[:-1]:
        if not (line := line.strip()):
            continue
        with suppress(Exception):
            msgs.append(loads(line))

    return msgs, replace(state, offset=new_offset, buffer=lines[-1])


# ── Assemble ───────────────────────────────────────────


def _assemble_turns(messages: list[_TranscriptLine]) -> Iterator[_Turn]:
    """
    Group transcript rows into turns: user → assistant(s) → tool_result(s).
    Dict insertion order deduplicates assistant messages by id (latest content wins).
    """
    user_msg: _TranscriptLine | None = None
    assistants: dict[str, _TranscriptLine] = {}
    tool_results: dict[str, Any] = {}

    for msg in messages:
        if _is_tool_result(msg):
            for tr in _content_blocks(_get_content(msg), block_type="tool_result"):
                if tid := tr.get("tool_use_id"):
                    tool_results[str(tid)] = tr.get("content")
            continue

        role = _get_role(msg)

        if role == "user":
            if user_msg is not None and assistants:
                yield _Turn(
                    user_msg=user_msg,
                    assistant_msgs=tuple(assistants.values()),
                    tool_results=dict(tool_results),
                )
            user_msg = msg
            assistants = {}
            tool_results = {}
            continue

        if role == "assistant" and user_msg is not None:
            mid = _get_message_id(msg) or f"noid:{len(assistants)}"
            assistants[mid] = msg
            continue

    if user_msg is not None and assistants:
        yield _Turn(
            user_msg=user_msg,
            assistant_msgs=tuple(assistants.values()),
            tool_results=dict(tool_results),
        )


# ── Emit ───────────────────────────────────────────────


def _tool_calls(
    assistant_msgs: tuple[_TranscriptLine, ...],
) -> list[_ToolCall]:
    calls: list[_ToolCall] = []
    for am in assistant_msgs:
        for tu in _content_blocks(_get_content(am), block_type="tool_use"):
            calls.append(
                _ToolCall(
                    id=str(tu.get("id") or ""),
                    name=tu.get("name") or "unknown",
                    input=inp
                    if isinstance(
                        inp := tu.get("input"), (dict, list, str, int, float, bool)
                    )
                    else {},
                )
            )
    return calls


def _emit_turn(
    langfuse: Langfuse,
    *,
    session_id: str,
    turn_num: int,
    turn: _Turn,
    transcript_path: Path,
) -> None:
    user_text, user_meta = _truncate(_extract_text(_get_content(turn.user_msg)))
    last_assistant = turn.assistant_msgs[-1] if turn.assistant_msgs else turn.user_msg
    assistant_text, assistant_meta = _truncate(
        _extract_text(_get_content(last_assistant))
    )
    model = _get_model(turn.assistant_msgs[0] if turn.assistant_msgs else last_assistant)
    calls = _tool_calls(turn.assistant_msgs)

    for c in calls:
        if (raw := turn.tool_results.get(c["id"])) is not None:
            out_str = raw if isinstance(raw, str) else dumps(raw, ensure_ascii=False)
            out_trunc, out_meta = _truncate(out_str)
            c["output"] = out_trunc
            c["output_meta"] = out_meta
        else:
            c["output"] = None

    trace_name = f"Claude Code - Turn {turn_num}"

    with (
        propagate_attributes(
            session_id=session_id,
            trace_name=trace_name,
            tags=["claude-code"],
        ),
        langfuse.start_as_current_observation(
            name=trace_name,
            input={"role": "user", "content": user_text},
            metadata={
                "source": "claude-code",
                "session_id": session_id,
                "turn_number": turn_num,
                "transcript_path": str(transcript_path),
                "user_text": user_meta,
            },
        ) as trace,
    ):
        with langfuse.start_as_current_observation(
            name="Claude Response",
            as_type="generation",
            model=model,
            input={"role": "user", "content": user_text},
            output={"role": "assistant", "content": assistant_text},
            metadata={
                "assistant_text": assistant_meta,
                "tool_count": len(calls),
            },
        ):
            ...

        for c in calls:
            in_obj: Any = c["input"]
            in_meta: _TruncMeta | None = None
            if isinstance(in_obj, str):
                in_obj, in_meta = _truncate(in_obj)

            with langfuse.start_as_current_observation(
                name=f"Tool: {c['name']}",
                as_type="tool",
                input=in_obj,
                metadata={
                    "tool_name": c["name"],
                    "tool_id": c["id"],
                    "input_meta": in_meta,
                    "output_meta": c.get("output_meta"),
                },
            ) as tool_obs:
                tool_obs.update(output=c.get("output"))

        for c in calls:
            if c["name"] == "ExitPlanMode" and (plan := c["input"]):
                plan_str = (
                    plan if isinstance(plan, str) else dumps(plan, ensure_ascii=False)
                )
                plan_trunc, plan_meta = _truncate(plan_str)
                with langfuse.start_as_current_observation(
                    name="Plan",
                    output=plan_trunc,
                    metadata={"plan_meta": plan_meta},
                ):
                    ...

        trace.update(output={"role": "assistant", "content": assistant_text})


@contextmanager
def _langfuse_client(config: _Config) -> Iterator[Langfuse | None]:
    try:
        lf = Langfuse(
            public_key=config.public_key,
            secret_key=config.secret_key,
            host=config.host,
            timeout=10,
        )
    except Exception as e:
        getLogger().error("%s", e, exc_info=True)
        yield None
        return
    try:
        yield lf
    except Exception as e:
        getLogger().error("%s", e, exc_info=True)
    finally:
        with suppress(Exception):
            lf.shutdown()


# ── Main ───────────────────────────────────────────────


def _main() -> int:
    if (config := _read_config()) is None:
        return 0

    if (payload := _read_payload()) is None:
        return 0

    with _timed(f"hook (session={payload.session_id})"), _langfuse_client(config) as langfuse:
        if langfuse is None:
            return 0

        state = _load_state(payload.session_id)
        msgs, state = _read_new_messages(payload.transcript_path, state=state)

        if not msgs:
            _save_state(payload.session_id, state=state)
            return 0

        turns = list(_assemble_turns(msgs))
        if not turns:
            _save_state(payload.session_id, state=state)
            return 0

        emitted = 0
        for turn in turns:
            emitted += 1
            with _log_errors():
                _emit_turn(
                    langfuse,
                    session_id=payload.session_id,
                    turn_num=state.turn_count + emitted,
                    turn=turn,
                    transcript_path=payload.transcript_path,
                )

        state = replace(state, turn_count=state.turn_count + emitted)
        _save_state(payload.session_id, state=state)

        getLogger().info(
            "%s",
            f"Processed {emitted} turns (session={payload.session_id})",
        )

    return 0


exit(_main())
