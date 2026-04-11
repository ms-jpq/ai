#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from collections.abc import Iterable, Iterator
from contextlib import nullcontext
from json import dumps, loads
from logging import INFO, basicConfig, captureWarnings, getLogger
from os import linesep
from pathlib import Path, PurePosixPath

with nullcontext():
    captureWarnings(True)
    basicConfig(format="%(message)s", level=INFO)

_SELF = Path(__file__).resolve()
_SETTINGS = _SELF.parent.parent / "settings.json"

_ORIGIN_ORDER = {"//": 0, "~": 1, "/": 2, ".": 2}
_TOOL_ORDER = {"Read": 0, "Write": 1, "Edit": 2}


def _json(obj: object) -> str:
    return dumps(obj, ensure_ascii=False, sort_keys=True, indent=2)


def _specificity(path: str) -> tuple[int, int, str]:
    parts = PurePosixPath(path).parts
    origin = _ORIGIN_ORDER.get(parts[0], 3) if parts else 3
    segments = sum(1 for p in parts if p not in ("/", "~"))
    return (origin, segments, path)


def _to_perm_path(sandbox_path: str) -> str:
    p = PurePosixPath(sandbox_path)
    if p.parts[0] in ("~", "."):
        return sandbox_path
    if p.is_absolute():
        return "/" + sandbox_path
    return sandbox_path


def _deny_pattern(sandbox_path: str) -> str:
    p = PurePosixPath(_to_perm_path(sandbox_path))
    if sandbox_path.endswith("/"):
        return str(p / "**")
    return str(p)


def _deny_entries(deny_read: Iterable[str], deny_write: Iterable[str]) -> Iterator[str]:
    for p in deny_read:
        yield f"Read({_deny_pattern(p)})"
    for p in deny_write:
        yield f"Write({_deny_pattern(p)})"
        yield f"Edit({_deny_pattern(p)})"


def _perm_key(entry: str) -> tuple[int, int, int, str, int]:
    if "(" in entry:
        tool, rest = entry.split("(", 1)
        inner = rest.rstrip(")")
        return (1, *_specificity(inner), _TOOL_ORDER.get(tool, 3))
    return (0, 0, 0, entry, 0)


with nullcontext():
    _settings = loads(_SETTINGS.read_text())

    _fs = _settings.setdefault("sandbox", {}).setdefault("filesystem", {})
    _perms = _settings.setdefault("permissions", {})

    _deny_read = {*_fs.get("denyRead", [])}
    _deny_write = {*_fs.get("denyWrite", [])}
    _deny_write_only = _deny_write - _deny_read

    _deny_write |= _deny_read

    _perm_deny = {*_perms.get("deny", [])}
    _perm_deny |= {*_deny_entries(_deny_read, _deny_write)}

    _fs["allowRead"] = sorted(_fs.get("allowRead", []), key=_specificity)
    _fs["allowWrite"] = sorted(_fs.get("allowWrite", []), key=_specificity)
    _fs["denyRead"] = sorted(_deny_read, key=_specificity)
    _fs["denyWrite"] = sorted(_deny_write, key=_specificity)

    _perms["allow"] = sorted(_perms.get("allow", []), key=_perm_key)
    _perms["deny"] = sorted(_perm_deny, key=_perm_key)

    _SETTINGS.write_text(_json(_settings) + linesep)

    _summary = {
        "filesystem": {
            "allowRead": _fs["allowRead"],
            "allowWrite": _fs["allowWrite"],
            "denyRead": _fs["denyRead"],
            "denyWrite (exclusive)": sorted(_deny_write_only, key=_specificity),
        }
    }
    getLogger().info("%s", _json(_summary))
