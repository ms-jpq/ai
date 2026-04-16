#!/usr/bin/env -S -- PYTHONSAFEPATH= python3

from contextlib import nullcontext
from logging import INFO, basicConfig, captureWarnings

with nullcontext():
    captureWarnings(True)
    basicConfig(format="%(message)s", level=INFO)

