#!/usr/bin/env -S -- jq --exit-status --from-file

def cell_text:
  if .type == "text" or .type == "inlineCode" then .value
  elif .type == "image" or .type == "imageReference" then .alt // ""
  elif .type == "break" then "\n"
  elif .type == "tableCell" or .type == "emphasis" or .type == "strong"
    or .type == "delete" or .type == "link" or .type == "linkReference"
  then [.children[] | cell_text] | join("")
  else error("Unsupported cell node: \(.type)")
  end;

[
  recurse(select(.type != "table") | .children[]?)
  | select(.type == "table")
  | [.children[] | [.children[] | cell_text]]
  | {columns: (.[0] // []), rows: .[1:]}
]
