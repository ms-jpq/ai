#!/usr/bin/env -S -- bash -Eeuo pipefail -O dotglob -O nullglob -O extglob -O failglob -O globstar

set -o pipefail

# use https://github.com/ajv-validator/ajv-cli
# and maybe yq? to convert stuff into a form that is compatible with
