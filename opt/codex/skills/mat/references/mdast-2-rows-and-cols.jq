#!/usr/bin/env -S -- jq --exit-status --from-file

def cell_text:
  [recurse(.children[]?) | .value? | strings] | join("");

[
  recurse(select(.type != "table") | .children[]?)
  | select(.type == "table")
  | [.children[] | [.children[] | cell_text]]
  | {columns: (.[0] // []), rows: .[1:]}
]
