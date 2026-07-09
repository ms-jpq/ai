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
class _Heredoc:
    delimiter: str
    patch: bool
    strip_tabs: bool


@dataclass(frozen=True)
class _PatchFile:
    path: str


@dataclass(frozen=True)
class _PathCommand:
    path_options: Set[str]
    value_options: Set[str]
    named_path_options: Set[str] = frozenset()
    program_value_options: Set[str] = frozenset()
    two_value_options: Set[str] = frozenset()
    yield_operands: bool = False
    path_options_are_program: bool = False
    include_writes: bool = False


_PATCH_COMMANDS = {"apply_patch", "applypatch"}
_CAT_COMMANDS = {"cat", "tee"}
_PATH_COMMANDS = {
    "base64": _PathCommand(
        path_options={"-i", "--input"},
        value_options={"-i", "--input"},
        yield_operands=True,
        include_writes=True,
    ),
    "cut": _PathCommand(
        path_options=frozenset(),
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
        yield_operands=True,
        include_writes=True,
    ),
    "grep": _PathCommand(
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
        include_writes=True,
    ),
    "head": _PathCommand(
        path_options=frozenset(),
        value_options={"-c", "-n", "--bytes", "--lines"},
        yield_operands=True,
        include_writes=True,
    ),
    "ls": _PathCommand(
        path_options=frozenset(),
        value_options=frozenset(),
        yield_operands=True,
        include_writes=True,
    ),
    "nl": _PathCommand(
        path_options=frozenset(),
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
        yield_operands=True,
        include_writes=True,
    ),
    "perl": _PathCommand(
        path_options=frozenset(),
        value_options={"-0", "-e", "-E", "-I", "-m", "-M", "-x"},
        yield_operands=True,
        include_writes=True,
    ),
    "rg": _PathCommand(
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
        include_writes=True,
    ),
    "stat": _PathCommand(
        path_options=frozenset(),
        value_options=frozenset(),
        yield_operands=True,
        include_writes=True,
    ),
    "tail": _PathCommand(
        path_options=frozenset(),
        value_options={"-c", "-n", "--bytes", "--lines", "--pid", "--sleep-interval"},
        yield_operands=True,
        include_writes=True,
    ),
    "wc": _PathCommand(
        path_options=frozenset(),
        value_options=frozenset(),
        yield_operands=True,
        include_writes=True,
    ),
    "awk": _PathCommand(
        value_options={"-F", "-v", "--assign", "--field-separator"},
        path_options={"-f", "--file"},
        path_options_are_program=True,
    ),
    "gawk": _PathCommand(
        value_options={"-F", "-v", "--assign", "--field-separator"},
        path_options={"-f", "--file"},
        path_options_are_program=True,
    ),
    "gsed": _PathCommand(
        value_options={"-e", "--expression"},
        path_options={"-f", "--file"},
        program_value_options={"-e", "--expression"},
        path_options_are_program=True,
    ),
    "jq": _PathCommand(
        value_options={"-L", "--indent"},
        path_options={"-f", "--from-file"},
        named_path_options={"--argfile", "--rawfile", "--slurpfile"},
        two_value_options={"--arg", "--argjson"},
        path_options_are_program=True,
    ),
    "sed": _PathCommand(
        value_options={"-e", "--expression"},
        path_options={"-f", "--file"},
        program_value_options={"-e", "--expression"},
        path_options_are_program=True,
    ),
}


def _is_assign(token: str) -> bool:
    name, sep, _ = token.partition("=")
    return bool(sep) and name.isidentifier()


def _is_redirection(token: str) -> bool:
    return bool(token) and all(chr in "<>&|" for chr in token)


def _short_option_value(token: str, options: Set[str]) -> tuple[str, str] | None:
    if not token.startswith("-") or token.startswith("--"):
        return None
    for index, option in enumerate(token[1:], start=2):
        short = f"-{option}"
        if short in options:
            return short, token[index:]
    return None


def _long_option_value(token: str, options: Set[str]) -> tuple[str, str] | None:
    option, sep, argument = token.partition("=")
    if sep and option in options:
        return option, argument
    return None


def _option_value(
    token: str, tokens: Iterator[str], options: Set[str]
) -> tuple[str, str] | None:
    if value := _long_option_value(token, options):
        return value
    if token in options:
        return token, next(tokens, "")
    if value := _short_option_value(token, options):
        option, argument = value
        return option, argument or next(tokens, "")
    return None


def _substitution_step(
    source: str, *, index: int, depth: int, quote: str
) -> tuple[int, int, str]:
    character = source[index]
    match quote, character:
        case _, _ if character == quote:
            return index + 1, depth, ""
        case "", "'" | '"':
            return index + 1, depth, character
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


def _heredoc(tokens: Iterator[str], *, patch: bool) -> _Heredoc | None:
    match next(tokens, None):
        case None | "":
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


def _args(arguments: Iterable[str]) -> Iterator[str]:
    tokens = iter(arguments)
    while token := next(tokens, None):
        if token.isdigit() and (following := next(tokens, None)) is not None:
            if _is_redirection(following):
                token = following
            else:
                tokens = chain((following,), tokens)
        yield token


def _patch_redirects(arguments: Iterable[str]) -> Iterator[_PatchFile]:
    tokens = iter(arguments)
    for token in tokens:
        if token == "<" and (path := next(tokens, "")):
            yield _PatchFile(path=path)


def _cat_paths(arguments: Iterable[str]) -> Iterator[str]:
    tokens = _args(arguments)
    while token := next(tokens, None):
        match token:
            case "--":
                yield from tokens
                return
            case _ if target := _redirect_target(token, tokens, include_writes=True):
                yield target
                continue
            case _ if _is_redirection(token):
                continue
        if token.startswith("-"):
            continue
        yield token


def _path_operands(arguments: Iterable[str], *, spec: _PathCommand) -> Iterator[str]:
    tokens = _args(arguments)
    yield_operands = spec.yield_operands
    for token in tokens:
        match token:
            case _ if target := _redirect_target(
                token, tokens, include_writes=spec.include_writes
            ):
                yield target
            case _ if _is_redirection(token):
                ...
            case "--" if not yield_operands:
                yield_operands = True
                next(tokens, None)
                yield from tokens
                return
            case "--":
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
                option, _ = value
                if option in spec.program_value_options:
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
        yield from _patch_redirects(args)
    elif name in _CAT_COMMANDS:
        yield from _cat_paths(args)
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
