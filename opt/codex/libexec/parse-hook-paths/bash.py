#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser
from collections.abc import Iterable, Iterator, Mapping, MutableSequence, Sequence
from contextlib import suppress
from dataclasses import dataclass, field
from enum import IntEnum
from itertools import chain
from os.path import expanduser, expandvars
from pathlib import Path, PurePath
from shlex import shlex
from subprocess import run
from sys import stdin, stdout

_AWK = Path(__file__).resolve(strict=True).parent / "apply_patch.awk"
_EXPANSION = "\0"


class _OperandMode(IntEnum):
    AFTER_PROGRAM = 0
    ALWAYS = 1
    NEVER = 2


@dataclass(frozen=True)
class _OptionSpec:
    values: int = 1
    path_index: int | None = None
    program: bool = False


def _options(
    *,
    named_path: Iterable[str] = (),
    path: Iterable[str] = (),
    program_path: Iterable[str] = (),
    program_value: Iterable[str] = (),
    two_value: Iterable[str] = (),
    value: Iterable[str] = (),
) -> Mapping[str, _OptionSpec]:
    options: dict[str, _OptionSpec] = {}
    for name in named_path:
        options[name] = _OptionSpec(values=2, path_index=1)
    for name in path:
        options[name] = _OptionSpec(path_index=0)
    for name in program_path:
        options[name] = _OptionSpec(path_index=0, program=True)
    for name in program_value:
        options[name] = _OptionSpec(program=True)
    for name in two_value:
        options[name] = _OptionSpec(values=2)
    for name in value:
        options[name] = _OptionSpec()
    return options


@dataclass(frozen=True)
class _PathCommand:
    include_writes: bool = False
    operand_mode: _OperandMode = _OperandMode.ALWAYS
    options: Mapping[str, _OptionSpec] = field(default_factory=_options)


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
        options=_options(path={"-i", "--input"}),
    ),
    "cat": _PathCommand(
        include_writes=True,
    ),
    "cut": _PathCommand(
        include_writes=True,
        options=_options(
            value={
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
    ),
    "ed": _PathCommand(
        include_writes=True,
        options=_options(
            path={"-f", "--script"},
            value={"-p", "--prompt"},
        ),
    ),
    "echo": _PathCommand(
        include_writes=True,
        operand_mode=_OperandMode.NEVER,
    ),
    "grep": _PathCommand(
        operand_mode=_OperandMode.AFTER_PROGRAM,
        include_writes=True,
        options=_options(
            path={"-f", "--file", "--exclude-from"},
            value={
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
    ),
    "head": _PathCommand(
        include_writes=True,
        options=_options(value={"-c", "-n", "--bytes", "--lines"}),
    ),
    "ls": _PathCommand(
        include_writes=True,
    ),
    "nl": _PathCommand(
        include_writes=True,
        options=_options(
            value={
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
    ),
    "perl": _PathCommand(
        include_writes=True,
        options=_options(value={"-0", "-e", "-E", "-I", "-m", "-M", "-x"}),
    ),
    "printf": _PathCommand(
        include_writes=True,
        operand_mode=_OperandMode.NEVER,
    ),
    "rg": _PathCommand(
        operand_mode=_OperandMode.AFTER_PROGRAM,
        include_writes=True,
        options=_options(
            path={"-f", "--file"},
            value={
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
    ),
    "stat": _PathCommand(
        include_writes=True,
    ),
    "tail": _PathCommand(
        include_writes=True,
        options=_options(
            value={"-c", "-n", "--bytes", "--lines", "--pid", "--sleep-interval"}
        ),
    ),
    "wc": _PathCommand(
        include_writes=True,
    ),
    "awk": _PathCommand(
        operand_mode=_OperandMode.AFTER_PROGRAM,
        options=_options(
            program_path={"-f", "--file"},
            value={"-F", "-v", "--assign", "--field-separator"},
        ),
    ),
    "gawk": _PathCommand(
        operand_mode=_OperandMode.AFTER_PROGRAM,
        options=_options(
            program_path={"-f", "--file"},
            value={"-F", "-v", "--assign", "--field-separator"},
        ),
    ),
    "gsed": _PathCommand(
        operand_mode=_OperandMode.AFTER_PROGRAM,
        options=_options(
            program_path={"-f", "--file"},
            program_value={"-e", "--expression"},
        ),
    ),
    "jq": _PathCommand(
        operand_mode=_OperandMode.AFTER_PROGRAM,
        options=_options(
            named_path={"--argfile", "--rawfile", "--slurpfile"},
            program_path={"-f", "--from-file"},
            two_value={"--arg", "--argjson"},
            value={"-L", "--indent"},
        ),
    ),
    "sed": _PathCommand(
        operand_mode=_OperandMode.AFTER_PROGRAM,
        options=_options(
            program_path={"-f", "--file"},
            program_value={"-e", "--expression"},
        ),
    ),
    "tee": _PathCommand(
        include_writes=True,
    ),
}


def _is_redirection(token: str) -> bool:
    return bool(token) and all(chr in "<>&|" for chr in token)


def _option_match(
    token: str, tokens: Iterator[str], options: Mapping[str, _OptionSpec]
) -> tuple[_OptionSpec, tuple[str | None, ...]] | None:
    option, sep, argument = token.partition("=")
    if sep and (spec := options.get(option)) and spec.values == 1:
        return spec, (argument,)
    if spec := options.get(token):
        return spec, tuple(next(tokens, None) for _ in range(spec.values))
    if token.startswith("-") and not token.startswith("--"):
        for index, short_option in enumerate(token[1:], start=2):
            short = f"-{short_option}"
            if (spec := options.get(short)) and spec.values == 1:
                return spec, (token[index:] or next(tokens, None),)
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
                        if (name := next(tokens, None)) is None:
                            return None
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
    match next(tokens, None):
        case None:
            return None
        case "-":
            if (delimiter := next(tokens, None)) is None:
                return None
            return _Heredoc(delimiter=delimiter, patch=patch, strip_tabs=True)
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
            return next(tokens, None)
        case ">" | ">>" | ">|" if include_writes:
            return next(tokens, None)
        case _ if _is_redirection(token):
            next(tokens, None)
    return None


def _path_operands(arguments: Iterable[str], *, spec: _PathCommand) -> Iterator[str]:
    tokens = iter(arguments)
    yield_operands = spec.operand_mode is _OperandMode.ALWAYS
    while (token := next(tokens, None)) is not None:
        if token.isdigit() and (following := next(tokens, None)) is not None:
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
                if spec.operand_mode is _OperandMode.NEVER:
                    continue
                if not yield_operands:
                    next(tokens, None)
                yield from tokens
                return
            case _ if option := _option_match(token, tokens, spec.options):
                option_spec, arguments = option
                if option_spec.path_index is not None:
                    if path := arguments[option_spec.path_index]:
                        yield path
                if option_spec.program:
                    yield_operands = True
            case _ if token.startswith("-") and token != "-":
                ...
            case _ if yield_operands:
                yield token
            case _:
                yield_operands = spec.operand_mode is _OperandMode.AFTER_PROGRAM


def _command_events(
    command: Sequence[str], *, read_too: bool
) -> Iterator[_Heredoc | _PatchFile | str]:
    arg0, *args = command
    name = PurePath(arg0).name

    yield from _heredocs(args, patch=name in _PATCH_COMMANDS)
    if not read_too:
        return

    match name:
        case _ if name in _PATCH_COMMANDS:
            tokens = iter(args)
            for token in tokens:
                if token == "<" and (path := next(tokens, None)):
                    yield _PatchFile(path=path)
        case _ if spec := _PATH_COMMANDS.get(name):
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
