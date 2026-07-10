#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser
from collections.abc import Iterable, Iterator, MutableSequence, Sequence, Set
from contextlib import suppress
from dataclasses import dataclass
from itertools import chain
from os.path import expanduser, expandvars
from pathlib import Path, PurePath
from shlex import shlex
from subprocess import run
from sys import stdin, stdout

_AWK = Path(__file__).resolve(strict=True).parent / "apply_patch.awk"
_EXPANSION = "\0"


@dataclass(frozen=True)
class _PathCommand:
    include_writes: bool = False
    path_options_are_program: bool = False
    value_options_are_program: bool = False
    yield_operands: bool = False

    named_path_options: Set[str] = frozenset()
    path_options: Set[str] = frozenset()
    two_value_options: Set[str] = frozenset()
    value_options: Set[str] = frozenset()


@dataclass(frozen=True)
class _Heredoc:
    delimiter: str
    patch: bool
    strip_tabs: bool


@dataclass(frozen=True)
class _PatchFile:
    path: str


_PATCH_COMMANDS = {"apply_patch", "applypatch"}
_PATH_COMMANDS = {
    "base64": _PathCommand(
        include_writes=True,
        yield_operands=True,
        path_options={"-i", "--input"},
    ),
    "cat": _PathCommand(
        yield_operands=True,
        include_writes=True,
    ),
    "cut": _PathCommand(
        include_writes=True,
        yield_operands=True,
        value_options={
            "-b",
            "-c",
            "-d",
            "-f",
            "--bytes",
            "--characters",
            "--delimiter",
            "--fields",
        },
    ),
    "grep": _PathCommand(
        include_writes=True,
        path_options={"-f", "--file", "--exclude-from"},
        value_options={
            "-A",
            "-B",
            "-C",
            "-D",
            "-d",
            "-e",
            "-m",
            "--after-context",
            "--before-context",
            "--binary-files",
            "--context",
            "--devices",
            "--directories",
            "--exclude",
            "--exclude-dir",
            "--include",
            "--label",
            "--max-count",
            "--regexp",
        },
    ),
    "head": _PathCommand(
        include_writes=True,
        yield_operands=True,
        value_options={"-c", "-n", "--bytes", "--lines"},
    ),
    "ls": _PathCommand(
        yield_operands=True,
        include_writes=True,
    ),
    "nl": _PathCommand(
        yield_operands=True,
        include_writes=True,
        value_options={
            "-b",
            "-d",
            "-f",
            "-h",
            "-i",
            "-l",
            "-n",
            "-s",
            "-v",
            "-w",
            "--body-numbering",
            "--footer-numbering",
            "--header-numbering",
            "--increment",
            "--join-blank-lines",
            "--line-increment",
            "--line-number-format",
            "--no-renumber",
            "--number-format",
            "--number-separator",
            "--number-width",
            "--page-increment",
            "--section-delimiter",
            "--starting-line-number",
        },
    ),
    "perl": _PathCommand(
        yield_operands=True,
        include_writes=True,
        value_options={"-0", "-e", "-E", "-I", "-m", "-M", "-x"},
    ),
    "rg": _PathCommand(
        include_writes=True,
        path_options={"-f", "--file"},
        value_options={
            "-A",
            "-B",
            "-C",
            "-E",
            "-e",
            "-g",
            "-M",
            "-m",
            "-T",
            "-t",
            "--after-context",
            "--before-context",
            "--context",
            "--context-separator",
            "--engine",
            "--glob",
            "--glob-case-insensitive",
            "--iglob",
            "--max-columns",
            "--max-count",
            "--max-depth",
            "--path-separator",
            "--regexp",
            "--replace",
            "--sort",
            "--sortr",
            "--type",
            "--type-add",
            "--type-clear",
            "--type-not",
        },
    ),
    "stat": _PathCommand(
        yield_operands=True,
        include_writes=True,
    ),
    "tail": _PathCommand(
        yield_operands=True,
        include_writes=True,
        value_options={"-c", "-n", "--bytes", "--lines", "--pid", "--sleep-interval"},
    ),
    "wc": _PathCommand(
        yield_operands=True,
        include_writes=True,
    ),
    "awk": _PathCommand(
        path_options_are_program=True,
        value_options={"-F", "-v", "--assign", "--field-separator"},
        path_options={"-f", "--file"},
    ),
    "gawk": _PathCommand(
        path_options_are_program=True,
        value_options={"-F", "-v", "--assign", "--field-separator"},
        path_options={"-f", "--file"},
    ),
    "gsed": _PathCommand(
        path_options_are_program=True,
        path_options={"-f", "--file"},
        value_options_are_program=True,
        value_options={"-e", "--expression"},
    ),
    "jq": _PathCommand(
        path_options_are_program=True,
        named_path_options={"--argfile", "--rawfile", "--slurpfile"},
        path_options={"-f", "--from-file"},
        two_value_options={"--arg", "--argjson"},
        value_options={"-L", "--indent"},
    ),
    "sed": _PathCommand(
        path_options_are_program=True,
        value_options_are_program=True,
        path_options={"-f", "--file"},
        value_options={"-e", "--expression"},
    ),
    "tee": _PathCommand(
        yield_operands=True,
        include_writes=True,
    ),
}


def _is_redirection(token: str) -> bool:
    return bool(token) and all(chr in "<>&|" for chr in token)


def _option_value(
    token: str, tokens: Iterator[str], options: Set[str]
) -> tuple[str, str] | None:
    option, sep, argument = token.partition("=")
    if sep and option in options:
        return option, argument
    if token in options:
        return token, next(tokens, "")
    if token.startswith("-") and not token.startswith("--"):
        for index, short_option in enumerate(token[1:], start=2):
            short = f"-{short_option}"
            if short in options:
                return short, token[index:] or next(tokens, "")
    return None


def _substitution_step(
    source: str, *, index: int, depth: int, quote: str
) -> tuple[int, int, str]:
    chr = source[index]
    match quote, chr:
        case _, _ if chr == quote:
            return index + 1, depth, ""
        case "", "'" | '"':
            return index + 1, depth, chr
        case "", "(":
            return index + 1, depth + 1, quote
        case "", ")":
            return index + 1, depth - 1, quote
        case _:
            return index + 1, depth, quote


def _mask_substitution(source: str, *, start: int) -> int:
    index = start + 2
    depth = 1
    quote = ""

    while index < len(source):
        index, depth, quote = _substitution_step(
            source, index=index, depth=depth, quote=quote
        )
        if not depth:
            return index
    return index


def _mask_backticks(source: str, *, start: int) -> int:
    index = start + 1
    while index < len(source):
        match source[index]:
            case "\\":
                index += 2
                continue
            case "`":
                return index + 1
        index += 1
    return index


def _masked_chunk(source: str, *, index: int, quote: str) -> tuple[int, str, str]:
    character = source[index]
    match quote, character:
        case _, _ if character == quote:
            return index + 1, "", character
        case "", "'" | '"':
            return index + 1, character, character
        case "" | '"', "$" if source.startswith("$(", index):
            return _mask_substitution(source, start=index), quote, _EXPANSION
        case "", "<" | ">" if source.startswith(("<(", ">("), index):
            return _mask_substitution(source, start=index), quote, _EXPANSION
        case "" | '"', "`":
            return _mask_backticks(source, start=index), quote, _EXPANSION
        case _:
            return index + 1, quote, character


def _masked_expansions(source: str) -> str:
    chunks: list[str] = []
    index = 0
    quote = ""
    while index < len(source):
        index, quote, text = _masked_chunk(source, index=index, quote=quote)
        chunks.append(text)
    return "".join(chunks)


def _tokens(source: str) -> Sequence[str] | None:
    lex = shlex(_masked_expansions(source), posix=True, punctuation_chars=";&|()<>")
    lex.commenters = "#"
    lex.whitespace_split = True
    with suppress(ValueError):
        return tuple(lex)
    return None


def _commands(tokens: Iterable[str]) -> Iterator[Sequence[str]]:
    acc: MutableSequence[str] = []
    for token in tokens:
        match token:
            case _ if token and all(chr in ";&|()" for chr in token):
                if acc:
                    yield acc
                    acc = []
            case _:
                acc.append(token)
    if acc:
        yield acc


def _unwrap_command(tokens: Iterator[str]) -> Sequence[str] | None:
    for name in tokens:
        assigned, sep, _ = name.partition("=")
        if not (sep and assigned.isidentifier()):
            break
    else:
        return None

    match name:
        case "":
            return None
        case "command":
            for name in tokens:
                match name:
                    case "--":
                        name = next(tokens, "")
                        break
                    case _ if not name.startswith("-"):
                        break
                    case _ if (options := set(name[1:])) and (
                        options & {"v", "V"} or not options <= {"p"}
                    ):
                        return None
            else:
                return None

    return name, *tokens


def _heredoc(tokens: Iterator[str], *, patch: bool) -> _Heredoc | None:
    match next(tokens, ""):
        case "":
            return None
        case "-":
            return _Heredoc(delimiter=next(tokens, ""), patch=patch, strip_tabs=True)
        case delimiter:
            return _Heredoc(
                delimiter=delimiter.removeprefix("-"),
                patch=patch,
                strip_tabs=delimiter.startswith("-"),
            )


def _heredocs(command: Iterable[str], *, patch: bool) -> Iterator[_Heredoc]:
    tokens = iter(command)
    for token in tokens:
        match token:
            case "<<" if document := _heredoc(tokens, patch=patch):
                yield document
            case _:
                ...


def _redirect_target(
    token: str, tokens: Iterator[str], *, include_writes: bool
) -> str | None:
    match token:
        case "<<" | "<<-":
            _heredoc(tokens, patch=False)
        case "<" | "<>":
            return next(tokens, "")
        case ">" | ">>" | ">|" if include_writes:
            return next(tokens, "")
        case _ if _is_redirection(token):
            next(tokens, None)
    return None


def _path_operands(arguments: Iterable[str], *, spec: _PathCommand) -> Iterator[str]:
    tokens = iter(arguments)
    yield_operands = spec.yield_operands
    while token := next(tokens, None):
        if token.isdigit() and (following := next(tokens, None)):
            if _is_redirection(following):
                token = following
            else:
                tokens = chain((following,), tokens)
        match token:
            case _ if target := _redirect_target(
                token, tokens, include_writes=spec.include_writes
            ):
                yield target
            case _ if _is_redirection(token):
                ...
            case "--":
                if not yield_operands:
                    next(tokens, None)
                yield from tokens
                return
            case _ if value := _option_value(token, tokens, spec.path_options):
                _, argument = value
                if argument:
                    yield argument
                if spec.path_options_are_program:
                    yield_operands = True
            case _ if token in spec.named_path_options:
                next(tokens, None)
                if argument := next(tokens, ""):
                    yield argument
            case _ if token in spec.two_value_options:
                next(tokens, None)
                next(tokens, None)
            case _ if value := _option_value(token, tokens, spec.value_options):
                if spec.value_options_are_program:
                    yield_operands = True
            case _ if token.startswith("-") and token != "-":
                ...
            case _ if yield_operands:
                yield token
            case _:
                yield_operands = True


def _command_events(
    command: Sequence[str], *, read_too: bool
) -> Iterator[_Heredoc | _PatchFile | str]:
    arg0, *args = command
    name = PurePath(arg0).name

    yield from _heredocs(args, patch=name in _PATCH_COMMANDS)
    if not read_too:
        return

    if name in _PATCH_COMMANDS:
        tokens = iter(args)
        for token in tokens:
            if token == "<" and (path := next(tokens, "")):
                yield _PatchFile(path=path)

    elif spec := _PATH_COMMANDS.get(name):
        yield from _path_operands(args, spec=spec)


def _scan(
    tokens: Iterable[str], *, read_too: bool
) -> Iterator[_Heredoc | _PatchFile | str]:
    for command_tokens in _commands(tokens):
        if not (command := _unwrap_command(iter(command_tokens))):
            continue
        yield from _command_events(command, read_too=read_too)


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


def _consume_heredoc(document: _Heredoc, *, lines: Iterator[str]) -> None:
    body = _heredoc_body(document, lines=lines)
    if document.patch:
        source = "\n".join(chain(body, ("",)))
        stdout.flush()
        run([_AWK], input=source.encode(), check=True)
        return
    for _ in body:
        ...


def _emit(path: str) -> None:
    if _EXPANSION in path:
        return
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
