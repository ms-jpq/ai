#!/usr/bin/env -S -- bash

set -Eeu
set -o pipefail
shopt -s nullglob extglob globstar

export -- GIT_TERMINAL_PROMPT=0 PAGER=tee EDITOR=true
