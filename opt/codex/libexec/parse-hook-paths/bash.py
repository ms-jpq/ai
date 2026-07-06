#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser, Namespace
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
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


def _tokens(source: str) -> Iterator[str]:
    lexer = shlex(source, posix=True, punctuation_chars=";&|()<>")
    lexer.commenters = "#"
    lexer.whitespace_split = True
    return lexer


def _commands(tokens: Iterable[str]) -> list[list[str]]:
    commands: list[list[str]] = [[]]
    for token in tokens:
        if token and all(character in ";&|()" for character in token):
            if commands[-1]:
                commands.append([])
            continue
        commands[-1].append(token)
    return [command for command in commands if command]


def _command_index(command: list[str]) -> int | None:
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
    return index if index < len(command) else None


def _emit(path: str) -> None:
    if path:
        stdout.buffer.write(path.encode() + b"\0")


def _heredocs(command: list[str], *, patch: bool) -> list[_Heredoc]:
    documents: list[_Heredoc] = []
    index = 0
    while index < len(command):
        if command[index] != "<<":
            index += 1
            continue
        index += 1
        if index >= len(command):
            break
        delimiter = command[index]
        strip_tabs = delimiter.startswith("-")
        if strip_tabs:
            delimiter = delimiter[1:]
        documents.append(
            _Heredoc(delimiter=delimiter, patch=patch, strip_tabs=strip_tabs)
        )
        index += 1
    return documents


def _is_assignment(token: str) -> bool:
    name, separator, _ = token.partition("=")
    return bool(
        separator
        and name
        and (name[0].isalpha() or name[0] == "_")
        and all(character.isalnum() or character == "_" for character in name)
    )


def _is_redirection(token: str) -> bool:
    return bool(token) and all(character in "<>&|" for character in token)


def _parse_sed(arguments: list[str]) -> None:
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
                _emit(arguments[index])
            index += 1
            continue
        if token == "--":
            index += 1
            if not has_script and index < len(arguments):
                has_script = True
                index += 1
            for path in arguments[index:]:
                _emit(path)
            return
        if token in {"-e", "--expression"}:
            has_script = True
            index += 2
            continue
        if token.startswith("-e") or token.startswith("--expression="):
            has_script = True
            index += 1
            continue
        if token in {"-f", "--file"}:
            has_script = True
            if index + 1 < len(arguments):
                _emit(arguments[index + 1])
            index += 2
            continue
        if token.startswith("-f"):
            has_script = True
            _emit(token[2:])
            index += 1
            continue
        if token.startswith("--file="):
            has_script = True
            _emit(token.removeprefix("--file="))
            index += 1
            continue
        if token.startswith("-") and token != "-":
            option_argument = token[1:]
            option_argument = option_argument[
                min(
                    (
                        position
                        for position in (
                            option_argument.find("e"),
                            option_argument.find("f"),
                        )
                        if position >= 0
                    ),
                    default=len(option_argument),
                ) :
            ]
            if option_argument.startswith("e"):
                has_script = True
                if option_argument == "e":
                    index += 1
            elif option_argument.startswith("f"):
                has_script = True
                path = option_argument[1:]
                if not path and index + 1 < len(arguments):
                    index += 1
                    path = arguments[index]
                _emit(path)
            index += 1
            continue
        if not has_script:
            has_script = True
        else:
            _emit(token)
        index += 1


def _scan(source: str, *, read_too: bool) -> list[_Heredoc]:
    documents: list[_Heredoc] = []
    for command in _commands(_tokens(source)):
        if (index := _command_index(command)) is None:
            continue
        name = Path(command[index]).name
        patch = name == "apply_patch"
        documents.extend(_heredocs(command[index + 1 :], patch=patch))
        if read_too and name == "sed":
            _parse_sed(command[index + 1 :])
    return documents


def _run_patch(body: list[str]) -> None:
    source = "\n".join(body) + "\n"
    stdout.buffer.flush()
    run([_AWK], input=source.encode(), check=True)


def _parse_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument("read_too", type=int, choices=(0, 1))
    return parser.parse_args()


def _main() -> None:
    args = _parse_args()
    pending: list[_Heredoc] = []
    body: list[str] = []
    logical_line = ""

    for raw_line in stdin:
        line = raw_line.removesuffix("\n").removesuffix("\r")
        if pending:
            document = pending[0]
            candidate = line.lstrip("\t") if document.strip_tabs else line
            if candidate == document.delimiter:
                if document.patch:
                    _run_patch(body)
                pending.pop(0)
                body = []
            elif document.patch:
                body.append(candidate)
            continue

        if raw_line.endswith("\\\n"):
            logical_line += raw_line[:-2]
            continue
        logical_line += raw_line
        try:
            pending.extend(_scan(logical_line, read_too=args.read_too))
        except ValueError as error:
            if str(error) not in {"No closing quotation", "No escaped character"}:
                raise
            continue
        logical_line = ""


_main()
