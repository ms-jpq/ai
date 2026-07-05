#!/usr/bin/env -S -- bash

set -Eeu -o pipefail
shopt -s dotglob nullglob extglob globstar

unset -- BASH_ENV
PATH="/opt/homebrew/bin:$PATH"
