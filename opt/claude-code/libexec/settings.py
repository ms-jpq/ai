#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from collections.abc import Callable, Iterable, Iterator, Mapping
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

_TOOL_ORDER = {"Read": 0, "Write": 1, "Edit": 2}


def _json(obj: object) -> str:
    return dumps(obj, ensure_ascii=False, sort_keys=True, indent=2)


def _specificity(origins: Mapping[str, int]) -> Callable[[str], tuple[int, int, str]]:
    def _key(path: str) -> tuple[int, int, str]:
        parts = PurePosixPath(path).parts
        origin = origins.get(parts[0], 3) if parts else 3
        segments = sum(1 for p in parts if p not in origins)
        return (origin, segments, path)

    return _key


_fs_key = _specificity({"/": 0, "~": 1, ".": 2})
_perm_path_key = _specificity({"//": 0, "~": 1, "/": 2, ".": 2})


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
        pat = _deny_pattern(p)
        for op in ("Read", "Grep", "Glob"):
            yield f"{op}({pat})"
    for p in deny_write:
        pat = _deny_pattern(p)
        for op in ("Write", "Edit"):
            yield f"{op}({pat})"


def _perm_key(entry: str) -> tuple[int, int, int, str, int]:
    if "(" in entry:
        tool, rest = entry.split("(", 1)
        inner = rest.rstrip(")")
        return (1, *_perm_path_key(inner), _TOOL_ORDER.get(tool, 3))
    return (0, 0, 0, entry, 0)


with nullcontext():
    _settings = loads(_SETTINGS.read_text())

    _fs = _settings.setdefault("sandbox", {}).setdefault("filesystem", {})
    _perms = _settings.setdefault("permissions", {})

    _deny_read = {*_fs.get("denyRead", [])}
    _deny_write = {*_fs.get("denyWrite", [])}
    _deny_write_only = _deny_write - _deny_read

    _deny_write |= _deny_read

    _perm_deny = {*_deny_entries(_deny_read, _deny_write)}

    _fs["allowRead"] = sorted(_fs.get("allowRead", []), key=_fs_key)
    _fs["allowWrite"] = sorted(_fs.get("allowWrite", []), key=_fs_key)
    _fs["denyRead"] = sorted(_deny_read, key=_fs_key)
    _fs["denyWrite"] = sorted(_deny_write, key=_fs_key)

    _perms["allow"] = sorted(_perms.get("allow", []), key=_perm_key)
    _perms["deny"] = sorted(_perm_deny, key=_perm_key)

    _SETTINGS.write_text(_json(_settings) + linesep)

    _summary = {
        "allowRead": _fs["allowRead"],
        "allowWrite": _fs["allowWrite"],
        "denyRead": _fs["denyRead"],
        "denyWrite (exclusive)": sorted(_deny_write_only, key=_fs_key),
    }
    getLogger().info("%s", _json(_summary))
