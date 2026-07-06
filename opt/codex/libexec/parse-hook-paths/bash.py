#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser
from collections import deque
from collections.abc import Iterable, Iterator, MutableSequence, Sequence
from dataclasses import dataclass
from itertools import chain
from pathlib import Path, PurePath
from shlex import shlex
from subprocess import run
from sys import stdin, stdout

_AWK = Path(__file__).resolve(strict=True).parent / "apply_patch.awk"


@dataclass(frozen=True)
class _Heredoc:
    delimiter: str
    patch: bool
    strip_tabs: bool


def _is_assign(token: str) -> bool:
    name, sep, _ = token.partition("=")
    return bool(sep) and name.isidentifier()


def _is_redirection(token: str) -> bool:
    return bool(token) and all(chr in "<>&|" for chr in token)


def _short_program_option(token: str) -> tuple[str, str] | None:
    if not token.startswith("-") or token.startswith("--"):
        return None
    for index, option in enumerate(token[1:], start=2):
        if option in {"e", "f"}:
            return option, token[index:]
    return None


def _tokens(source: str) -> Sequence[str] | None:
    lex = shlex(source, posix=True, punctuation_chars=";&|()<>")
    lex.commenters = "#"
    lex.whitespace_split = True
    try:
        return tuple(lex)
    except ValueError:
        return None


def _commands(tokens: Iterable[str]) -> Iterator[Sequence[str]]:
    acc: MutableSequence[str] = []
    for token in tokens:
        if token and all(character in ";&|()" for character in token):
            if acc:
                yield acc
                acc = []
            continue
        acc.append(token)
    if acc:
        yield acc


def _unwrap_command(tokens: Iterator[str]) -> Sequence[str] | None:
    for name in tokens:
        if not _is_assign(name):
            break
    else:
        return None

    if name == "command":
        for name in tokens:
            if name == "--":
                name = next(tokens, "")
                break
            if not name.startswith("-") or name == "-":
                break
            options = set(name[1:])
            if options & {"v", "V"} or not options <= {"p"}:
                return None
        else:
            return None

    if not name:
        return None
    return name, *tokens


def _heredocs(command: Iterable[str], *, patch: bool) -> Iterator[_Heredoc]:
    tokens = iter(command)
    for token in tokens:
        if token != "<<":
            continue
        if (delimiter := next(tokens, None)) is None:
            break

        strip_tabs = delimiter.startswith("-")
        yield _Heredoc(
            delimiter=delimiter.removeprefix("-"),
            patch=patch,
            strip_tabs=strip_tabs,
        )


def _sed_paths(arguments: Iterable[str]) -> Iterator[str]:
    tokens = deque(arguments)
    has_script = False
    while tokens:
        token = tokens.popleft()
        if token.isdigit() and tokens and _is_redirection(tokens[0]):
            token = tokens.popleft()

        if _is_redirection(token):
            target = tokens.popleft() if tokens else ""
            if token in {"<", "<>"} and target:
                yield target
            continue

        if token == "--":
            if not has_script and tokens:
                has_script = True
                tokens.popleft()
            yield from tokens
            return

        if token in {"-e", "--expression"}:
            has_script = True
            if tokens:
                tokens.popleft()
            continue

        if token.startswith("--expression="):
            has_script = True
            continue

        if token == "--file":
            has_script = True
            if tokens:
                yield tokens.popleft()
            continue

        if token.startswith("--file="):
            has_script = True
            yield token.removeprefix("--file=")
            continue

        if program := _short_program_option(token):
            option, argument = program
            has_script = True
            if not argument and tokens:
                argument = tokens.popleft()
            if option == "f" and argument:
                yield argument
            continue

        if token.startswith("-") and token != "-":
            continue

        if not has_script:
            has_script = True
        else:
            yield token


def _scan(tokens: Iterable[str], *, read_too: bool) -> Iterator[_Heredoc | str]:
    for command_tokens in _commands(tokens):
        if not (command := _unwrap_command(iter(command_tokens))):
            continue
        arg0, *args = command
        name = PurePath(arg0).name

        yield from _heredocs(args, patch=name == "apply_patch")
        if read_too and name == "sed":
            yield from _sed_paths(args)


def _read_too() -> bool:
    parser = ArgumentParser()
    parser.add_argument("read_too", type=int, choices=(0, 1))
    return bool(parser.parse_args().read_too)


def _run_patch(patch: Iterable[str]) -> None:
    source = "\n".join(chain(patch, ("",)))
    stdout.buffer.flush()
    run([_AWK], input=source.encode(), check=True)


def _heredoc_body(document: _Heredoc, *, lines: Iterator[str]) -> Iterator[str]:
    for raw_line in lines:
        line = raw_line.removesuffix("\n").removesuffix("\r")
        candidate = line.lstrip("\t") if document.strip_tabs else line
        if candidate == document.delimiter:
            return
        yield candidate


def _consume_heredoc(document: _Heredoc, *, lines: Iterator[str]) -> None:
    body = _heredoc_body(document, lines=lines)
    if document.patch:
        _run_patch(body)
        return
    for _ in body:
        ...


def _main() -> None:
    read_too = _read_too()
    logical_line: MutableSequence[str] = []
    lines = iter(stdin)

    for raw_line in lines:
        if raw_line.endswith("\\\n"):
            logical_line.append(raw_line[:-2])
            continue
        logical_line.append(raw_line)
        if (tokens := _tokens("".join(logical_line))) is None:
            continue

        for event in _scan(tokens, read_too=read_too):
            match event:
                case _Heredoc():
                    _consume_heredoc(event, lines=lines)
                case str() if event:
                    stdout.buffer.write(event.encode() + b"\0")
        logical_line.clear()


_main()
