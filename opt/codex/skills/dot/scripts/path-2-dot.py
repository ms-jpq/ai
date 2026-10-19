#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser, Namespace
from collections.abc import Iterable, Iterator
from itertools import chain, pairwise, repeat
from json import dumps
from locale import strxfrm
from os import linesep
from pathlib import PurePosixPath
from sys import stdin, stdout


def _chains(lines: Iterable[str]) -> Iterator[tuple[str, ...]]:
    for line in lines:
        if not (line := line.strip()):
            continue

        path = PurePosixPath(line)
        yield path.relative_to(path.anchor).parts if path.anchor else path.parts


def _dot(lines: Iterable[str], *, incoming: bool) -> Iterator[str]:
    nodes: set[str] = set()
    edges: set[tuple[str, str]] = set()

    for parts in _chains(lines):
        nodes.update(parts)
        edges.update(
            (head, tail) if incoming else (tail, head) for tail, head in pairwise(parts)
        )

    yield "digraph {"
    for node_id in sorted(nodes, key=strxfrm):
        yield f"  {dumps(node_id, ensure_ascii=False)};"
    for tail, head in sorted(edges, key=lambda x: tuple(map(strxfrm, x))):
        yield (
            f"  {dumps(tail, ensure_ascii=False)} -> {dumps(head, ensure_ascii=False)};"
        )
    yield "}"


def _parse_args() -> Namespace:
    parser = ArgumentParser()
    parser.add_argument(
        "direction",
        choices=("outgoing", "incoming"),
        help="outgoing: a/b means (a → b); incoming: a/b means (a ← b)",
    )
    return parser.parse_args()


def _main() -> None:
    args = _parse_args()
    statements = _dot(stdin, incoming=args.direction == "incoming")
    stdout.writelines(chain.from_iterable(zip(statements, repeat(linesep))))


_main()
