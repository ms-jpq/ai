#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from argparse import ArgumentParser, Namespace
from collections.abc import Iterable, Iterator
from itertools import pairwise
from json import dumps
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
            (target, source) if incoming else (source, target)
            for source, target in pairwise(parts)
        )

    yield "digraph {"
    yield linesep
    for node_id in sorted(nodes):
        yield f"  {dumps(node_id, ensure_ascii=False)};"
        yield linesep
    for source, target in sorted(edges):
        stmt = f"  {dumps(source, ensure_ascii=False)} -> {dumps(target, ensure_ascii=False)};"
        yield stmt
        yield linesep
    yield "}"
    yield linesep


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
    stdout.writelines(_dot(stdin, incoming=args.direction == "incoming"))


_main()
