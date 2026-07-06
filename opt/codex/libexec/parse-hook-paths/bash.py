#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser, Namespace
from collections import deque
from collections.abc import Iterable, Iterator, MutableSequence, Sequence
from dataclasses import dataclass
from itertools import chain
from pathlib import Path
from shlex import shlex
from subprocess import run
from sys import stdin, stdout

_AWK = Path(__file__).resolve(strict=True).parent / "apply_patch.awk"


@dataclass(frozen=True)
class _Heredoc:
    delimiter: str
    patch: bool
    strip_tabs: bool


@dataclass(frozen=True)
class _Command:
    name: str
    arguments: Sequence[str]


def _tokens(source: str) -> Iterator[str]:
    lex = shlex(source, posix=True, punctuation_chars=";&|()<>")
    lex.commenters = "#"
    lex.whitespace_split = True
    return lex


def _run_patch(patch: Iterable[str]) -> None:
    source = "\n".join(chain(patch, ("",)))
    stdout.buffer.flush()
    run([_AWK], input=source.encode(), check=True)


def _emit(path: str) -> None:
    if path:
        stdout.buffer.write(path.encode() + b"\0")


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


def _is_assignment(token: str) -> bool:
    name, sep, _ = token.partition("=")
    return bool(
        sep
        and name
        and (name[0].isalpha() or name[0] == "_")
        and all(chr.isalnum() or chr == "_" for chr in name)
    )


def _parse_command(command: Sequence[str]) -> _Command | None:
    index = 0
    while index < len(command) and _is_assignment(command[index]):
        index += 1
    if index < len(command) and command[index] == "command":
        index += 1
        while index < len(command) and command[index] == "-p":
            index += 1
        if index < len(command) and command[index] in {"-v", "-V"}:
            return None
        if index < len(command) and command[index] == "--":
            index += 1
    if index >= len(command):
        return None
    return _Command(
        name=Path(command[index]).name,
        arguments=command[index + 1 :],
    )


def _heredocs(command: Iterable[str], *, patch: bool) -> Iterator[_Heredoc]:
    tokens = iter(command)
    for token in tokens:
        if token != "<<":
            continue
        if (delimiter := next(tokens, None)) is None:
            break
        strip_tabs = delimiter.startswith("-")
        if strip_tabs:
            delimiter = delimiter[1:]
        yield _Heredoc(
            delimiter=delimiter,
            patch=patch,
            strip_tabs=strip_tabs,
        )


def _is_redirection(token: str) -> bool:
    return bool(token) and all(character in "<>&|" for character in token)


def _short_program_option(token: str) -> tuple[str, str] | None:
    if not token.startswith("-") or token.startswith("--"):
        return None
    for index, option in enumerate(token[1:], start=2):
        if option in {"e", "f"}:
            return option, token[index:]
    return None


def _sed_paths(arguments: Sequence[str]) -> Iterator[str]:
    has_script = False
    index = 0
    while index < len(arguments):
        token = arguments[index]
        if (
            token.isdigit()
            and index + 1 < len(arguments)
            and _is_redirection(arguments[index + 1])
        ):
            index += 1
            token = arguments[index]
        if _is_redirection(token):
            index += 1
            if index < len(arguments) and token.startswith("<") and "<<" not in token:
                yield arguments[index]
            index += 1
            continue
        if token == "--":
            index += 1
            if not has_script and index < len(arguments):
                has_script = True
                index += 1
            yield from arguments[index:]
            return
        if token in {"-e", "--expression"}:
            has_script = True
            index += 2
            continue
        if token.startswith("--expression="):
            has_script = True
            index += 1
            continue
        if token == "--file":
            has_script = True
            if index + 1 < len(arguments):
                yield arguments[index + 1]
            index += 2
            continue
        if token.startswith("--file="):
            has_script = True
            yield token.removeprefix("--file=")
            index += 1
            continue
        if program := _short_program_option(token):
            option, argument = program
            has_script = True
            if not argument and index + 1 < len(arguments):
                index += 1
                argument = arguments[index]
            if option == "f":
                yield argument
            index += 1
            continue
        if token.startswith("-") and token != "-":
            index += 1
            continue
        if not has_script:
            has_script = True
        else:
            yield token
        index += 1


def _scan(source: str, *, read_too: bool) -> Iterator[_Heredoc | str]:
    for tokens in _commands(_tokens(source)):
        if (command := _parse_command(tokens)) is None:
            continue
        yield from _heredocs(
            command.arguments,
            patch=command.name == "apply_patch",
        )
        if read_too and command.name == "sed":
            yield from _sed_paths(command.arguments)


def _parse_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument("read_too", type=int, choices=(0, 1))
    return parser.parse_args()


def _main() -> None:
    args = _parse_args()
    pending = deque[_Heredoc]()
    body: MutableSequence[str] = []
    logical_line = ""

    for raw_line in stdin:
        line = raw_line.removesuffix("\n").removesuffix("\r")
        if pending:
            document = pending[0]
            candidate = line.lstrip("\t") if document.strip_tabs else line
            if candidate == document.delimiter:
                if document.patch:
                    _run_patch(body)
                pending.popleft()
                body = []
            elif document.patch:
                body.append(candidate)
            continue

        if raw_line.endswith("\\\n"):
            logical_line += raw_line[:-2]
            continue
        logical_line += raw_line
        try:
            for event in _scan(logical_line, read_too=args.read_too):
                match event:
                    case _Heredoc():
                        pending.append(event)
                    case str():
                        _emit(event)
        except ValueError as error:
            if str(error) not in {"No closing quotation", "No escaped character"}:
                raise
            continue
        logical_line = ""


_main()
