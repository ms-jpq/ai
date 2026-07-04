#!/usr/bin/env -S -- bash

set -Ee
# set -u TODO: why doesn't this work in opencode?
set -o pipefail
shopt -s nullglob extglob globstar

PATH="/opt/homebrew/bin:$PATH"
