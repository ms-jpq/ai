#!/usr/bin/env -S -- jq --exit-status --from-file

map_values(.extensionToLanguage = [._filetypes[]? | ($map[0][.] // [])[]] | del(._filetypes))
