#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser
from collections.abc import Iterable, Iterator, MutableSequence, Sequence
from contextlib import suppress
from dataclasses import dataclass
from itertools import chain
from os.path import expanduser, expandvars
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


@dataclass(frozen=True)
class _PatchFile:
    path: str


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
    with suppress(ValueError):
        return tuple(lex)
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
            match name:
                case "--":
                    name = next(tokens, "")
                    break
                case "-" | _ if not name.startswith("-"):
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

        yield _Heredoc(
            delimiter=delimiter.removeprefix("-"),
            patch=patch,
            strip_tabs=delimiter.startswith("-"),
        )


def _patch_redirects(arguments: Iterable[str]) -> Iterator[_PatchFile]:
    tokens = iter(arguments)
    for token in tokens:
        if token == "<" and (path := next(tokens, "")):
            yield _PatchFile(path=path)


def _sed_paths(arguments: Iterable[str]) -> Iterator[str]:
    tokens = iter(arguments)
    has_script = False
    while token := next(tokens, None):
        if token.isdigit() and (following := next(tokens, None)) is not None:
            if _is_redirection(following):
                token = following
            else:
                tokens = chain((following,), tokens)

        match token:
            case "<" | "<>":
                if target := next(tokens, ""):
                    yield target
                continue
            case _ if _is_redirection(token):
                next(tokens, None)
                continue
            case "--":
                if not has_script:
                    has_script = True
                    next(tokens, None)
                yield from tokens
                return
            case "-e" | "--expression":
                has_script = True
                next(tokens, None)
                continue
            case _ if token.startswith("--expression="):
                has_script = True
                continue
            case "--file":
                has_script = True
                if argument := next(tokens, ""):
                    yield argument
                continue
            case _ if (argument := token.removeprefix("--file=")) != token:
                has_script = True
                yield argument
                continue

        if program := _short_program_option(token):
            option, argument = program
            has_script = True
            if not argument:
                argument = next(tokens, "")
            if option == "f" and argument:
                yield argument
            continue

        if token.startswith("-") and token != "-":
            continue

        if not has_script:
            has_script = True
        else:
            yield token


def _cat_paths(arguments: Iterable[str]) -> Iterator[str]:
    tokens = iter(arguments)
    while token := next(tokens, None):
        if token.isdigit() and (following := next(tokens, None)) is not None:
            if _is_redirection(following):
                token = following
            else:
                tokens = chain((following,), tokens)
        match token:
            case "--":
                yield from tokens
                return
            case "<<" | "<<-":
                next(tokens, None)
                continue
            case "<" | "<>" | ">" | ">>" | ">|":
                if target := next(tokens, ""):
                    yield target
                continue
            case _ if _is_redirection(token):
                next(tokens, None)
                continue
        if token.startswith("-"):
            continue
        yield token


def _scan(
    tokens: Iterable[str], *, read_too: bool
) -> Iterator[_Heredoc | _PatchFile | str]:
    for command_tokens in _commands(tokens):
        if not (command := _unwrap_command(iter(command_tokens))):
            continue
        arg0, *args = command
        name = PurePath(arg0).name

        yield from _heredocs(args, patch=name == "apply_patch")
        match name:
            case "apply_patch" if read_too:
                yield from _patch_redirects(args)
            case "sed" if read_too:
                yield from _sed_paths(args)
            case "cat" if read_too:
                yield from _cat_paths(args)


def _read_too() -> bool:
    parser = ArgumentParser()
    parser.add_argument("read_too", type=int, choices=(0, 1))
    return bool(parser.parse_args().read_too)


def _heredoc_body(document: _Heredoc, *, lines: Iterator[str]) -> Iterator[str]:
    for raw_line in lines:
        line = raw_line.removesuffix("\n").removesuffix("\r")
        candidate = line.lstrip("\t") if document.strip_tabs else line
        if candidate == document.delimiter:
            return
        yield candidate


def _run_patch(patch: Iterable[str]) -> None:
    source = "\n".join(chain(patch, ("",)))
    stdout.flush()
    run([_AWK], input=source.encode(), check=True)


def _consume_heredoc(document: _Heredoc, *, lines: Iterator[str]) -> None:
    body = _heredoc_body(document, lines=lines)
    if document.patch:
        _run_patch(body)
        return
    for _ in body:
        pass


def _emit(path: str) -> None:
    stdout.write(f"{expanduser(expandvars(path))}\0")


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
                case _PatchFile():
                    _emit(event.path)
                case str() if event:
                    _emit(event)
        logical_line.clear()


_main()
