#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from contextlib import nullcontext
from logging import INFO, basicConfig, captureWarnings
from pathlib import Path
from subprocess import PIPE, Popen
from sys import stdin

with nullcontext():
    captureWarnings(True)
    basicConfig(format="%(message)s", level=INFO)

_AWK = Path(__file__).resolve(strict=True).parent / "apply_patch.awk"
_SEP = "\0"

with Popen((_AWK,), stdin=PIPE, stdout=PIPE) as awk:
    assert awk.stdin and awk.stdout
